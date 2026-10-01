import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true; // Defaults to Login Mode
  bool _isLoading = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _tscController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  final List<String> _roles = [
    'Member Teacher',
    'Assistant Admin',
    'Administrator',
  ];

  String _selectedRole = 'Member Teacher';

  // Blacklist filters matching backend validation
  final Set<String> _blockedPhoneNumbers = {
    '0712345678',
    '0700000000',
    '0711111111',
    '0722222222',
    '0799999999',
    '0123456789',
  };

  final Set<String> _blockedIds = {
    '12345',
    '123456',
    '1234567',
    '12345678',
    '000000',
    '111111',
    '999999',
  };

  @override
  void dispose() {
    _fullNameController.dispose();
    _tscController.dispose();
    _phoneController.dispose();
    _idController.dispose();
    super.dispose();  }

  void _showSnackBar(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  }
    
  Future<void> _handleSubmit() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  // Dynamically target either /login or /register
  final String endpoint = _isLogin
      ? 'https://teacher-connect-backend.vercel.app/api/auth/login'
      : 'https://teacher-connect-backend.vercel.app/api/auth/register';

  final String tsc = _tscController.text.trim();
  final String idNumber = _idController.text.trim();

  // Prepare request payload
  final Map<String, dynamic> requestBody = _isLogin
      ? {
          'tscNumber': tsc,
          'nationalId': idNumber,
        }
      : {
          'fullName': _fullNameController.text.trim(),
          'tscNumber': tsc,
          'phone': _phoneController.text.trim(),
          'nationalId': idNumber,
          'role': _selectedRole,
        };

  try {
    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 20));

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final userStatus = data['user']?['status'];

      if (userStatus == 'pending') {
        _showSnackBar('Account pending admin verification.');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/pending-approval');
        }
        return;
      }

      // Save session details locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString(
        'userName',
        data['user']?['fullName'] ?? (_isLogin ? 'Teacher' : _fullNameController.text.trim()),
      );
      await prefs.setString(
        'userRole',
        data['user']?['role'] ?? (_isLogin ? 'Member Teacher' : _selectedRole),
      );
      await prefs.setString('userPhone', data['user']?['phone'] ?? _phoneController.text.trim());

      if (data['token'] != null) {
        await prefs.setString('token', data['token']);
      }

      _showSnackBar(_isLogin ? 'Login Successful!' : 'Registration Successful!');

            if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } else {
      _showSnackBar(data['error'] ?? data['message'] ?? 'Authentication failed.');
    }
  } catch (e) {
    _showSnackBar('EXACT ERROR: $e');
  } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Member Login' : 'Member Registration'),
        backgroundColor: const Color(0xFF00897B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.school,
                size: 64,
                color: Color(0xFF00897B),
      
            ),
              const SizedBox(height: 16),
              Text(
                _isLogin ? 'Welcome Back' : 'Welcome to Teacher Portal',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Enter your credentials to log in'
                    : 'Enter your details below to register',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // REGISTER-ONLY FIELD: FULL NAME
              if (!_isLogin) ...[
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (!_isLogin) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your Full Name';
                      }
                      if (val.trim().length < 3) {
                        return 'Full Name must be at least 3 characters';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // REQUIRED FOR BOTH: TSC NUMBER
              TextFormField(
                controller: _tscController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'TSC Number',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your TSC Number';
                  }
                  final trimmed = val.trim();
                  if (_blockedIds.contains(trimmed)) {
                    return 'Please enter a valid TSC Number';
                  }
                  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
                    return 'TSC Number must contain digits only';
                  }
                  if (trimmed.length < 5) {
                    return 'TSC Number must be at least 5 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // REGISTER-ONLY FIELD: PHONE NUMBER
              if (!_isLogin) ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (!_isLogin) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter a phone number';
                      }
                      final trimmed = val.trim();
                      if (_blockedPhoneNumbers.contains(trimmed)) {
                        return 'Please enter a valid phone number';
                      }
                      if (!RegExp(r'^(07|01)\d{8}$').hasMatch(trimmed)) {
                        return 'Enter a valid 10-digit Kenyan phone number (e.g. 0712345678)';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // REQUIRED FOR BOTH: NATIONAL ID
              TextFormField(
                controller: _idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'National ID Number',
                  prefixIcon: Icon(Icons.card_membership),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your National ID';
                  }
                  final trimmed = val.trim();
                  if (_blockedIds.contains(trimmed)) {
                    return 'Please enter a valid National ID';
                  }
                  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
                    return 'National ID must contain digits only';
                  }
                  if (trimmed.length < 5) {
                    return 'National ID must be at least 5 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // REGISTER-ONLY FIELD: ROLE DROPDOWN
              if (!_isLogin) ...[
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work),
                    border: OutlineInputBorder(),
                  ),
                  items: _roles.map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 24),
              ],

              // SUBMIT BUTTON
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isLogin ? 'Log In' : 'Register Account',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 16),

              // TOGGLE BETWEEN LOGIN & REGISTER
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isLogin ? "Don't have an account? " : "Already have an account? "),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _isLogin ? 'Register' : 'Log In',
                      style: const TextStyle(
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

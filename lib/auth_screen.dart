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

  bool _isLogin = true; // Default to Login mode
  bool _isLoading = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _tscController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _adminPasscodeController = TextEditingController();

  final List<String> _roles = [
    'Member Teacher',
    'Assistant Admin',
    'Administrator',
  ];

  String _selectedRole = 'Member Teacher';

  // Blacklists for invalid/placeholder entries
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
    _adminPasscodeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleSubmit() async {
    // Validate Form first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    const String baseUrl = 'https://teacher-connect-backend.vercel.app/api/auth';
    final String endpoint = _isLogin ? '$baseUrl/login' : '$baseUrl/register';

    final String tsc = _tscController.text.trim();
    final String idNumber = _idController.text.trim();

    Map<String, dynamic> requestBody;

    if (_isLogin) {
      // LOGIN PAYLOAD: ONLY CREDENTIALS REQUIRED FOR AUTHENTICATION
      requestBody = {
        'tscNumber': tsc,
        'nationalId': idNumber,
      };
    } else {
      // REGISTRATION PAYLOAD: FULL DETAILS REQUIRED
      requestBody = {
        'fullName': _fullNameController.text.trim(),
        'tscNumber': tsc,
        'phone': _phoneController.text.trim(),
        'nationalId': idNumber,
        'role': _selectedRole,
      };

      if (_selectedRole == 'Administrator' || _selectedRole == 'Assistant Admin') {
        requestBody['adminPasscode'] = _adminPasscodeController.text.trim();
      }
    }

    try {
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final userStatus = data['user']?['status'] ?? data['status'];

        if (userStatus == 'pending') {
          _showSnackBar('Account pending admin verification.');
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/pending-approval');
          }
          return;
        }

        // Save session locally for verified users
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
        _showSnackBar(data['message'] ?? 'Authentication failed.');
      }
    } catch (e) {
      _showSnackBar('Network error. Please check your internet connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            crossAxisAlignment: CrossAlignment.stretch,
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

              // REGISTER-ONLY FIELDS: ROLE & ADMIN PASSCODE
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
                if (_selectedRole == 'Administrator' || _selectedRole == 'Assistant Admin') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminPasscodeController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Admin Passcode',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (!_isLogin &&
                          (_selectedRole == 'Administrator' || _selectedRole == 'Assistant Admin')) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter the admin passcode';
                        }
                      }
                      return null;
                    },
                  ),
                ],
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

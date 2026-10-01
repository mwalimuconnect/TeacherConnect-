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

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _tscNumberController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();

  String _selectedRole = 'Member Teacher';

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _idNumberController.dispose();
    _tscNumberController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final baseUrl = 'https://teacher-connect-backend.vercel.app';
    final endpoint = _isLogin ? '$baseUrl/api/auth/login' : '$baseUrl/api/auth/register';

    final Map<String, dynamic> requestBody = _isLogin
        ? {
            'phone': _phoneController.text.trim(),
            'password': _passwordController.text.trim(),
          }
        : {
            'fullName': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'idNumber': _idNumberController.text.trim(),
            'tscNumber': _tscNumberController.text.trim(),
            'schoolName': _schoolNameController.text.trim(),
            'role': _selectedRole,
            'password': _passwordController.text.trim(),
          };

          final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> data = {};
      
      // Check if the server returned JSON
      if (response.headers['content-type']?.contains('application/json') ?? false) {
        data = jsonDecode(response.body);
      } else {
        _showSnackBar('Server response (${response.statusCode}): ${response.body}');
        return;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ... rest of your success logic

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
                _isLogin ? 'Welcome Back' : 'Welcome to TeacherConnect',
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
                TextFormField(
                  controller: _idNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'National ID Number',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                   // Role Dropdown Selection
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Member Teacher',
                    'Job Seeker (BOM)',
                    'Admin',
                    'Representative'
                  ]
                      .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRole = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // TSC Number Field (Optional for Job Seekers)
                TextFormField(
                  controller: _tscNumberController,
                  decoration: InputDecoration(
                    labelText: _selectedRole == 'Job Seeker (BOM)'
                        ? 'TSC Number (Optional)'
                        : 'TSC Number',
                    prefixIcon: const Icon(Icons.card_membership),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (!_isLogin && _selectedRole != 'Job Seeker (BOM)') {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your TSC Number';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Current School Name Field (Optional for Job Seekers)
                TextFormField(
                  controller: _schoolNameController,
                  decoration: InputDecoration(
                    labelText: _selectedRole == 'Job Seeker (BOM)'
                        ? 'Current School / Preferred Region (Optional)'
                        : 'Current School Name',
                    prefixIcon: const Icon(Icons.domain),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (!_isLogin && _selectedRole == 'Member Teacher') {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your Current School Name';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),               validator: (val) {
                    if (!_isLogin && (val == null || val.trim().isEmpty)) {
                      return 'Please enter your National ID Number';
                    }
                    return null;
                  },
                ),
                ,
              ],

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your password';
                  }
                  if (val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isLogin ? 'Login' : 'Register'),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Register"
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

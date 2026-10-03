import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _tscNumberController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _adminPasscodeController = TextEditingController();

  String _selectedRole = 'Admin';

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    _tscNumberController.dispose();
    _schoolNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _adminPasscodeController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    _formKey.currentState?.reset(); // Clears all validation errors when toggling mode
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String endpoint = _isLogin ? '/api/auth/login' : '/api/auth/register';
      final Uri url = Uri.parse('https://teacher-connect-backend.vercel.app$endpoint');

      final Map<String, dynamic> payload = _isLogin
          ? {
              'phoneNumber': _phoneController.text.trim(),
              'password': _passwordController.text.trim(),
            }
          : {
              'fullName': _fullNameController.text.trim(),
              'idNumber': _idNumberController.text.trim(),
              'role': _selectedRole,
              'tscNumber': _tscNumberController.text.trim(),
              'currentSchool': _schoolNameController.text.trim(),
              'phoneNumber': _phoneController.text.trim(),
              'password': _passwordController.text.trim(),
              if (_selectedRole == 'Admin')
                'adminPasscode': _adminPasscodeController.text.trim(),
            };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? (_isLogin ? 'Login successful!' : 'Registration successful!')),
            backgroundColor: const Color(0xFF00897B),
          ),
        );

        // TODO: Add navigation to AdminDashboardScreen or TeacherPortalScreen here
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Authentication failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to server: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isLogin ? 'Member Login' : 'Member Registration'),
        backgroundColor: const Color(0xFF00897B),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isLogin ? 'Welcome Back to' : 'Welcome to',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.normal),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'TeacherConnect',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ================= REGISTRATION SPECIFIC FIELDS =================
                if (!_isLogin) ...[
                  // Full Name (with ValueKey)
                  TextFormField(
                    key: const ValueKey('fullNameField'),
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (!_isLogin && (val == null || val.trim().isEmpty)) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ID / Passport Number (with ValueKey)
                  TextFormField(
                    key: const ValueKey('idNumberField'),
                    controller: _idNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID / Passport Number',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (!_isLogin && (val == null || val.trim().isEmpty)) {
                        return 'Please enter your ID number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Role Dropdown Selection
                  DropdownButtonFormField<String>(
                    key: const ValueKey('roleDropdownField'),
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
                  const SizedBox(height: 14),

                  // TSC Number Field (with ValueKey)
                  TextFormField(
                    key: const ValueKey('tscNumberField'),
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
                  const SizedBox(height: 14),

                  // Current School Name Field (with ValueKey)
                  TextFormField(
                    key: const ValueKey('schoolNameField'),
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
                  const SizedBox(height: 14),
                ],

                // ================= SHARED FIELDS =================
                // Phone Number Field (with ValueKey)
                TextFormField(
                  key: const ValueKey('phoneNumberField'),
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
                const SizedBox(height: 14),

                // Password Field (with ValueKey)
                TextFormField(
                  key: const ValueKey('passwordField'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                    return null;
                  },
                ),

                // Conditional Admin Security Passcode Field
                if (!_isLogin && _selectedRole == 'Admin') ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const ValueKey('adminPasscodeField'),
                    controller: _adminPasscodeController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.security, color: Colors.red),
                      labelText: 'Admin Security Passcode',
                      hintText: 'Enter passcode',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    ),
                    validator: (val) {
                      if (!_isLogin && _selectedRole == 'Admin') {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter the admin security passcode';
                        }
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isLogin ? 'Login' : 'Register',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 12),

                // Toggle Login / Register
                TextButton(
                  onPressed: _toggleAuthMode,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      children: [
                        TextSpan(
                          text: _isLogin
                              ? "Don't have an account? "
                              : 'Already have an account? ',
                        ),
                        TextSpan(
                          text: _isLogin ? 'Register' : 'Login',
                          style: const TextStyle(
                            color: Color(0xFF5E35B1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

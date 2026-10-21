import 'main.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocalAuthentication _localAuth = LocalAuthentication();

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
    _formKey.currentState?.reset();
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  /// Handles Biometric (Fingerprint) Authentication flow with saved session lookup
  Future<void> _handleBiometricLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedPhone = prefs.getString('savedPhone');
      final String? savedName = prefs.getString('savedName');
      final String? savedRole = prefs.getString('savedRole');

      // Check if a valid user session was saved on this device
      if (savedPhone == null || savedPhone.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in with your phone and password first to enable fingerprint login.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication is not supported or set up on this device.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to log into TeacherConnect',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome back, ${savedName ?? 'Teacher'}!'),
            backgroundColor: const Color(0xFF00897B),
            duration: const Duration(seconds: 2),
          ),
        );

        final bool isAdmin = savedRole?.toLowerCase().contains('admin') ?? false;

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(
                adminName: savedName ?? 'Admin',
                adminPhone: savedPhone,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherPortalScreen(
                userName: savedName ?? 'Member Teacher',
                userRole: savedRole ?? 'Member Teacher',
                userPhone: savedPhone,
              ),
            ),
          );
        }
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      if (!_isLogin && _selectedRole != 'Job Seeker (BOM)' && _tscNumberController.text.trim().isNotEmpty) {
        final verifyResponse = await http.post(
          Uri.parse('https://teacher-connect-backend.vercel.app/api/verify-tsc'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idNumber': _idNumberController.text.trim(),
            'tscNumber': _tscNumberController.text.trim(),
          }),
        );

        final verifyData = jsonDecode(verifyResponse.body);
        if (verifyData['success'] == false) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(verifyData['message'] ?? 'TSC verification failed. Please check your ID and TSC number.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

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

        final userMap = data['user'] ?? {};
        final String userRole = userMap['role'] ?? _selectedRole;
        final String userName = userMap['fullName'] ?? _phoneController.text.trim();
        final String userPhone = userMap['phone'] ?? userMap['phoneNumber'] ?? _phoneController.text.trim();

        // Save session locally so fingerprint login and direct entry work instantly
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedPhone', userPhone);
        await prefs.setString('savedName', userName);
        await prefs.setString('savedRole', userRole);
        await prefs.setBool('isLoggedIn', true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? (_isLogin ? 'Login successful!' : 'Registration successful!')),
            backgroundColor: const Color(0xFF00897B),
            duration: const Duration(seconds: 2),
          ),
        );

        final bool isAdmin = userRole.toLowerCase().contains('admin');

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(
                adminName: userName,
                adminPhone: userPhone,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherPortalScreen(
                userName: userName,
                userRole: userRole,
                userPhone: userPhone,
              ),
            ),
          );
        }
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

                if (!_isLogin) ...[
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
                      'Representative',
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
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
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

                if (_isLogin) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

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

                // Fingerprint Login Section (Visible only in Login mode)
                if (_isLogin) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider(thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _handleBiometricLogin,
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF00897B), width: 1.5),
                            ),
                            child: const Icon(
                              Icons.fingerprint,
                              size: 40,
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Login with Fingerprint',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                TextButton(
                  onPressed: _toggleAuthMode,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      children: [
                        TextSpan(
                          text: _isLogin ? "Don't have an account? " : "Already have an account? ",
                        ),
                        TextSpan(
                          text: _isLogin ? 'Register' : 'Login',
                          style: const TextStyle(
                            color: Color(0xFFFF5722),
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

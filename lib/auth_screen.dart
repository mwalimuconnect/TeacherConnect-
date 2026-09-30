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

  bool _isLogin = false;

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

  // Blocklists for invalid/placeholder entries

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

  String? _validatePhone(String phone) {

    if (phone.isEmpty) return 'Please enter a phone number.';

    if (_blockedPhoneNumbers.contains(phone)) {

      return 'Please enter a genuine phone number.';

    }

    final phoneRegex = RegExp(r'^(07|01)\d{8}$');

    if (!phoneRegex.hasMatch(phone)) {

      return 'Enter a valid 10-digit Kenyan phone number (e.g., 07123...).';

    }

    return null;

  }

  String? _validateIdOrTsc(String value, String labelName) {

    if (value.isEmpty) return 'Please enter your $labelName.';

    if (_blockedIds.contains(value)) {

      return 'Please enter a valid $labelName.';

    }

    if (RegExp(r'^(\d)\1+$').hasMatch(value)) {

      return 'Invalid $labelName format.';

    }

    if (value.length < 5) {

      return '$labelName must be at least 5 digits.';

    }

    return null;

  }

  Future<void> _handleSubmit() async {

    final tsc = _tscController.text.trim();

    final idNumber = _idController.text.trim();

    final fullName = _fullNameController.text.trim();

    final phone = _phoneController.text.trim();

    final adminPasscode = _adminPasscodeController.text.trim();

    // Validate TSC and ID

    final tscError = _validateIdOrTsc(tsc, 'TSC Number');

    if (tscError != null) {

      _showSnackBar(tscError);

      return;

    }

    final idError = _validateIdOrTsc(idNumber, 'National ID');

    if (idError != null) {

      _showSnackBar(idError);

      return;

    }

    // Additional Registration Validations

    if (!_isLogin) {

      if (fullName.isEmpty) {

        _showSnackBar('Please enter your Full Name.');

        return;

      }

      final phoneError = _validatePhone(phone);

      if (phoneError != null) {

        _showSnackBar(phoneError);

        return;

      }

      if ((_selectedRole == 'Administrator' || _selectedRole == 'Assistant Admin') &&

          adminPasscode.isEmpty) {

        _showSnackBar('Please enter the admin passcode.');

        return;

      }

    }

    setState(() => _isLoading = true);

    const String baseUrl = 'https://teacher-connect-backend.vercel.app/api/auth';

    final String endpoint = _isLogin ? '$baseUrl/login' : '$baseUrl/register';

    try {

      final Map<String, dynamic> requestBody = _isLogin

          ? {

              'tscNumber': tsc,

              'nationalId': idNumber,

            }

          : {

              'fullName': fullName,

              'tscNumber': tsc,

              'phone': phone,

              'nationalId': idNumber,

              'role': _selectedRole,

              if (_selectedRole == 'Administrator' || _selectedRole == 'Assistant Admin')

                'adminPasscode': adminPasscode,

            };

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

        // Check if registration/login is pending admin verification

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

            'userName', data['user']?['fullName'] ?? (_isLogin ? 'Teacher' : fullName));

        await prefs.setString(

            'userRole', data['user']?['role'] ?? (_isLogin ? 'Member Teacher' : _selectedRole));

        await prefs.setString('userPhone', data['user']?['phone'] ?? phone);

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

            // REGISTER ONLY FIELD: FULL NAME

            if (!_isLogin) ...[

              TextField(

                controller: _fullNameController,

                decoration: const InputDecoration(

                  labelText: 'Full Name',

                  prefixIcon: Icon(Icons.person),

                  border: OutlineInputBorder(),

                ),

              ),

              const SizedBox(height: 16),

            ],

            // TSC NUMBER (Required for both)

            TextField(

              controller: _tscController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(

                labelText: 'TSC Number',

                prefixIcon: Icon(Icons.badge),

                border: OutlineInputBorder(),

              ),

            ),

            const SizedBox(height: 16),

            // REGISTER ONLY FIELD: PHONE NUMBER

            if (!_isLogin) ...[

              TextField(

                controller: _phoneController,

                keyboardType: TextInputType.phone,

                decoration: const InputDecoration(

                  labelText: 'Phone Number',

                  prefixIcon: Icon(Icons.phone),

                  border: OutlineInputBorder(),

                ),

              ),

              const SizedBox(height: 16),

            ],

            // NATIONAL ID NUMBER (Required for both)

            TextField(

              controller: _idController,

              keyboardType: TextInputType.number,

              decoration: const InputDecoration(

                labelText: 'National ID Number',

                prefixIcon: Icon(Icons.card_membership),

                border: OutlineInputBorder(),

              ),

            ),

            const SizedBox(height: 16),

            // REGISTER ONLY FIELD: ROLE DROPDOWN & ADMIN PASSCODE

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

                TextField(

                  controller: _adminPasscodeController,

                  obscureText: true,

                  keyboardType: TextInputType.number,

                  decoration: const InputDecoration(

                    labelText: 'Admin Passcode',

                    prefixIcon: Icon(Icons.lock),

                    border: OutlineInputBorder(),

                  ),

                ),

              ],

              const SizedBox(height: 24),

            ] else

              const SizedBox(height: 8),

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

                      style: const TextStyle(fontSize: 16, color: Colors.white),

                    ),

            ),

            const SizedBox(height: 16),
                        // TOGGLE BETWEEN LOGIN & REGISTER

            Row(

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                Text(

                  _isLogin

                      ? "Don't have an account? "

                      : "Already have an account? ",

                ),

                GestureDetector(

                  onTap: () {

                    setState(() {

                      _isLogin = !_isLogin;

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

    );

  }

}  
            

import 'package:flutter/material.dart';

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

  String _selectedRole = 'Member Teacher';

  @override
  void dispose() {
    _fullNameController.dispose();
    _idNumberController.dispose();
    _tscNumberController.dispose();
    _schoolNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Submit auth data logic here
      
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
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isLogin ? 'Welcome Back' : 'Welcome to TeacherConnect',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Fields shown only during Registration
                if (!_isLogin) ...[
                  // Full Name
                  TextFormField(
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
                  const SizedBox(height: 16),

                  // ID / Passport Number
                  TextFormField(
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
                  const SizedBox(height: 16),

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
                        .map((role) =>
                            DropdownMenuItem(value: role, child: Text(role)))
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
                  const SizedBox(height: 16),
                ],

                // Phone Number Field
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

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
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
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Login' : 'Register'),
                ),
                const SizedBox(height: 16),

                // Toggle Login / Register
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Register"
                        : "Already have an account? Login",
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

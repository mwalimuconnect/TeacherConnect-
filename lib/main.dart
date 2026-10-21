import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Add this for PlatformException
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacherconnect/auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:teacherconnect/services/upload_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart'; // <-- Add this for LocalAuthentication & AuthenticationOptions
void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  final String userName = prefs.getString('userName') ?? 'Teacher';

  final String userRole = prefs.getString('userRole') ?? 'Member Teacher';

  final String userPhone = prefs.getString('userPhone') ?? '';

  runApp(MyApp(

    isLoggedIn: isLoggedIn,

    userName: userName,

    userRole: userRole,

    userPhone: userPhone,

  ));

}

class MyApp extends StatelessWidget {

  final bool isLoggedIn;

  final String userName;

  final String userRole;

  final String userPhone;

  const MyApp({

    super.key,

    required this.isLoggedIn,

    required this.userName,

    required this.userRole,

    required this.userPhone,

  });

  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'TeacherConnect',

      theme: ThemeData(

        primarySwatch: Colors.teal,

        useMaterial3: true,

        scaffoldBackgroundColor: const Color(0xFFF7F9FA),

        appBarTheme: const AppBarTheme(

          backgroundColor: Color(0xFF009688),

          elevation: 0,

          foregroundColor: Colors.white,

        ),

      ),

      home: isLoggedIn

          ? ((userRole == 'Administrator' || userRole == 'Assistant Admin')

              ? AdminDashboardScreen(adminName: userName)

              : TeacherPortalScreen(

                  userName: userName,

                  userRole: userRole,

                  userPhone: userPhone,

                ))

          : const AuthScreen(),

    );

  }

}

// ==========================================
// 1. DATA MODELS
// ==========================================
class ListingModel {
  final String id;
  final String teacherName;
  final String schoolName;
  final String subject;
  final String currentCounty;
  final String subCounty;
  final String targetCounty;
  final String targetSubCounty;
  final String contactPhone;
  final String? tscNumber;
  final String salary;
  final bool isTscCompliant;
  final String category;
  final bool isPaid;
  final bool isApproved;

  ListingModel({
    this.id = '',
    this.teacherName = '',
    this.schoolName = '',
    required this.subject,
    required this.currentCounty,
    this.subCounty = '',
    this.targetCounty = '',
    this.targetSubCounty = '',
    required this.contactPhone,
    this.tscNumber,
    this.salary = '',
    this.isTscCompliant = false,
    required this.category,
    this.isPaid = false,
    this.isApproved = false,
  });

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    // Extract nested user objects safely (handles 'userId', 'user', or 'postedBy')
    final Map<String, dynamic> userMap = 
        (json['userId'] is Map<String, dynamic>) ? json['userId'] :
        (json['user'] is Map<String, dynamic>) ? json['user'] :
        (json['postedBy'] is Map<String, dynamic>) ? json['postedBy'] : {};

    // 1. Extract raw TSC Number string across top-level & nested user keys
    final Object? rawTscValue = json['tscNumber'] ?? 
                               json['tscNo'] ?? 
                               json['tsc'] ?? 
                               json['tsc_number'] ?? 
                               json['tsc_no'] ?? 
                               userMap['tscNumber'] ?? 
                               userMap['tscNo'] ?? 
                               userMap['tsc'] ?? 
                               userMap['tsc_number'] ?? 
                               userMap['tsc_no'];

    final String rawTsc = rawTscValue != null ? rawTscValue.toString().trim() : '';

    final String displayTsc = 
        (rawTsc.isNotEmpty && 
         rawTsc.toLowerCase() != 'null' && 
         rawTsc.toLowerCase() != 'undefined' &&
         rawTsc.toLowerCase() != 'n/a') 
        ? rawTsc 
        : 'N/A';

    // 2. Safe Phone extraction
    final Object? rawPhoneValue = json['contactPhone'] ?? 
                                 json['phoneNumber'] ?? 
                                 json['phone'] ?? 
                                 userMap['contactPhone'] ?? 
                                 userMap['phone'];

    final String phone = rawPhoneValue != null ? rawPhoneValue.toString().trim() : 'N/A';

    // 3. Comprehensive TSC Compliance evaluation logic
    // Forces compliance to true if a valid TSC number or string exists
    final bool computedCompliance = json['isTscCompliant'] == true || 
                                     json['tscCompliant'] == true || 
                                     (displayTsc != 'N/A' && displayTsc.isNotEmpty);

    return ListingModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      teacherName: (json['teacherName'] ?? 
                    json['fullName'] ?? 
                    json['userName'] ?? 
                    userMap['name'] ?? 
                    userMap['fullName'] ?? 
                    'N/A').toString(),
      schoolName: (json['schoolName'] ?? 
                   json['currentSchool'] ?? 
                   json['school'] ?? 
                   userMap['school'] ??
                   'N/A').toString(),
      subject: (json['subjectCombination'] ?? 
                json['subject'] ?? 
                json['subjects'] ?? 
                'N/A').toString(),
      currentCounty: (json['currentCounty'] ?? 
                     json['county'] ?? 
                     json['currentLocation'] ?? 
                     'N/A').toString(),
      subCounty: (json['subCounty'] ?? 
                  json['currentSubCounty'] ?? 
                  userMap['subCounty'] ?? 
                  '').toString(),
      targetCounty: (json['targetCounty'] ?? 
                    json['targetLocation'] ?? 
                    json['desiredCounty'] ?? 
                    '').toString(),
      targetSubCounty: (json['targetSubCounty'] ?? '').toString(),
      contactPhone: phone,
      tscNumber: displayTsc,
      salary: (json['salary'] ?? '').toString(),
      isTscCompliant: computedCompliance,
      category: (json['category'] ?? json['type'] ?? 'TSC Swap').toString(),
      isPaid: json['isPaid'] == true,
      isApproved: json['isApproved'] == true || json['status'] == 'approved',
    );
  }
}

class ResourceModel {
  final String id;
  final String title;
  final String category;
  final double price; // 0.0 for free

  ResourceModel({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    return ResourceModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Resource').toString(),
      category: (json['category'] ?? 'General').toString(),
      price: (json['price'] != null)
          ? double.tryParse(json['price'].toString()) ?? 0.0
          : 0.0,
    );
  }
}
                                                                                                
// =========================================================
// 1. REGISTRATION SCREEN
// =========================================================

class MemberRegistrationScreen extends StatefulWidget {
  const MemberRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<MemberRegistrationScreen> createState() =>
      _MemberRegistrationScreenState();
}

class _MemberRegistrationScreenState extends State<MemberRegistrationScreen> {
  final _fullNameController = TextEditingController();
  final _idController = TextEditingController();
  final _tscController = TextEditingController();
  final _schoolController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _adminPasscodeController = TextEditingController();

  String _selectedRole = 'Admin';
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _roles = [
    'Member Teacher',
    'Job Seeker (BOM)',
    'Admin',
    'Representative',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _idController.dispose();
    _tscController.dispose();
    _schoolController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _adminPasscodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);

    try {
      final payload = {
        'fullName': _fullNameController.text.trim(),
        'idNumber': _idController.text.trim(),
        'role': _selectedRole,
        'tscNumber': _tscController.text.trim(),
        'currentSchool': _schoolController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
        if (_selectedRole == 'Admin')
          'adminPasscode': _adminPasscodeController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Registration successful!'),
            backgroundColor: const Color(0xFF00897B),
          ),
        );

        if (_selectedRole == 'Admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(
                adminName: _fullNameController.text.trim(),
                adminPhone: _phoneController.text.trim(),
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherPortalScreen(
                userName: _fullNameController.text.trim(),
                userRole: _selectedRole,
                userPhone: _phoneController.text.trim(),
              ),
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Registration failed'),
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

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Member Registration'),
        backgroundColor: const Color(0xFF00897B),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'Welcome to',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.normal),
                ),
              ),
              const Center(
                child: Text(
                  'TeacherConnect',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // ID / Passport Number
              TextField(
                controller: _idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge),
                  labelText: 'ID / Passport Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Role Dropdown
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.work),
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: _roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // TSC Number
              TextField(
                controller: _tscController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.card_membership),
                  labelText: _selectedRole == 'Job Seeker (BOM)'
                      ? 'TSC Number (Optional)'
                      : 'TSC Number',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Current School Name
              TextField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.apartment),
                  labelText: 'Current School Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Phone Number
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone),
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                ),
              ),

              // Conditional Admin Security Passcode Field
              if (_selectedRole == 'Admin') ...[
                const SizedBox(height: 14),
                TextField(
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
                ),
              ],

              const SizedBox(height: 24),

              // Register Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleRegister,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Register',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Active Login Link
              Center(
                child: TextButton(
                  onPressed: _navigateToLogin,
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 15, color: Colors.black87),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: Color(0xFF5E35B1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
            
// =========================================================
// 2. LOGIN SCREEN (With Biometric Fingerprint & Session Support)
// =========================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handles Biometric (Fingerprint) Authentication
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

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to log into TeacherConnect',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
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
          content: Text('Biometric Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Handles standard Phone & Password login
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final payload = {
        'phoneNumber': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;

        final userMap = data['user'] ?? {};
        final String userRole = userMap['role'] ?? 'Member Teacher';
        final String userName = userMap['fullName'] ?? 'Teacher';
        final String userPhone = userMap['phone'] ?? userMap['phoneNumber'] ?? _phoneController.text.trim();

        // Save session data locally so fingerprint authentication can load this specific user
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedPhone', userPhone);
        await prefs.setString('savedName', userName);
        await prefs.setString('savedRole', userRole);
        await prefs.setBool('isLoggedIn', true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Color(0xFF00897B),
            duration: Duration(seconds: 2),
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
            content: Text(data['message'] ?? 'Invalid login credentials'),
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

  void _navigateToRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MemberRegistrationScreen(),
      ),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Member Login'),
        backgroundColor: const Color(0xFF00897B),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Welcome Back to',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.normal),
              ),
            ),
            const Center(
              child: Text(
                'TeacherConnect',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),

            // Phone Number
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                labelText: 'Password',
                border: const OutlineInputBorder(),
              ),
            ),

            // Forgot Password Link
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _navigateToForgotPassword,
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFF5E35B1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Login Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Biometric Fingerprint Section ---
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

            const SizedBox(height: 20),

            // Link back to Register
            Center(
              child: TextButton(
                onPressed: _navigateToRegister,
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 15, color: Colors.black87),
                    children: [
                      TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Register',
                        style: TextStyle(
                          color: Color(0xFF5E35B1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
                                                                                         
// =========================================================
// 3. FORGOT & RESET PASSWORD SCREENS
// =========================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestResetToken() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final payload = {'identifier': _phoneController.text.trim()};

      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset code generated successfully!'),
            backgroundColor: Color(0xFF00897B),
          ),
        );

        // Navigate to Reset Password Screen with the phone number
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              identifier: _phoneController.text.trim(),
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to send reset code'),
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
        title: const Text('Forgot Password'),
        backgroundColor: const Color(0xFF00897B),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Reset Your Password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your registered phone number below. We will generate a verification code for you to reset your password.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _requestResetToken,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Send Reset Code',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  final String identifier;
  const ResetPasswordScreen({Key? key, required this.identifier}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

    Future<void> _submitNewPassword() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final payload = {
        'identifier': widget.identifier,
        'token': _tokenController.text.trim(),
        'newPassword': _newPasswordController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password successfully reset! Please login.'),
            backgroundColor: Color(0xFF00897B),
          ),
        );

        // Pop back to Login Screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Invalid or expired code'),
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
        title: const Text('Set New Password'),
        backgroundColor: const Color(0xFF00897B),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter Verification Code',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-digit reset code generated for ${widget.identifier} and your new password.',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.security),
                labelText: 'Reset Code / Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                labelText: 'New Password',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _submitNewPassword,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Reset Password',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
                                                
// =========================================================
// 1. TEACHER PORTAL TABLES (GROUPED BY SUBJECT COMBINATION)
// =========================================================
class TeacherPortalTables {
  static String _getListingDisplayName(
    ListingModel listing,
    String Function(ListingModel)? getDisplayName,
  ) {
    if (getDisplayName != null) {
      return getDisplayName(listing);
    }
    if (listing.isPaid) {
      return listing.teacherName.isNotEmpty ? listing.teacherName : 'N/A';
    }
    final String subjectText =
        listing.subject.isNotEmpty ? listing.subject : 'Subject Unspecified';
    final String catLower = listing.category.toLowerCase();
    if ((catLower.contains('vacancy') || catLower.contains('bom')) &&
        !catLower.contains('seeking')) {
      return '$subjectText Vacancy';
    } else {
      return '$subjectText Teacher';
    }
  }

  static Map<String, List<ListingModel>> _groupBySubject(List<ListingModel> listings) {
    final Map<String, List<ListingModel>> grouped = {};
    for (var listing in listings) {
      final subjectKey = listing.subject.trim().isNotEmpty 
          ? listing.subject.trim() 
          : 'Subject Unspecified';
      if (!grouped.containsKey(subjectKey)) {
        grouped[subjectKey] = [];
      }
      grouped[subjectKey]!.add(listing);
    }
    return grouped;
  }

  static Widget buildTscSwapsTable({
    required BuildContext context,
    required List<ListingModel> listings,
    required bool Function(ListingModel) isUnlocked,
    String Function(ListingModel)? getDisplayName,
    required Function(BuildContext, ListingModel) onPayPressed,
  }) {
    if (listings.isEmpty) {
      return const Center(child: Text("No TSC Swaps available."));
    }

    final groupedListings = _groupBySubject(listings);

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: groupedListings.entries.map((entry) {
        final subject = entry.key;
        final subjectListings = entry.value;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              subject,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.teal,
              ),
            ),
            subtitle: Text('${subjectListings.length} swap(s) available'),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                  columns: const [
                    DataColumn(label: Text('Teacher', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Current Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Target Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: subjectListings.map((listing) {
                    final unlocked = isUnlocked(listing);
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _getListingDisplayName(listing, getDisplayName),
                            style: TextStyle(
                              fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
                              color: unlocked ? Colors.black87 : Colors.teal.shade800,
                            ),
                          ),
                        ),
                        DataCell(Text(listing.currentCounty)),
                        DataCell(Text(listing.targetCounty)),
                        DataCell(
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: unlocked ? Colors.teal : Colors.orange.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => onPayPressed(context, listing),
                            child: Text(
                              unlocked ? 'View Details' : 'Pay to view full details',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget buildBomJobsTable({
    required BuildContext context,
    required List<ListingModel> listings,
    required bool Function(ListingModel) isUnlocked,
    String Function(ListingModel)? getDisplayName,
    required Function(BuildContext, ListingModel) onPayPressed,
  }) {
    if (listings.isEmpty) {
      return const Center(child: Text("No BOM Vacancies available."));
    }

    final groupedListings = _groupBySubject(listings);

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: groupedListings.entries.map((entry) {
        final subject = entry.key;
        final subjectListings = entry.value;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              subject,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.teal,
              ),
            ),
            subtitle: Text('${subjectListings.length} vacancy/vacancies available'),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                  columns: const [
                    DataColumn(label: Text('School / Vacancy', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Salary', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: subjectListings.map((listing) {
                    final unlocked = isUnlocked(listing);
                    final String schoolDisplay = unlocked
                        ? (listing.schoolName.isNotEmpty ? listing.schoolName : 'N/A')
                        : _getListingDisplayName(listing, getDisplayName);

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            schoolDisplay,
                            style: TextStyle(
                              fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
                              color: unlocked ? Colors.black87 : Colors.teal.shade800,
                            ),
                          ),
                        ),
                        DataCell(Text(listing.currentCounty)),
                        DataCell(Text(listing.salary.isNotEmpty ? listing.salary : 'N/A')),
                        DataCell(
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: unlocked ? Colors.teal : Colors.orange.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => onPayPressed(context, listing),
                            child: Text(
                              unlocked ? 'View Details' : 'Pay to view full details',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  static Widget buildSeekingBomTable({
    required BuildContext context,
    required List<ListingModel> listings,
    required bool Function(ListingModel) isUnlocked,
    String Function(ListingModel)? getDisplayName,
    required Function(BuildContext, ListingModel) onPayPressed,
  }) {
    if (listings.isEmpty) {
      return const Center(child: Text("No Seekers listed."));
    }

    final groupedListings = _groupBySubject(listings);

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: groupedListings.entries.map((entry) {
        final subject = entry.key;
        final subjectListings = entry.value;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              subject,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.teal,
              ),
            ),
            subtitle: Text('${subjectListings.length} seeker(s) available'),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                  columns: const [
                    DataColumn(label: Text('Teacher', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: subjectListings.map((listing) {
                    final unlocked = isUnlocked(listing);
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _getListingDisplayName(listing, getDisplayName),
                            style: TextStyle(
                              fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
                              color: unlocked ? Colors.black87 : Colors.teal.shade800,
                            ),
                          ),
                        ),
                        DataCell(Text(listing.currentCounty)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: listing.isTscCompliant ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              listing.isTscCompliant ? 'TSC compliant' : 'Not TSC compliant',
                              style: TextStyle(
                                color: listing.isTscCompliant ? Colors.green.shade900 : Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: unlocked ? Colors.teal : Colors.orange.shade800,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => onPayPressed(context, listing),
                            child: Text(
                              unlocked ? 'View Details' : 'Pay to view full details',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// =========================================================
// TEACHER PORTAL MAIN SCREEN
// =========================================================
class TeacherPortalScreen extends StatefulWidget {
  final String userName;
  final String userRole;
  final String userPhone;

  const TeacherPortalScreen({
    Key? key,
    required this.userName,
    required this.userRole,
    required this.userPhone,
  }) : super(key: key);

  @override
  State<TeacherPortalScreen> createState() => _TeacherPortalScreenState();
}

class _TeacherPortalScreenState extends State<TeacherPortalScreen> {
  bool get isAdmin {
    final role = widget.userRole.toLowerCase().trim();
    return role.contains('admin') || role.contains('administrator');
  }

  // Master lists for listings in each category
  List<ListingModel> tscSwaps = [];
  List<ListingModel> bomJobs = [];
  List<ListingModel> seekingBom = [];

  bool isLoading = true;
  String errorMessage = '';
  Map<String, dynamic>? activeAnnouncement;

  final String _baseUrl = 'https://teacher-connect-backend.vercel.app';

  @override
  void initState() {
    super.initState();
    _fetchListings();
    _fetchActiveAnnouncement();
  }

  Future<void> _fetchListings() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final url = Uri.parse('$_baseUrl/api/listings?limit=500');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rawData = [];

        if (decoded is List) {
          rawData = decoded;
        } else if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          rawData = decoded['data'] as List<dynamic>;
        }

        final List<ListingModel> allListings = rawData.map((item) {
          return ListingModel.fromJson(item as Map<String, dynamic>);
        }).toList();

        if (mounted) {
          setState(() {
            tscSwaps = allListings.where((item) {
              final cat = item.category.toLowerCase();
              return cat.contains('swap') || cat.contains('tsc');
            }).toList();

            bomJobs = allListings.where((item) {
              final cat = item.category.toLowerCase();
              return (cat.contains('vacancy') || cat.contains('bom')) &&
                  !cat.contains('seeking');
            }).toList();

            seekingBom = allListings.where((item) {
              final cat = item.category.toLowerCase();
              return cat.contains('seeking') || cat.contains('seeker');
            }).toList();

            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = 'Failed to load listings (${response.statusCode})';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching portal listings: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Network error fetching listings.';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchActiveAnnouncement() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/announcement/active'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['announcement'] != null) {
          if (mounted) {
            setState(() {
              activeAnnouncement = decoded['announcement'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching announcement: $e');
    }
  }

  bool isListingUnlocked(ListingModel listing) {
    return isAdmin || listing.isPaid;
  }

  // Helper method to format display text based on payment status and category
  String _getDisplayName(ListingModel listing) {
    if (isListingUnlocked(listing)) {
      return listing.teacherName.isNotEmpty ? listing.teacherName : 'N/A';
    }

    final String subjectText = listing.subject.isNotEmpty ? listing.subject : 'Subject Unspecified';
    final String catLower = listing.category.toLowerCase();

    if ((catLower.contains('vacancy') || catLower.contains('bom')) && !catLower.contains('seeking')) {
      return '$subjectText Vacancy';
    } else {
      return '$subjectText Teacher';
    }
  }

  // Helper modal to view full contact details when unlocked or accessed by Admin
  void _showContactDetailsModal(BuildContext context, ListingModel listing) {
    final String currentLoc = listing.subCounty.isNotEmpty
        ? '${listing.currentCounty} (${listing.subCounty})'
        : (listing.currentCounty.isNotEmpty ? listing.currentCounty : 'N/A');

    final String targetLoc = listing.targetCounty.isNotEmpty
        ? (listing.targetSubCounty.isNotEmpty
            ? '${listing.targetCounty} (${listing.targetSubCounty})'
            : listing.targetCounty)
        : 'N/A';

    final String displayName = _getDisplayName(listing);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contact Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(
                'Listing Profile: $displayName',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isListingUnlocked(listing) ? Colors.black87 : Colors.teal.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'TSC Number: ${listing.tscNumber ?? "N/A"}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Current School: ${listing.schoolName.isNotEmpty ? listing.schoolName : "N/A"}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Location: $currentLoc',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Target Location: $targetLoc',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Subjects: ${listing.subject.isNotEmpty ? listing.subject : "N/A"}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Phone Number: ${listing.contactPhone}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentModal(BuildContext context, ListingModel listing) {
    if (isListingUnlocked(listing)) {
      _showContactDetailsModal(context, listing);
      return;
    }

    final TextEditingController phoneController =
        TextEditingController(text: widget.userPhone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unlock Contact Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Pay KSh 100 to unlock details for ${_getDisplayName(listing)}:'),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (e.g. 0712345678)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _triggerMpesaPayment(
                    context,
                    amount: 100,
                    phone: phoneController.text.trim(),
                  );
                },
                child: const Text(
                  'Pay via M-Pesa STK Push',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _triggerMpesaPayment(
    BuildContext context, {
    required double amount,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/mpesa/stkpush'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phone,
          'amount': amount,
        }),
      );

      if (!context.mounted) return false;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('M-Pesa prompt sent! Check your phone to enter PIN.'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Request Failed: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to server: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  void _showPostDialog(BuildContext context) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DynamicPostListingModal(
        userName: widget.userName,
        userPhone: widget.userPhone,
      ),
    );

    if (result == true) {
      _fetchListings();
    }
  }

  Future<void> _handleLogout() async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );

  if (confirm != true) return;

  final prefs = await SharedPreferences.getInstance();
  
  // ❌ REMOVE await prefs.clear(); so you don't delete the fingerprint cache!
  
  // ✅ Instead, just update your active session flag:
  await prefs.setBool('isLoggedIn', false);
  // (Optional: clear auth tokens if you use them, e.g., await prefs.remove('token');)

  if (!mounted) return;

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const AuthScreen()),
  );
}

// Keep your existing helper as is:
  Widget _buildTabBody(Widget tableWidget) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchListings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchListings,
      child: tableWidget,
    );
  }
            
  Widget _buildAnnouncementBanner() {
    if (activeAnnouncement == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFFE0F2F1),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign, color: Color(0xFF00897B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeAnnouncement!['title'] ?? 'Official Notice',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF004D40),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activeAnnouncement!['message'] ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () {
              setState(() {
                activeAnnouncement = null;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('Teacher Portal'),
          backgroundColor: Colors.teal,
          actions: [
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Admin Dashboard',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminDashboardScreen(
                        adminName: widget.userName,
                        adminPhone: widget.userPhone,
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            isScrollable: true,
            tabs: [
              Tab(text: 'TSC Swaps'),
              Tab(text: 'BOM Jobs'),
              Tab(text: 'Seeking BOM'),
              Tab(text: 'Teacher Resources'),
            ],
          ),
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.teal,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'T',
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.userName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.userPhone,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline, color: Color(0xFF00897B)),
                title: const Text('Help & Support'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HelpSupportScreen(
                        userName: widget.userName,
                        userPhone: widget.userPhone,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.teal.shade50,
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text(
                      widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'T',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text('Role: ${widget.userRole}'),
                    ],
                  ),
                ],
              ),
            ),
            
            // Announcement banner display
            _buildAnnouncementBanner(),

            Expanded(
              child: TabBarView(
                children: [
                  _buildTabBody(
                    TeacherPortalTables.buildTscSwapsTable(
                      context: context,
                      listings: tscSwaps,
                      isUnlocked: isListingUnlocked,
                      getDisplayName: _getDisplayName,
                      onPayPressed: _showPaymentModal,
                    ),
                  ),
                  _buildTabBody(
                    TeacherPortalTables.buildBomJobsTable(
                      context: context,
                      listings: bomJobs,
                      isUnlocked: isListingUnlocked,
                      getDisplayName: _getDisplayName,
                      onPayPressed: _showPaymentModal,
                    ),
                  ),
                  _buildTabBody(
                    TeacherPortalTables.buildSeekingBomTable(
                      context: context,
                      listings: seekingBom,
                      isUnlocked: isListingUnlocked,
                      getDisplayName: _getDisplayName,
                      onPayPressed: _showPaymentModal,
                    ),
                  ),
                  TeacherResourcesTab(userRole: widget.userRole),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showPostDialog(context),
          backgroundColor: Colors.teal,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
                                                                                                                                                                                                                             
// ==========================================
// 3. ADMIN DASHBOARD MODULE
// ==========================================

class AdminDashboardScreen extends StatefulWidget {
  final String adminName;
  final String adminPhone;

  const AdminDashboardScreen({
    Key? key,
    required this.adminName,
    this.adminPhone = '',
  }) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  final Map<String, dynamic> _stats = {
    'totalListings': 0,
    'pendingApprovals': 0,
    'paymentsReceived': 0,
    'totalMembers': 0,
    'totalSupportTickets': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/stats'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _stats['totalListings'] = data['totalListings'] ?? 0;
            _stats['pendingApprovals'] = data['pendingApprovals'] ?? 0;
            _stats['paymentsReceived'] = data['paymentsReceived'] ?? 0;
            _stats['totalMembers'] = data['totalMembers'] ?? 0;
            _stats['totalSupportTickets'] = data['totalSupportTickets'] ?? 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load stats (${response.statusCode})';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showPostAnnouncementDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Broadcast Notice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Notice Title',
                  hintText: 'e.g., TSC Mutual Swap Updates',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message Content',
                  hintText: 'Type announcement details here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          messageController.text.trim().isEmpty) {
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('auth_token') ?? '';

                        final response = await http.post(
                          Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/announcement'),
                          headers: {
                            'Content-Type': 'application/json',
                            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode({
                            'title': titleController.text.trim(),
                            'message': messageController.text.trim(),
                            'authorName': widget.adminName,
                          }),
                        );

                        if (response.statusCode == 200 || response.statusCode == 201) {
                          Navigator.pop(dialogContext);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Announcement broadcast live!'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        } else {
                          setDialogState(() => isSubmitting = false);
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Publish Notice', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text(
            'Are you sure you want to log out of your account?',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                if (!mounted) return;

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AuthScreen(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 22),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.teal),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayName =
        widget.adminName.isNotEmpty ? widget.adminName : 'Samuel Oino';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ChoiceChip(
              avatar: const Icon(Icons.person, size: 18, color: Colors.teal),
              label: const Text(
                'User Mode',
                style: TextStyle(fontSize: 12, color: Colors.teal),
              ),
              selected: false,
              backgroundColor: Colors.white,
              onSelected: (_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeacherPortalScreen(
                      userName: displayName,
                      userRole: 'Administrator',
                      userPhone: widget.adminPhone,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log Out',
            onPressed: () => _confirmLogout(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ADMIN PROFILE CARD ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.teal.shade100,
                        child: const Icon(
                          Icons.admin_panel_settings,
                          size: 32,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.adminPhone.isNotEmpty
                                  ? 'Role: Administrator • ${widget.adminPhone}'
                                  : 'Role: Administrator',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- SYSTEM OVERVIEW ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'System Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: Colors.teal),
                    onPressed: _fetchDashboardStats,
                    tooltip: 'Refresh Stats',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: _fetchDashboardStats,
                        icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                        label: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard(
                      title: 'Total Listings',
                      value: '${_stats['totalListings']}',
                      icon: Icons.list_alt,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageListingsScreen(),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    _buildStatCard(
                      title: 'Total Members',
                      value: '${_stats['totalMembers']}',
                      icon: Icons.people,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TotalMembersScreen(),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    _buildStatCard(
                      title: 'Payments Received',
                      value: 'KSh ${_stats['paymentsReceived']}',
                      icon: Icons.payments,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentHistoryScreen(
                              userPhoneNumber: widget.adminPhone,
                            ),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    _buildStatCard(
                      title: 'Pending Approvals',
                      value: '${_stats['pendingApprovals']}',
                      icon: Icons.pending_actions,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PendingApprovalsScreen(),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    _buildStatCard(
                      title: 'Support Tickets',
                      value: '${_stats['totalSupportTickets']}',
                      icon: Icons.support_agent,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Support Tickets'),
                                backgroundColor: Colors.teal,
                              ),
                              body: const AdminSupportTicketsTab(),
                            ),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // --- ADMIN ACTIONS ---
              const Text(
                'Admin Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildActionTile(
                      icon: Icons.campaign,
                      title: 'Post Broadcast Announcement',
                      onTap: () => _showPostAnnouncementDialog(context),
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.dashboard,
                      title: 'Manage All Listings',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageListingsScreen(),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.swap_horiz,
                      title: 'TSC Swaps',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageListingsScreen(
                              categoryType: 'TSC Swap',
                            ),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.work,
                      title: 'BOM Vacancies',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageListingsScreen(
                              categoryType: 'BOM Vacancy',
                            ),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.person_search,
                      title: 'BOM Job Seekers',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageListingsScreen(
                              categoryType: 'Seeking BOM Job',
                            ),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.how_to_reg,
                      title: 'Pending Approvals',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PendingApprovalsScreen(),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                    const Divider(height: 1),
                    _buildActionTile(
                      icon: Icons.support_agent,
                      title: 'Member Support Tickets',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Support Tickets'),
                                backgroundColor: Colors.teal,
                              ),
                              body: const AdminSupportTicketsTab(),
                            ),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
                       
// ==========================================
// ADMIN SUPPORT TICKETS TAB WIDGET
// ==========================================

class AdminSupportTicketsTab extends StatefulWidget {
  const AdminSupportTicketsTab({Key? key}) : super(key: key);

  @override
  State<AdminSupportTicketsTab> createState() => _AdminSupportTicketsTabState();
}

class _AdminSupportTicketsTabState extends State<AdminSupportTicketsTab> {
  List<dynamic> tickets = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/support'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            tickets = decoded is List ? decoded : (decoded['tickets'] ?? decoded['data'] ?? []);
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = 'Failed to load support tickets (${response.statusCode}).';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Network error fetching tickets.';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _dismissTicket(String ticketId, int index) async {
    try {
      final response = await http.delete(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/support/$ticketId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          tickets.removeAt(index);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support ticket dismissed successfully'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to dismiss ticket'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error dismissing ticket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchTickets,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (tickets.isEmpty) {
      return const Center(
        child: Text('No support tickets submitted yet.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTickets,
      child: ListView.builder(
        itemCount: tickets.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          final ticketId = ticket['_id'] ?? ticket['id'] ?? '';
          final fullName = ticket['fullName'] ?? ticket['name'] ?? 'Unknown Teacher';
          final phone = ticket['phoneNumber'] ?? ticket['phone'] ?? '';
          final subject = ticket['subject'] ?? 'No Subject';
          final message = ticket['message'] ?? '';

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP LINE: Subject Subtitle (Left) & Delete Button (Right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Subject: $subject',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF00897B),
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        tooltip: 'Dismiss Ticket',
                        onPressed: () => _dismissTicket(ticketId, index),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. SECOND LINE: Teacher Name & Phone Number
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        phone,
                        style: const TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // 3. THIRD LINE: Ticket Message Body
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
     
// ==========================================
// MANAGE ALL LISTINGS (CLEANED PAGINATED UI)
// ==========================================
class ManageListingsScreen extends StatefulWidget {
  final String? categoryType;

  const ManageListingsScreen({Key? key, this.categoryType}) : super(key: key);

  @override
  State<ManageListingsScreen> createState() => _ManageListingsScreenState();
}

class _ManageListingsScreenState extends State<ManageListingsScreen> {
  List<ListingModel> _listings = [];
  bool _isLoading = true;

  final String _baseUrl = 'https://teacher-connect-backend.vercel.app';

  @override
  void initState() {
    super.initState();
    _fetchListings();
  }

  Future<void> _fetchListings() async {
    setState(() => _isLoading = true);

    final String activeType = widget.categoryType ?? '';
    final String categoryQueryParam = activeType.isNotEmpty
        ? '&category=${Uri.encodeComponent(activeType)}'
        : '';

    final url = Uri.parse(
      '$_baseUrl/api/listings?limit=1000&isAdmin=true$categoryQueryParam',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rawData = [];

        if (decoded is List) {
          rawData = decoded;
        } else if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          rawData = decoded['data'] as List<dynamic>;
        }

        final List<ListingModel> loadedListings = rawData.map((item) {
          return ListingModel.fromJson(item as Map<String, dynamic>);
        }).toList();

        if (mounted) {
          setState(() {
            _listings = loadedListings;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching listings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteListing(String id) async {
    if (id.isEmpty) return;
    final url = Uri.parse('$_baseUrl/api/listings/$id');
    try {
      final response = await http.delete(url);
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted successfully')),
        );
        _fetchListings();
      }
    } catch (e) {
      debugPrint('Error deleting listing: $e');
    }
  }

  Future<void> _approveSwap(String swapId) async {
    if (swapId.isEmpty) return;
    final url = Uri.parse('$_baseUrl/api/listings/$swapId');
    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'approved', 'isApproved': true}),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchListings();
      }
    } catch (e) {
      debugPrint('Error approving listing: $e');
    }
  }

  void _editListing(ListingModel listing) {
    final teacherNameCtrl = TextEditingController(text: listing.teacherName);
    final schoolNameCtrl = TextEditingController(text: listing.schoolName);
    final subjectCtrl = TextEditingController(text: listing.subject);
    final currentCountyCtrl = TextEditingController(text: listing.currentCounty);
    final targetCountyCtrl = TextEditingController(text: listing.targetCounty);
    final contactPhoneCtrl = TextEditingController(text: listing.contactPhone);
    final tscNumberCtrl = TextEditingController(text: listing.tscNumber ?? '');
    final salaryCtrl = TextEditingController(text: listing.salary);
    final categoryCtrl = TextEditingController(text: listing.category);
    bool isTscCompliant = listing.isTscCompliant;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Listing Data',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: teacherNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Teacher / User Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: schoolNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'School Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Subject Combination', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: currentCountyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Current Location / County', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetCountyCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Target Location / County', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: salaryCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Salary (BOM Jobs)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contactPhoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Contact Phone', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tscNumberCtrl,
                      decoration: const InputDecoration(
                          labelText: 'TSC Number', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Category', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('TSC Compliant'),
                      value: isTscCompliant,
                      onChanged: (val) {
                        setModalState(() {
                          isTscCompliant = val ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          if (listing.id.isNotEmpty) {
                            await _updateListingOnServer(listing.id, {
                              'teacherName': teacherNameCtrl.text.trim(),
                              'schoolName': schoolNameCtrl.text.trim(),
                              'subject': subjectCtrl.text.trim(),
                              'currentCounty': currentCountyCtrl.text.trim(),
                              'targetCounty': targetCountyCtrl.text.trim(),
                              'salary': salaryCtrl.text.trim(),
                              'contactPhone': contactPhoneCtrl.text.trim(),
                              'tscNumber': tscNumberCtrl.text.trim(),
                              'category': categoryCtrl.text.trim(),
                              'isTscCompliant': isTscCompliant,
                            });
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            _fetchListings();
                          }
                        },
                        child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateListingOnServer(String id, Map<String, dynamic> updateData) async {
    if (id.isEmpty) return;
    final url = Uri.parse('$_baseUrl/api/listings/$id');
    try {
      await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );
    } catch (e) {
      debugPrint('Error updating listing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String activeCategory = widget.categoryType ?? '';
    final String titleText = activeCategory.isNotEmpty
        ? 'Manage $activeCategory Listings'
        : 'Manage All Listings';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
              ? const Center(child: Text("No listings found."))
              : RefreshIndicator(
                  onRefresh: _fetchListings,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: PaginatedDataTable(
                      showCheckboxColumn: false,
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('Teacher / User', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Current Location', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Target / Salary', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('School', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('TSC No.', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Compliance', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      source: _ListingDataTableSource(
                        _listings,
                        onApprove: _approveSwap,
                        onEdit: _editListing,
                        onDelete: _deleteListing,
                      ),
                    ),
                  ),
                ),
    );
  }
}

// ==========================================
// DATA SOURCE WITH EXACT CELL ALIGNMENT
// ==========================================
class _ListingDataTableSource extends DataTableSource {
  final List<ListingModel> _listings;
  final Function(String) onApprove;
  final Function(ListingModel) onEdit;
  final Function(String) onDelete;

  _ListingDataTableSource(
    this._listings, {
    required this.onApprove,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= _listings.length) return null;

    final listing = _listings[index];
    final String tsc = listing.tscNumber ?? 'N/A';

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (index.isEven) {
            return Colors.teal.shade50.withOpacity(0.3);
          }
          return null;
        },
      ),
      cells: [
        DataCell(Text(listing.teacherName)),
        DataCell(Text(listing.category)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(listing.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        DataCell(Text(listing.currentCounty)),
        DataCell(Text(listing.salary.isNotEmpty ? listing.salary : listing.targetCounty)),
        DataCell(Text(listing.schoolName.isNotEmpty ? listing.schoolName : 'N/A')),
        DataCell(Text(listing.contactPhone)),
        // Explicit TSC Number display cell
        DataCell(Text(tsc)),
        // Updated Compliance badge label
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: listing.isTscCompliant ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              listing.isTscCompliant ? 'TSC compliant' : 'Not TSC compliant',
              style: TextStyle(
                color: listing.isTscCompliant ? Colors.green.shade900 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: listing.isApproved ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              listing.isApproved ? 'Approved' : 'Pending',
              style: TextStyle(
                color: listing.isApproved ? Colors.green.shade900 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!listing.isApproved)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  tooltip: 'Approve',
                  onPressed: () => onApprove(listing.id),
                ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => onEdit(listing),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => onDelete(listing.id),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _listings.length;

  @override
  int get selectedRowCount => 0;
}

// ==========================================
// PENDING APPROVALS MODULE (4 CATEGORIES)
// ==========================================

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  List<dynamic> _pendingSwaps = [];
  List<dynamic> _pendingBomSeekers = [];
  List<dynamic> _pendingBomVacancies = [];
  List<dynamic> _pendingMembers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchAllPendingApprovals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllPendingApprovals() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/pending-approvals'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _pendingSwaps = data['swaps'] ?? [];
          _pendingBomSeekers = data['bomSeekers'] ?? [];
          _pendingBomVacancies = data['bomVacancies'] ?? [];
          _pendingMembers = data['members'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching pending approvals: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleApprovalAction(String id, String type, bool isApprove) async {
    final action = isApprove ? 'approve' : 'reject';
    try {
      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/$action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'type': type}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isApprove ? "Approved" : "Rejected"} successfully.',
            ),
            backgroundColor: isApprove ? Colors.green : Colors.red,
          ),
        );
        _fetchAllPendingApprovals();
      }
    } catch (e) {
      debugPrint('Error executing $action: $e');
    }
  }

  Widget _buildTableTab({
    required List<dynamic> items,
    required List<String> headers,
    required DataTableSource source,
  }) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No pending approvals in this category.',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllPendingApprovals,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          width: double.infinity,
          child: PaginatedDataTable(
            rowsPerPage: PaginatedDataTable.defaultRowsPerPage,
            showCheckboxColumn: false,
            columnSpacing: 16,
            horizontalMargin: 12,
            columns: headers
                .map((h) => DataColumn(
                      label: Text(
                        h,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ))
                .toList(),
            source: source,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchAllPendingApprovals,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amber,
          tabs: [
            Tab(text: 'TSC Swaps (${_pendingSwaps.length})'),
            Tab(text: 'BOM Job Seekers (${_pendingBomSeekers.length})'),
            Tab(text: 'BOM Vacancies (${_pendingBomVacancies.length})'),
            Tab(text: 'New Members (${_pendingMembers.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. SEEKING SWAP TABLE (4 COLUMNS)
          _buildTableTab(
            items: _pendingSwaps,
            headers: const ['Applicant', 'Subjects', 'Counties', 'Actions'],
            source: _PendingApprovalTableSource(
              items: _pendingSwaps,
              type: 'swap',
              onAction: _handleApprovalAction,
            ),
          ),

          // 2. SEEKING BOM JOBS TABLE (4 COLUMNS)
          _buildTableTab(
            items: _pendingBomSeekers,
            headers: const ['Teacher', 'Subjects', 'Target Location', 'Actions'],
            source: _PendingApprovalTableSource(
              items: _pendingBomSeekers,
              type: 'bom_seeker',
              onAction: _handleApprovalAction,
            ),
          ),

          // 3. AVAILABLE BOM JOBS TABLE (4 COLUMNS)
          _buildTableTab(
            items: _pendingBomVacancies,
            headers: const ['School Name', 'Subject Needed', 'County', 'Actions'],
            source: _PendingApprovalTableSource(
              items: _pendingBomVacancies,
              type: 'bom_vacancy',
              onAction: _handleApprovalAction,
            ),
          ),

          // 4. NEW MEMBER REGISTRATIONS TABLE (4 COLUMNS)
          _buildTableTab(
            items: _pendingMembers,
            headers: const ['Full Name', 'Phone Number', 'TSC / ID Number', 'Actions'],
            source: _PendingApprovalTableSource(
              items: _pendingMembers,
              type: 'member',
              onAction: _handleApprovalAction,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4-COLUMN PAGINATED DATA TABLE SOURCE
// ==========================================

class _PendingApprovalTableSource extends DataTableSource {
  final List<dynamic> items;
  final String type;
  final Function(String id, String type, bool isApprove) onAction;

  _PendingApprovalTableSource({
    required this.items,
    required this.type,
    required this.onAction,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= items.length) return null;

    final item = items[index];
    final String id = item['_id'] ?? item['id'] ?? '';

    String col1 = 'N/A';
    String col2 = 'N/A';
    String col3 = 'N/A';

    switch (type) {
      case 'swap':
        col1 = item['fullName'] ?? item['name'] ?? 'N/A';
        col2 = '${item['subject1'] ?? ''} / ${item['subject2'] ?? ''}';
        col3 = '${item['county'] ?? ''} -> ${item['targetCounty'] ?? ''}';
        break;

      case 'bom_seeker':
        col1 = item['fullName'] ?? item['name'] ?? 'N/A';
        col2 = '${item['subject1'] ?? ''} / ${item['subject2'] ?? ''}';
        col3 = item['county'] ?? item['targetCounty'] ?? 'N/A';
        break;

      case 'bom_vacancy':
        col1 = item['schoolName'] ?? item['title'] ?? 'N/A';
        col2 = item['subject'] ?? item['subject1'] ?? 'N/A';
        col3 = item['county'] ?? 'N/A';
        break;

      case 'member':
        col1 = item['fullName'] ?? item['name'] ?? 'N/A';
        col2 = item['phoneNumber'] ?? item['phone'] ?? 'N/A';
        col3 = 'TSC: ${item['tscNumber'] ?? 'N/A'} | ID: ${item['idNumber'] ?? 'N/A'}';
        break;
    }

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(col1, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(col2)),
        DataCell(Text(col3)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                tooltip: 'Approve',
                onPressed: () => onAction(id, type, true),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'Reject',
                onPressed: () => onAction(id, type, false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => items.length;

  @override
  int get selectedRowCount => 0;
}
                                                
// ==========================================
// PAYMENT HISTORY SCREEN (PAGINATED)
// ==========================================

class PaymentHistoryScreen extends StatefulWidget {
   final String userPhoneNumber;
    
    const PaymentHistoryScreen({
    Key? key,
    required this.userPhoneNumber,
  }) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _payments = [];
  int _currentPage = 1;
  final int _limit = 15;
  bool _isLoadingInitial = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchPaymentHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _hasMore) {
      _fetchPaymentHistory(isLoadMore: true);
    }
  }

  Future<void> _fetchPaymentHistory({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isFetchingMore = true);
    } else {
      setState(() {
        _isLoadingInitial = true;
        _currentPage = 1;
        _payments.clear();
      });
    }

    final isAll = widget.userPhoneNumber == 'ALL';
    final baseUrl = isAll
        ? 'https://teacher-connect-backend.vercel.app/api/admin/payments'
        : 'https://teacher-connect-backend.vercel.app/api/payments/user/${widget.userPhoneNumber}';

    final url = Uri.parse('$baseUrl?page=$_currentPage&limit=$_limit');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        List<dynamic> newItems = [];
        if (jsonResponse is Map<String, dynamic> &&
            jsonResponse.containsKey('data')) {
          newItems = jsonResponse['data'] as List<dynamic>;
        } else if (jsonResponse is List) {
          newItems = jsonResponse;
        }

        setState(() {
          _payments.addAll(newItems);
          _hasMore = newItems.length == _limit;
          if (_hasMore) _currentPage++;
        });
      }
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment History")),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? const Center(child: Text("No transaction history found."))
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _payments.length + (_isFetchingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _payments.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final Map<String, dynamic> item =
                        _payments[index] as Map<String, dynamic>;
                    final String status =
                        (item['status'] ?? 'completed').toString().toLowerCase();
                    final bool isSuccessful =
                        status == 'completed' || status == 'successful';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long,
                            color: Colors.green),
                        title: Text(
                          "Receipt: ${item['mpesaReceiptNumber'] ?? 'N/A'}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Purpose: ${(item['purpose'] ?? 'SWAP_UNLOCK').toString().replaceAll('_', ' ').toUpperCase()}\nPhone: ${item['phoneNumber'] ?? 'N/A'}",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "KSh ${item['amount'] ?? 100}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color:
                                    isSuccessful ? Colors.green : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==========================================
// MANAGE BOM JOB SEEKERS (PAGINATED)
// ==========================================
class ManageJobSeekersScreen extends StatefulWidget {
  const ManageJobSeekersScreen({Key? key}) : super(key: key);

        @override
  State<ManageJobSeekersScreen> createState() => _ManageJobSeekersScreenState();
}

class _ManageJobSeekersScreenState extends State<ManageJobSeekersScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _seekers = [];
  int _currentPage = 1;
  final int _limit = 15;
  bool _isLoadingInitial = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchSeekers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _hasMore) {
      _fetchSeekers(isLoadMore: true);
    }
  }

  Future<void> _fetchSeekers({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isFetchingMore = true);
    } else {
      setState(() {
        _isLoadingInitial = true;
        _currentPage = 1;
        _seekers.clear();
      });
    }

    final url = Uri.parse(
        'https://teacher-connect-backend.vercel.app/api/job-seekers?page=$_currentPage&limit=$_limit');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        List<dynamic> newItems = [];
        if (decoded is List) {
          newItems = decoded;
        } else if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          newItems = decoded['data'] as List<dynamic>;
        }

        setState(() {
          _seekers.addAll(newItems);
          _hasMore = newItems.length == _limit;
          if (_hasMore) _currentPage++;
        });
      }
    } catch (e) {
      debugPrint('Error fetching job seekers: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _deleteSeeker(String id) async {
    final url = Uri.parse(
        'https://teacher-connect-backend.vercel.app/api/admin/job-seekers/$id');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job seeker deleted successfully')),
        );
        _fetchSeekers();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BOM Job Seekers'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : _seekers.isEmpty
              ? const Center(child: Text('No job seekers found.'))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _seekers.length + (_isFetchingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _seekers.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final item = _seekers[index];
                    final seekerId = item['_id'] ?? item['id'];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          item['teacherName'] ?? item['name'] ?? 'Job Seeker',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Qualification: ${item['qualification'] ?? 'N/A'}\nSubject Combo: ${item['subjects'] ?? 'N/A'}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Job Seeker'),
                                content: const Text(
                                    'Are you sure you want to remove this job seeker profile?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _deleteSeeker(seekerId);
                                    },
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ==========================================
// TOTAL MEMBERS SCREEN (PAGINATED DATATABLE)
// ==========================================

class TotalMembersScreen extends StatefulWidget {
  const TotalMembersScreen({Key? key}) : super(key: key);
  
  @override
  State<TotalMembersScreen> createState() => _TotalMembersScreenState();
}

class _TotalMembersScreenState extends State<TotalMembersScreen> {
  bool _isLoading = false;
  List<dynamic> _members = [];
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/members'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _members = data is List ? data : (data['members'] ?? []);
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load members (${response.statusCode})')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching total members: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while loading members.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberDataSource = _MemberDataTableSource(_members);

    return Scaffold(
      appBar: AppBar(
        title: Text('Total Members (${_members.length})'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Members',
            onPressed: _fetchMembers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? const Center(
                  child: Text(
                    'No registered members found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMembers,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: PaginatedDataTable(
                        header: const Text(
                          'Registered Members Directory',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        rowsPerPage: _rowsPerPage,
                        availableRowsPerPage: const [10, 20, 50],
                        onRowsPerPageChanged: (int? value) {
                          if (value != null) {
                            setState(() {
                              _rowsPerPage = value;
                            });
                          }
                        },
                        showCheckboxColumn: false,
                        columnSpacing: 20,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn(
                            label: Text(
                              '#',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Phone Number',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'TSC Number',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'ID Number',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Joined Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        source: memberDataSource,
                      ),
                    ),
                  ),
                ),
    );
  }
}

// ==========================================
// PAGINATED DATA SOURCE FOR MEMBERS
// ==========================================

class _MemberDataTableSource extends DataTableSource {
  final List<dynamic> _members;

  _MemberDataTableSource(this._members);

  @override
  DataRow? getRow(int index) {
    if (index >= _members.length) return null;

    final member = _members[index];
    final name = member['fullName'] ?? member['name'] ?? 'N/A';
    final phone = member['phoneNumber'] ?? member['phone'] ?? 'N/A';
    final tsc = member['tscNumber'] ?? member['tsc'] ?? 'N/A';

    // Resolves actual user ID card fields and ignores Mongo '_id'
    final idNum = member['idNumber'] ??
        member['nationalId'] ??
        member['idNo'] ??
        member['id'] ??
        'N/A';

    final createdAt = member['createdAt'] != null
        ? member['createdAt'].toString().split('T')[0]
        : 'N/A';

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (index.isEven) {
            return Colors.teal.shade50.withOpacity(0.3);
          }
          return null;
        },
      ),
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(phone)),
        DataCell(Text(tsc)),
        DataCell(Text(idNum)),
        DataCell(Text(createdAt)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _members.length;

  @override
  int get selectedRowCount => 0;
}                                                                           

// ============================================================================
// TEACHER RESOURCES TAB (FOLDER DIRECTORY VIEW WITH ADMIN BYPASS)
// ============================================================================
class TeacherResourcesTab extends StatefulWidget {
  final String? userRole;

  const TeacherResourcesTab({Key? key, this.userRole}) : super(key: key);

  @override
  State<TeacherResourcesTab> createState() => _TeacherResourcesTabState();
}

class _TeacherResourcesTabState extends State<TeacherResourcesTab> {
  List<dynamic> _resources = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Schemes of Work',
    'Lesson Plans',
    'Exams & Marking Schemes',
    'Setbooks & Notes',
    'Projects',
  ];

  List<String> _subjects = [
    'English',
    'Literature',
    'Kiswahili',
    'Mathematics',
    'Biology',
    'Chemistry',
    'Physics',
    'History',
    'Geography',
    'CRE',
    'Business Studies',
    'Agriculture',
    'Computer Studies',
    'Home Science',
  ];
  bool _isLoadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _fetchResources();
    _fetchDynamicSubjects();
  }

  Future<void> _fetchResources() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/resources'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _resources = data is List ? data : (data['resources'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Failed to load resources. Server returned status code ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDynamicSubjects() async {
    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/subjects'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'];
        if (mounted && data != null && data.isNotEmpty) {
          setState(() {
            _subjects = List<String>.from(data);
            _isLoadingSubjects = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching dynamic subjects: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubjects = false;
        });
      }
    }
  }
      
  Future<void> _downloadOrOpenUrl(dynamic resourceInput) async {
    String targetUrl = '';
    final String currentRole = widget.userRole?.toLowerCase() ?? '';
    final bool isAdmin = currentRole.contains('admin') || currentRole == 'administrator';

    if (resourceInput is Map) {
      final String resourceId = resourceInput['_id']?.toString() ?? resourceInput['id']?.toString() ?? '';
      if (resourceId.isNotEmpty) {
        targetUrl = 'https://teacher-connect-backend.vercel.app/api/resources/download/$resourceId?isAdmin=$isAdmin';
      }
    } else if (resourceInput is String) {
      String input = resourceInput.trim();
      if (input.isNotEmpty) {
        if (!input.startsWith('http://') && !input.startsWith('https://')) {
          targetUrl = 'https://teacher-connect-backend.vercel.app/api/resources/download/$input?isAdmin=$isAdmin';
        } else {
          targetUrl = input;
          if (targetUrl.contains('cloudinary.com') && !targetUrl.contains('fl_attachment')) {
            targetUrl = targetUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
          }
        }
      }
    }

    if (targetUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid resource link or identifier.')),
        );
      }
      return;
    }

    final Uri uri = Uri.parse(targetUrl);

    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $targetUrl')),
        );
      }
    } catch (e) {
      debugPrint('Url Launcher Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentRole = widget.userRole?.toLowerCase() ?? '';
    final bool isAdmin = currentRole.contains('admin') || currentRole == 'administrator';

    // Apply Category Filter to all resources
    final filteredResources = _selectedCategory == 'All'
        ? _resources
        : _resources.where((res) {
            final resCat = (res['category'] ?? '').toString().toLowerCase();
            final selectedCat = _selectedCategory.toLowerCase();

            if (selectedCat.contains('notes') && resCat.contains('notes')) return true;
            if (selectedCat.contains('exam') && resCat.contains('exam')) return true;
            if (selectedCat.contains('schemes') && resCat.contains('scheme')) return true;
            if (selectedCat.contains('lesson') && resCat.contains('lesson')) return true;
            if (selectedCat.contains('project') && resCat.contains('project')) return true;

            return resCat == selectedCat;
          }).toList();

    return Column(
      children: [
        // Upload Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(45),
              backgroundColor: Colors.teal,
            ),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text(
              'UPLOAD NEW RESOURCE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddResourceScreen(),
                ),
              );

              if (result == true) {
                _fetchResources();
              }
            },
          ),
        ),

        // Category Filter Chips
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  selectedColor: Colors.teal.shade100,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                ),
              );
            },
          ),
        ),

        // Folder Directory Grid View
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _fetchResources,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchResources,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12.0),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: _subjects.length,
                        itemBuilder: (context, index) {
                          final subjectName = _subjects[index];

                          final folderResources = filteredResources.where((r) {
                            final resSubject = (r['subject'] ?? '').toString().toLowerCase();
                            return resSubject == subjectName.toLowerCase();
                          }).toList();

                          final int count = folderResources.length;

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SubjectFolderDetailScreen(
                                    subject: subjectName,
                                    resources: folderResources,
                                    isAdmin: isAdmin,
                                    onDownload: _downloadOrOpenUrl,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.folder,
                                        color: Colors.teal.shade400,
                                        size: 38,
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.chevron_right, color: Colors.grey),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    subjectName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$count ${count == 1 ? 'item' : 'items'}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// ============================================================================
// SUBJECT FOLDER DETAIL SCREEN (With Admin Edit & Delete)
// ============================================================================
class SubjectFolderDetailScreen extends StatefulWidget {
  final String subject;
  final List<dynamic> resources;
  final bool isAdmin;
  final Function(dynamic) onDownload;

  const SubjectFolderDetailScreen({
    Key? key,
    required this.subject,
    required this.resources,
    required this.isAdmin,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<SubjectFolderDetailScreen> createState() => _SubjectFolderDetailScreenState();
}

class _SubjectFolderDetailScreenState extends State<SubjectFolderDetailScreen> {
  late List<dynamic> _localResources;

  @override
  void initState() {
    super.initState();
    _localResources = List.from(widget.resources);
  }

  // --- 1. EDIT RESOURCE DIALOG ---
  Future<void> _editResource(Map<String, dynamic> resource) async {
    final String resourceId = resource['_id']?.toString() ?? resource['id']?.toString() ?? '';
    final titleController = TextEditingController(text: resource['title'] ?? '');
    final priceController = TextEditingController(text: (resource['price'] ?? 50).toString());
    String selectedCategory = resource['category'] ?? 'Setbooks & Notes';

    bool? updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Resource'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Resource Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (KES)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              try {
                final response = await http.put(
                  Uri.parse('https://teacher-connect-backend.vercel.app/api/resources/$resourceId?isAdmin=true'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'title': titleController.text.trim(),
                    'price': double.tryParse(priceController.text) ?? 50.0,
                    'category': selectedCategory,
                    'subject': widget.subject,
                  }),
                );

                if (response.statusCode == 200) {
                  if (context.mounted) Navigator.pop(context, true);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: ${response.body}')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (updated == true) {
      if (mounted) {
        setState(() {
          resource['title'] = titleController.text.trim();
          resource['price'] = double.tryParse(priceController.text) ?? 50.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resource updated successfully')),
        );
      }
    }
  }

  // --- 2. DELETE RESOURCE ---
  Future<void> _deleteResource(String resourceId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resource'),
        content: const Text('Are you sure you want to delete this resource? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/resources/$resourceId?isAdmin=true'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _localResources.removeWhere((item) => (item['_id']?.toString() ?? item['id']?.toString()) == resourceId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resource deleted successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject} Folder'),
        backgroundColor: Colors.teal,
      ),
      body: _localResources.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No resources found in ${widget.subject}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: _localResources.length,
              itemBuilder: (context, index) {
                final res = _localResources[index];
                final title = res['title'] ?? 'Untitled Resource';
                final category = res['category'] ?? 'General';
                final resourceId = res['_id']?.toString() ?? res['id']?.toString() ?? '';
                double price = (res['price'] ?? 50.0).toDouble();

                if (price > 0 && price < 50) price = 50.0;
                if (price > 100) price = 100.0;

                final bool isPaidResource = price >= 50.0;
                final bool canDownloadDirectly = widget.isAdmin || !isPaidResource;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.teal,
                      size: 36,
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Category: $category${isPaidResource ? " • Price: KES ${price.toStringAsFixed(0)}" : ""}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Download / Pay Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canDownloadDirectly
                                ? Colors.teal
                                : Colors.teal.shade700,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          icon: Icon(
                            canDownloadDirectly ? Icons.download : Icons.lock_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: Text(
                            canDownloadDirectly
                                ? 'Download'
                                : 'Pay KES ${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () {
                            if (canDownloadDirectly) {
                              widget.onDownload(res);
                            } else {
                              showPaymentModal(
                                parentContext: context,
                                resourceTitle: title,
                                price: price,
                                isAdmin: widget.isAdmin,
                                onPaymentSuccess: () {
                                  widget.onDownload(res);
                                },
                              );
                            }
                          },
                        ),

                        // Admin-Only Edit Pencil Icon Button
                        if (widget.isAdmin) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            tooltip: 'Edit Resource',
                            onPressed: () => _editResource(res),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete Resource',
                            onPressed: () => _deleteResource(resourceId),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
// =========================================================================
// Payment Modal with Strict Payment Verification
// =========================================================================
void showPaymentModal({
  required BuildContext parentContext,
  required String resourceTitle,
  required double price,
  required VoidCallback onPaymentSuccess,
  bool isAdmin = false,
}) {
  if (isAdmin || price <= 0) {
    onPaymentSuccess();
    return;
  }

  TextEditingController phoneController = TextEditingController(text: "254");

  showDialog(
    context: parentContext,
    builder: (dialogContext) {
      bool isLoading = false;
      String statusMessage = "";

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text("Unlock $resourceTitle"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Price: KES ${price.toStringAsFixed(0)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "M-Pesa Phone Number",
                    hintText: "254712345678",
                    border: OutlineInputBorder(),
                  ),
                ),
                if (statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    statusMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: statusMessage.contains("failed") || statusMessage.contains("Error")
                          ? Colors.red
                          : Colors.teal,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                ),
                onPressed: isLoading
                    ? null
                    : () async {
                        String rawPhone = phoneController.text.trim();
                        String formattedPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

                        if (formattedPhone.startsWith('0')) {
                          formattedPhone = '254${formattedPhone.substring(1)}';
                        }

                        if (formattedPhone.length != 12) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid phone number (e.g., 254712345678)'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          isLoading = true;
                          statusMessage = "Sending M-Pesa prompt to phone...";
                        });

                        try {
                          final response = await http.post(
                            Uri.parse('https://teacher-connect-backend.vercel.app/api/mpesa/stkpush'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({
                              'phone': formattedPhone,
                              'amount': price,
                              'accountReference': 'ResourceDownload',
                              'transactionDesc': 'Payment for $resourceTitle',
                            }),
                          );

                          if (response.statusCode == 200) {
                            final data = jsonDecode(response.body);

                            if (data['success'] == true) {
                              final String checkoutRequestId = data['CheckoutRequestID'] ?? '';

                              setState(() {
                                statusMessage =
                                    "STK Push sent! Please enter your PIN on your phone to complete payment...";
                              });

                              bool paid = await _verifyPaymentStatus(checkoutRequestId);

                              setState(() => isLoading = false);

                              if (paid) {
                                if (Navigator.canPop(dialogContext)) {
                                  Navigator.pop(dialogContext);
                                }
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment verified! Downloading document...'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                onPaymentSuccess();
                              } else {
                                setState(() {
                                  statusMessage =
                                      "Payment verification failed or timed out. Please try again.";
                                });
                              }
                            } else {
                              setState(() {
                                isLoading = false;
                                statusMessage =
                                    data['error'] ?? 'Failed to initiate M-Pesa payment.';
                              });
                            }
                          } else {
                            setState(() {
                              isLoading = false;
                              statusMessage = 'Server error. Please try again later.';
                            });
                          }
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                            statusMessage = 'Error initiating payment: $e';
                          });
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Pay Now",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

// =========================================================================
// Helper to poll backend until M-Pesa callback updates payment status
// =========================================================================
Future<bool> _verifyPaymentStatus(String checkoutRequestId) async {
  if (checkoutRequestId.isEmpty) return false;

  for (int i = 0; i < 6; i++) {
    await Future.delayed(const Duration(seconds: 5));
    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/mpesa/query/$checkoutRequestId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'COMPLETED' || data['success'] == true) {
          return true;
        } else if (data['status'] == 'FAILED' || data['status'] == 'CANCELLED') {
          return false;
        }
      }
    } catch (_) {}
  }
  return false;
}                                                                                                                                                                                                                  

// ==========================================
// 2. RESOURCE FORM UI & API LOGIC
// ==========================================
class AddResourceScreen extends StatefulWidget {
  const AddResourceScreen({Key? key}) : super(key: key);

  @override
  State<AddResourceScreen> createState() => _AddResourceScreenState();
}

class _AddResourceScreenState extends State<AddResourceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Fields Controllers
  final TextEditingController _titleController = TextEditingController();
  String? _selectedSubject;
  String _selectedForm = 'Form 1';
  String _selectedCategory = 'Exams & Marking Schemes';

  // File Picker & Loading States
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isLoadingSubjects = true;

  // Dynamic Subject Options (Fetched from backend with full comprehensive fallback)
  List<String> _subjects = [];

  final List<String> _forms = [
    'Form 1',
    'Form 2',
    'Form 3',
    'Form 4',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  // Dropdown Options (Includes Projects)
  final List<String> _categories = [
    'Schemes of Work',
    'Lesson Plans',
    'Exams & Marking Schemes',
    'Setbooks & Notes',
    'Projects',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDynamicSubjects();
  }

  Future<void> _fetchDynamicSubjects() async {
    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/subjects'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'];
        if (mounted && data != null && data.isNotEmpty) {
          setState(() {
            _subjects = List<String>.from(data);
            if (_subjects.isNotEmpty) {
              _selectedSubject = _subjects.first;
            }
            _isLoadingSubjects = false;
          });
          return;
        }
      }
      
      // If response is empty or status isn't 200, trigger fallback
      _loadCompleteFallbackSubjects();
    } catch (e) {
      print('Error fetching dynamic subjects: $e');
      _loadCompleteFallbackSubjects();
    }
  }

  void _loadCompleteFallbackSubjects() {
  if (mounted) {
    setState(() {
      _subjects = [
        // Languages & Humanities
        'English / Literature',
        'Kiswahili / History',
        'Kiswahili / CRE',
        'Kiswahili / Geography',
        'Kiswahili / IRE',
        'History / CRE',
        'History / IRE',
        'Geography / CRE',
        'Geography / Business',
        'French / English',
        'German / Any',

        // Sciences & Mathematics (STEM)
        'Mathematics / Chemistry',
        'Mathematics / Biology',
        'Mathematics / Physics',
        'Physics / Chemistry',
        'Mathematics / Computer Studies',
        'Biology / Chemistry',

        // Technical, Applied & Business Studies
        'Business Studies / Mathematics',
        'Business Studies / Kiswahili',
        'Business Studies / History',
        'Business Studies / Computer Studies',
        'Agriculture / Biology',
        'Agriculture / Chemistry',
        'Agriculture / Geography',
        'Home Science / Biology',
        'Home Science / Chemistry',
        'Home Science / History',
        'Computer / Any',
        'HomeScience / Any',
      ];
      if (_subjects.isNotEmpty) {
        _selectedSubject = _subjects.first;
      }
      _isLoadingSubjects = false;
    });
  }
  }
      
  // Step A: Pick File Logic
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'zip'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  // Step B: Submit Form Logic (Uploads to Backend /api/upload + Posts to MongoDB /api/resources)
  Future<void> _submitResource() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1. Upload File to Backend /api/upload (handled by upload.js)
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://teacher-connect-backend.vercel.app/api/upload'),
      );

      if (_selectedFile!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          ),
        );
      } else if (_selectedFile!.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            _selectedFile!.path!,
            filename: _selectedFile!.name,
          ),
        );
      } else {
        setState(() => _isUploading = false);
        return;
      }

      var streamedResponse = await request.send();
      var uploadResponse = await http.Response.fromStream(streamedResponse);
      final responseBody = await uploadResponse.body;

      if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 201) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload file: $responseBody')),
          );
        }
        return;
      }

      final Map<String, dynamic> uploadData = jsonDecode(responseBody);
      final String? uploadedFileUrl = uploadData['fileUrl'];

      if (uploadedFileUrl == null || uploadedFileUrl.isEmpty) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server did not return a valid file URL.')),
          );
        }
        return;
      }

      // 2. Create Resource Record in MongoDB via Express /api/resources
      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/resources'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'subject': _selectedSubject,
          'form': _selectedForm,
          'category': _selectedCategory,
          'fileUrl': uploadedFileUrl,
        }),
      );

      setState(() => _isUploading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resource uploaded successfully!')),
          );
          Navigator.pop(context, true); // Return back to resources list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save resource details: ${response.body}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server connection error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Teacher Resource'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Resource Title',
                  hintText: 'e.g., Form 3 English Paper 1 Marking Scheme',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),

              // Subject Dropdown
DropdownButtonFormField<String>(
  value: _subjects.contains(_selectedSubject) ? _selectedSubject : (_subjects.isNotEmpty ? _subjects.first : null),
  isExpanded: true,
  menuMaxHeight: 380, // Enables scrolling for all 28+ subject combinations
  decoration: const InputDecoration(
    labelText: 'Subject',
    border: OutlineInputBorder(),
  ),
  items: _subjects.map((sub) => DropdownMenuItem(
    value: sub,
    child: Text(sub, overflow: TextOverflow.ellipsis),
  )).toList(),
  onChanged: (val) => setState(() => _selectedSubject = val),
),
              // Form Level Dropdown
              DropdownButtonFormField<String>(
                value: _selectedForm,
                decoration: const InputDecoration(
                  labelText: 'Class / Form',
                  border: OutlineInputBorder(),
                ),
                items: _forms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (val) => setState(() => _selectedForm = val!),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 20),

              // File Picker Selector Box
              InkWell(
                onTap: _isUploading ? null : _pickFile,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, color: Colors.teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile != null
                              ? _selectedFile!.name
                              : 'Tap to select document (PDF, DOCX, PPT, ZIP)',
                          style: TextStyle(
                            color: _selectedFile != null ? Colors.black : Colors.grey.shade700,
                            fontWeight: _selectedFile != null ? FontWeight.bold : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitResource,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade50,
                    foregroundColor: Colors.purple.shade700,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text('Uploading & Saving...'),
                          ],
                        )
                      : const Text(
                          'UPLOAD RESOURCE',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
                                                                                                                                                               
// ==========================================
// MANAGE BOM SCHOOL VACANCIES (PAGINATED)
// ==========================================
class ManageBomVacanciesScreen extends StatefulWidget {
  const ManageBomVacanciesScreen({Key? key}) : super(key: key);
      @override

  State<ManageBomVacanciesScreen> createState() =>

      _ManageBomVacanciesScreenState();

}

class _ManageBomVacanciesScreenState extends State<ManageBomVacanciesScreen> {

  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _vacancies = [];

  int _currentPage = 1;

  final int _limit = 15;

  bool _isLoadingInitial = true;

  bool _isFetchingMore = false;

  bool _hasMore = true;

  @override

  void initState() {

    super.initState();

    _fetchVacancies();

    _scrollController.addListener(_onScroll);

  }

  @override

  void dispose() {

    _scrollController.dispose();

    super.dispose();

  }

  void _onScroll() {

    if (_scrollController.position.pixels >=

            _scrollController.position.maxScrollExtent - 200 &&

        !_isFetchingMore &&

        _hasMore) {

      _fetchVacancies(isLoadMore: true);

    }

  }

  Future<void> _fetchVacancies({bool isLoadMore = false}) async {

    if (isLoadMore) {

      setState(() => _isFetchingMore = true);

    } else {

      setState(() {

        _isLoadingInitial = true;

        _currentPage = 1;

        _vacancies.clear();

      });

    }

    final url = Uri.parse(

        'https://teacher-connect-backend.vercel.app/api/bom-vacancies?page=$_currentPage&limit=$_limit');

    try {

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {

        final decoded = jsonDecode(response.body);

        List<dynamic> newItems = [];

        if (decoded is List) {

          newItems = decoded;

        } else if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {

          newItems = decoded['data'] as List<dynamic>;

        }

        setState(() {

          _vacancies.addAll(newItems);

          _hasMore = newItems.length == _limit;

          if (_hasMore) _currentPage++;

        });

      }

    } catch (e) {

      debugPrint('Error fetching BOM vacancies: $e');

    } finally {

      if (mounted) {

        setState(() {

          _isLoadingInitial = false;

          _isFetchingMore = false;

        });

      }

    }

  }

  Future<void> _deleteVacancy(String id) async {

    final url = Uri.parse(

        'https://teacher-connect-backend.vercel.app/api/admin/bom-vacancies/$id');

    try {

      final response = await http.delete(url);

      if (response.statusCode == 200) {

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Vacancy deleted successfully')),

        );

        _fetchVacancies();

      }

    } catch (_) {}

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text('BOM School Vacancies'),

        backgroundColor: Colors.teal,

      ),

      body: _isLoadingInitial

          ? const Center(child: CircularProgressIndicator())

          : _vacancies.isEmpty

              ? const Center(child: Text('No BOM vacancies found.'))

              : ListView.builder(

                  controller: _scrollController,

                  padding: const EdgeInsets.all(12),

                  itemCount: _vacancies.length + (_isFetchingMore ? 1 : 0),

                  itemBuilder: (context, index) {

                    if (index == _vacancies.length) {

                      return const Padding(

                        padding: EdgeInsets.symmetric(vertical: 16.0),

                        child: Center(child: CircularProgressIndicator()),

                      );

                    }

                    final item = _vacancies[index];

                    final vacancyId = item['_id'] ?? item['id'];

                    return Card(

                      elevation: 2,

                      margin: const EdgeInsets.symmetric(vertical: 6),

                      child: ListTile(

                        leading: const CircleAvatar(

                          backgroundColor: Colors.teal,

                          child: Icon(Icons.school, color: Colors.white),

                        ),

                        title: Text(

                          item['schoolName'] ?? item['title'] ?? 'BOM Vacancy',

                          style: const TextStyle(fontWeight: FontWeight.bold),

                        ),

                        subtitle: Text(

                          'Subject: ${item['subjects'] ?? 'N/A'}\nLocation: ${item['county'] ?? 'N/A'}',

                        ),

                        isThreeLine: true,

                        trailing: IconButton(

                          icon: const Icon(Icons.delete_outline,

                              color: Colors.red),

                          onPressed: () {

                            showDialog(

                              context: context,

                              builder: (ctx) => AlertDialog(

                                title: const Text('Delete Vacancy'),

                                content: const Text(

                                    'Are you sure you want to delete this vacancy?'),

                                actions: [

                                  TextButton(

                                    onPressed: () => Navigator.pop(ctx),

                                    child: const Text('Cancel'),

                                  ),

                                  TextButton(

                                    onPressed: () {

                                      Navigator.pop(ctx);

                                      _deleteVacancy(vacancyId);

                                    },

                                    child: const Text('Delete',

                                        style: TextStyle(color: Colors.red)),

                                  ),

                                ],

                              ),

                            );

                          },

                        ),

                      ),

                    );

                  },

                ),

    );

  }

}

// ==========================================
// 4. FREE POSTING MODAL
// ==========================================
// ==========================================
// 4. FREE POSTING MODAL
// ==========================================

class DynamicPostListingModal extends StatefulWidget {
  final String userName;
  final String userPhone;

  const DynamicPostListingModal({
    Key? key,
    required this.userName,
    required this.userPhone,
  }) : super(key: key);

  @override
  State<DynamicPostListingModal> createState() =>
      _DynamicPostListingModalState();
}

class _DynamicPostListingModalState extends State<DynamicPostListingModal> {
  String selectedType = 'TSC Swap';
  String? selectedSubject;
  bool isSubmitting = false;

  // Dynamic Subjects List & Loading state
  List<String> _subjects = [];
  bool _isLoadingSubjects = true;

  String? _selectedCounty;
  String? _selectedSubCounty;
  String? _selectedTargetCounty;
  String? _selectedTargetSubCounty;

  late TextEditingController _nameController;
  late TextEditingController _schoolController;
  late TextEditingController _tscController;
  late TextEditingController _phoneController;
  late TextEditingController _salaryController;

  final Map<String, List<String>> _countySubCountyData = {
    'Baringo': [
      'Baringo Central',
      'Baringo North',
      'Baringo South',
      'Eldama Ravine',
      'Mogotio',
      'Tiaty'
    ],
    'Bomet': [
      'Bomet Central',
      'Bomet East',
      'Chepalungu',
      'Konoin',
      'Sotik'
    ],
    'Bungoma': [
      'Bungoma Central',
      'Bungoma East',
      'Bungoma North',
      'Bungoma South',
      'Bungoma West',
      'Cheptais',
      'Kimilili',
      'Mount Elgon',
      'Sirisia',
      'Tongaren'
    ],
    'Busia': [
      'Bunyala',
      'Busia',
      'Butula',
      'Nambale',
      'Samia',
      'Teso North',
      'Teso South'
    ],
    'Elgeyo Marakwet': [
      'Keiyo North',
      'Keiyo South',
      'Marakwet East',
      'Marakwet West'
    ],
    'Embu': [
      'Embu East',
      'Embu North',
      'Embu West',
      'Mbeere North',
      'Mbeere South'
    ],
    'Garissa': [
      'Balambala',
      'Dadaab',
      'Fafi',
      'Garissa',
      'Hulugho',
      'Ijara',
      'Lagdera'
    ],
    'Homa Bay': [
      'Homa Bay',
      'Kabondo Kasipul',
      'Karachuonyo',
      'Kasipul',
      'Mbita',
      'Ndhiwa',
      'Rangwe',
      'Suba'
    ],
    'Isiolo': [
      'Garbatulla',
      'Isiolo',
      'Merti'
    ],
    'Kajiado': [
      'Isinya',
      'Kajiado Central',
      'Kajiado North',
      'Kajiado West',
      'Loitokitok',
      'Mashuuru'
    ],
    'Kakamega': [
      'Butere',
      'Kakamega Central',
      'Kakamega East',
      'Kakamega North',
      'Kakamega South',
      'Khwisero',
      'Likuyani',
      'Lugari',
      'Matungu',
      'Mumias East',
      'Mumias West',
      'Navakholo'
    ],
    'Kericho': [
      'Belgut',
      'Bureau',
      'Kericho East',
      'Kipkelion East',
      'Kipkelion West',
      'Soin/Sigowet'
    ],
    'Kiambu': [
      'Githunguri',
      'Juja',
      'Kabete',
      'Kiambaa',
      'Kiambu',
      'Kikuyu',
      'Lari',
      'Limuru',
      'Ruiru',
      'Thika East',
      'Thika West'
    ],
    'Kilifi': [
      'Ganze',
      'Kaloleni',
      'Kilifi North',
      'Kilifi South',
      'Magarini',
      'Malindi',
      'Rabai'
    ],
    'Kirinyaga': [
      'Kirinyaga Central',
      'Kirinyaga East',
      'Kirinyaga West',
      'Mwea East',
      'Mwea West'
    ],
    'Kisii': [
      'Gucha',
      'Gucha South',
      'Kenyenya',
      'Kisii Central',
      'Kisii South',
      'Kitutu Central',
      'Marani',
      'Masaba South',
      'Nyamache',
      'Sameta'
    ],
    'Kisumu': [
      'Kadibo',
      'Kisumu Central',
      'Kisumu East',
      'Kisumu West',
      'Muhoroni',
      'Nyando',
      'Nyakach'
    ],
    'Kitui': [
      'Ikutha',
      'Katulani',
      'Kitui Central',
      'Kitui Rural',
      'Kitui West',
      'Kyuso',
      'Lower Yatta',
      'Mwingi Central',
      'Mwingi East',
      'Mwingi West',
      'Nzambani'
    ],
    'Kwale': [
      'Kinango',
      'Lunga Lunga',
      'Matuga',
      'Msambweni'
    ],
    'Laikipia': [
      'Laikipia Central',
      'Laikipia East',
      'Laikipia North',
      'Laikipia West',
      'Nyahururu'
    ],
    'Lamu': [
      'Lamu East',
      'Lamu West'
    ],
    'Machakos': [
      'Athi River',
      'Kalama',
      'Kangundo',
      'Kathiani',
      'Machakos',
      'Masinga',
      'Matungulu',
      'Mwala',
      'Yatta'
    ],
    'Makueni': [
      'Kilungu',
      'Makueni',
      'Kaiti',
      'Kibwezi West',
      'Kibwezi East',
      'Mukaa'
    ],
    'Mandera': [
      'Banissa',
      'Kutulo',
      'Lafey',
      'Mandera Central',
      'Mandera East',
      'Mandera North',
      'Mandera West'
    ],
    'Marsabit': [
      'Laisamis',
      'Marsabit Central',
      'Moyale',
      'North Horr'
    ],
    'Meru': [
      'Imenti Central',
      'Imenti North',
      'Imenti South',
      'Tigania East',
      'Tigania West',
      'Igembe Central',
      'Igembe North',
      'Igembe South',
      'Buuri'
    ],
    'Migori': [
      'Awendo',
      'Kuria East',
      'Kuria West',
      'Nyatike',
      'Rongo',
      'Suna East',
      'Suna West',
      'Uriri'
    ],
    'Mombasa': [
      'Changamwe',
      'Jomvu',
      'Kisauni',
      'Likoni',
      'Mvita',
      'Nyali'
    ],
    "Murang'a": [
      'Gatanga',
      'Kandara',
      'Kangema',
      'Kigumo',
      'Kiharu',
      'Mathioya',
      "Murang'a South"
    ],
    'Nairobi': [
      'Dagoretti',
      'Embakasi',
      'Kamukunji',
      'Kasarani',
      'Kibra',
      "Lang'ata",
      'Makadara',
      'Mathare',
      'NJiru',
      'Starehe',
      'Westlands'
    ],
    'Nakuru': [
      'Gilgil',
      'Kuresoi North',
      'Kuresoi South',
      'Molo',
      'Naivasha',
      'Nakuru East',
      'Nakuru North',
      'Nakuru West',
      'Njoro',
      'Rongai',
      'Subukia'
    ],
    'Nandi': [
      'Chesumei',
      'Nandi Central',
      'Nandi East',
      'Nandi North',
      'Nandi South',
      'Tinderet'
    ],
    'Narok': [
      'Narok East',
      'Narok North',
      'Narok South',
      'Narok West',
      'Trans Mara East',
      'Trans Mara West'
    ],
    'Nyamira': [
      'Borabu',
      'Manga',
      'Masaba North',
      'Nyamira North',
      'Nyamira South'
    ],
    'Nyandarua': [
      'Kinangop',
      'Ndaragwa',
      'Ol Kalou',
      'Ol Joro Orok',
      'Nipini'
    ],
    'Nyeri': [
      'Kieni East',
      'Kieni West',
      'Mathira East',
      'Mathira West',
      'Mukurweini',
      'Nyeri Central',
      'Nyeri South',
      'Tetu'
    ],
    'Samburu': [
      'Samburu East',
      'Samburu North',
      'Samburu West'
    ],
    'Siaya': [
      'Alego Usonga',
      'Bondo',
      'Gem',
      'Rarieda',
      'Ugenya',
      'Ugunja'
    ],
    'Taita Taveta': [
      'Mwatate',
      'Taveta',
      'Taita',
      'Voi'
    ],
    'Tana River': [
      'Bura',
      'Garsen',
      'Tana Delta',
      'Tana North',
      'Tana River'
    ],
    'Tharaka Nithi': [
      'Tharaka North',
      'Tharaka South',
      'Chuka',
      "Igambang'ombe",
      'Maara'
    ],
    'Trans Nzoia': [
      'Endebess',
      'Kiminini',
      'Kwanza',
      'Saboti',
      'Cherangany'
    ],
    'Turkana': [
      'Turkana Central',
      'Turkana East',
      'Turkana North',
      'Turkana South',
      'Turkana West',
      'Loima'
    ],
    'Uasin Gishu': [
      'Ainabkoi',
      'Kapseret',
      'Kesses',
      'Moiben',
      'Soy',
      'Turbo'
    ],
    'Vihiga': [
      'Emuhaya',
      'Hamisi',
      'Luanda',
      'Sabatia',
      'Vihiga'
    ],
    'Wajir': [
      'Buna',
      'Eldas',
      'Habaswein',
      'Tarbaj',
      'Wajir East',
      'Wajir North',
      'Wajir South',
      'Wajir West'
    ],
    'West Pokot': [
      'Kipkomai',
      'Pokot Central',
      'Pokot North',
      'Pokot South',
      'West Pokot'
    ],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _schoolController = TextEditingController();
    _tscController = TextEditingController();
    _phoneController = TextEditingController(text: widget.userPhone);
    _salaryController = TextEditingController();
    _fetchDynamicSubjects();
  }

  Future<void> _fetchDynamicSubjects() async {
    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/subjects'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'];
        if (mounted && data != null && data.isNotEmpty) {
          setState(() {
            _subjects = List<String>.from(data);
            selectedSubject = _subjects.first;
            _isLoadingSubjects = false;
          });
          return;
        }
      }
      _loadFallbackSubjects();
    } catch (e) {
      _loadFallbackSubjects();
    }
  }
void _loadFallbackSubjects() {
  if (mounted) {
    setState(() {
      _subjects = [
        // Languages & Humanities
        'English / Literature',
        'Kiswahili / History',
        'Kiswahili / CRE',
        'Kiswahili / Geography',
        'Kiswahili / IRE',
        'History / CRE',
        'History / IRE',
        'Geography / CRE',
        'Geography / Business',
        'French / English',
        'German / Any',

        // Sciences & Mathematics (STEM)
        'Mathematics / Chemistry',
        'Mathematics / Biology',
        'Mathematics / Physics',
        'Physics / Chemistry',
        'Mathematics / Computer Studies',
        'Biology / Chemistry',

        // Technical, Applied & Business Studies
        'Business Studies / Mathematics',
        'Business Studies / Kiswahili',
        'Business Studies / History',
        'Business Studies / Computer Studies',
        'Agriculture / Biology',
        'Agriculture / Chemistry',
        'Agriculture / Geography',
        'Home Science / Biology',
        'Home Science / Chemistry',
        'Home Science / History',
        'Computer / Any',
        'HomeScience / Any',
      ];
      selectedSubject = _subjects.first;
      _isLoadingSubjects = false;
    });
  }
}

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _tscController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_nameController.text.trim().isEmpty ||
        _selectedCounty == null ||
        _selectedSubCounty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields (Name, County, Sub-County).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedType == 'TSC Swap') {
      if (_phoneController.text.trim().isEmpty ||
          _tscController.text.trim().isEmpty ||
          _selectedTargetCounty == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in Phone, TSC Number, and Target County for TSC Swap.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => isSubmitting = true);

    String targetCountyText = _selectedTargetCounty ?? '';
    if (_selectedTargetSubCounty != null && _selectedTargetSubCounty!.isNotEmpty) {
      targetCountyText += ' (${_selectedTargetSubCounty})';
    }

    final effectivePhone = _phoneController.text.trim().isNotEmpty 
        ? _phoneController.text.trim() 
        : widget.userPhone;

    try {
      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/listings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': selectedType,
          'category': selectedType,
          'listingCategory': selectedType,
          'teacherName': _nameController.text.trim(),
          'fullName': _nameController.text.trim(),
          'name': _nameController.text.trim(),
          'subject': selectedSubject,
          'subjects': selectedSubject,
          'subjectCombination': selectedSubject,
          'currentCounty': '${_selectedCounty ?? ''} (${_selectedSubCounty ?? ''})',
          'county': _selectedCounty ?? '',
          'subCounty': _selectedSubCounty ?? '',
          'schoolName': _schoolController.text.trim(),
          'currentSchool': _schoolController.text.trim(),
          'tscNumber': _tscController.text.trim(),
          'targetCounty': targetCountyText,
          'desiredCounty': targetCountyText,
          'targetSubCounty': _selectedTargetSubCounty ?? '',
          'salary': _salaryController.text.trim(),
          'contactPhone': effectivePhone,
          'phone': effectivePhone,
          'phoneNumber': effectivePhone,
          'status': 'approved',
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing posted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${response.statusCode} - ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

@override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Post New Listing (Free)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Listing Category',
                border: OutlineInputBorder(),
              ),
              items: ['TSC Swap', 'BOM Vacancy', 'Seeking BOM Job'].map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedType = val);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _subjects.contains(selectedSubject) ? selectedSubject : null,
              isExpanded: true,
              menuMaxHeight: 380, // Enables scrolling through all 29 subject combinations
              decoration: const InputDecoration(
                labelText: 'Subject Combination',
                border: OutlineInputBorder(),
              ),
              items: _subjects.map((sub) {
                return DropdownMenuItem(
                  value: sub,
                  child: Text(sub, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedSubject = val);
                }
              },
            ),
            const SizedBox(height: 12),
   
              
            // ==========================================
            // CURRENT LOCATION (HORIZONTAL ROW)
            // ==========================================
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'County',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    ),
                    isExpanded: true,
                    value: _selectedCounty,
                    hint: const Text('County', overflow: TextOverflow.ellipsis),
                    items: _countySubCountyData.keys.map((String county) {
                      return DropdownMenuItem<String>(
                        value: county,
                        child: Text(county, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCounty = newValue;
                        _selectedSubCounty = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Sub-County',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    ),
                    isExpanded: true,
                    value: _selectedSubCounty,
                    hint: Text(
                      _selectedCounty == null ? 'Select County' : 'Sub-County',
                      overflow: TextOverflow.ellipsis,
                    ),
                    disabledHint: const Text('Select County', overflow: TextOverflow.ellipsis),
                    items: (_selectedCounty == null
                            ? <String>[]
                            : _countySubCountyData[_selectedCounty] ?? [])
                        .map((String subCounty) {
                      return DropdownMenuItem<String>(
                        value: subCounty,
                        child: Text(subCounty, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _selectedCounty == null
                        ? null
                        : (String? newValue) {
                            setState(() {
                              _selectedSubCounty = newValue;
                            });
                          },
                  ),
                ),
              ],
            ),

            if (selectedType == 'TSC Swap') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: 'Current School Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tscController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'TSC Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),            
// ==========================================
// TARGET LOCATION (HORIZONTAL ROW)
// ==========================================
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Target County',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      isExpanded: true,
                      value: _selectedTargetCounty,
                      hint: const Text('Target County', overflow: TextOverflow.ellipsis),
                      items: _countySubCountyData.keys.map((String county) {
                        return DropdownMenuItem<String>(
                          value: county,
                          child: Text(county, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTargetCounty = newValue;
                          _selectedTargetSubCounty = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Target Sub-County',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      ),
                      isExpanded: true,
                      value: _selectedTargetSubCounty,
                      hint: const Text('Optional/Any', overflow: TextOverflow.ellipsis),
                      items: _selectedTargetCounty == null
                          ? []
                          : (_countySubCountyData[_selectedTargetCounty] ?? [])
                              .map((String subCounty) {
                              return DropdownMenuItem<String>(
                                value: subCounty,
                                child: Text(subCounty, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                      onChanged: _selectedTargetCounty == null
                          ? null
                          : (String? newValue) {
                              setState(() {
                                _selectedTargetSubCounty = newValue;
                              });
                            },
                    ),
                  ),
                ],
              ),
            ],

            if (selectedType == 'BOM Vacancy') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly Salary (KSh)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: isSubmitting ? null : _handleSubmit,
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Listing (Free)',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}                           
                                          
//=============================
// class HelpSupportScreen
//=============================
class HelpSupportScreen extends StatefulWidget {
  final String userName;
  final String userPhone;

  const HelpSupportScreen({Key? key, required this.userName, required this.userPhone}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitConcern() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final payload = {
        'fullName': widget.userName,
        'phoneNumber': widget.userPhone,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/support/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Concern submitted successfully!'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
        _subjectController.clear();
        _messageController.clear();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to submit concern'),
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
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: const Color(0xFF00897B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Share Your Concerns or Feedback',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Need assistance with a swap or facing technical issues? Send a message to the administration team.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject (e.g., Swap Assistance)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe your concern...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading ? null : _submitConcern,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Concern',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ADMIN SUPPORT TICKETS SCREEN (WITH DISMISS / DELETE FUNCTIONALITY)
// ===========================================================================
class AdminSupportTicketsScreen extends StatefulWidget {
  const AdminSupportTicketsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSupportTicketsScreen> createState() => _AdminSupportTicketsScreenState();
}

class _AdminSupportTicketsScreenState extends State<AdminSupportTicketsScreen> {
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/support'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _tickets = data is List ? data : (data['tickets'] ?? data['data'] ?? []);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load tickets. Status code: ${response.statusCode}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _dismissTicket(String ticketId, int index) async {
    try {
      final response = await http.delete(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/support/$ticketId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _tickets.removeAt(index);
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support ticket dismissed successfully'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to dismiss ticket'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error dismissing ticket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        backgroundColor: const Color(0xFF00897B),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _tickets.isEmpty
                  ? const Center(
                      child: Text(
                        'No support tickets found.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = _tickets[index];
                        final ticketId = ticket['_id'] ?? ticket['id'] ?? '';
                        final fullName = ticket['fullName'] ?? ticket['name'] ?? 'Mwl. Teacher';
                        final phone = ticket['phoneNumber'] ?? ticket['phone'] ?? '';
                        final subject = ticket['subject'] ?? 'General Inquiry';
                        final message = ticket['message'] ?? '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. TOP LINE: Subject Subtitle (Left) & Delete Button (Right)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Subject: $subject',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF00897B),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 22,
                                      ),
                                      tooltip: 'Dismiss Ticket',
                                      onPressed: () => _dismissTicket(ticketId, index),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // 2. SECOND LINE: Teacher Name & Phone Number
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      phone,
                                      style: const TextStyle(
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),

                                // 3. THIRD LINE: Ticket Message Body
                                Text(
                                  message,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

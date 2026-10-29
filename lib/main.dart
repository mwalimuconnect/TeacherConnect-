import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Add this for PlatformException
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teacherconnect/auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:teacherconnect/services/upload_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart'; // <-- Add this for LocalAuthentication & AuthenticationOptions
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:image_picker/image_picker.dart';
void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  final String userId = prefs.getString('userId') ?? '';

  final String userName = prefs.getString('userName') ?? 'Teacher';

  final String userRole = prefs.getString('userRole') ?? 'Member Teacher';

  final String userPhone = prefs.getString('userPhone') ?? '';

  runApp(MyApp(

    isLoggedIn: isLoggedIn,

    userId: userId,

    userName: userName,

    userRole: userRole,

    userPhone: userPhone,

  ));

}

class MyApp extends StatelessWidget {

  final bool isLoggedIn;

  final String userId;

  final String userName;

  final String userRole;

  final String userPhone;

  const MyApp({

    super.key,

    required this.isLoggedIn,

    required this.userId,

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
       ? (userRole == 'Administrator' 
        ? AdminDashboardScreen(
            userId: userId, // <-- Add this
            adminName: userName,
            adminPhone: userPhone,
          )
        : TeacherPortalScreen(
            userId: userId, // <-- Add this
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
    final bool computedCompliance = json['isTscCompliant'] == true || 
                                     json['tscCompliant'] == true || 
                                     (displayTsc != 'N/A' && displayTsc.isNotEmpty);

    // 4. Upgraded Subject Combination extraction prioritizing the standard field
    final Object? rawSubjectValue = json['subjectCombination'] ?? 
                                    json['subject'] ?? 
                                    json['subjects'] ?? 
                                    userMap['subjectCombination'] ?? 
                                    userMap['subjects'] ?? 
                                    userMap['subject'];

    final String rawSubjectStr = rawSubjectValue != null ? rawSubjectValue.toString().trim() : '';
    final String displaySubject = (rawSubjectStr.isNotEmpty && rawSubjectStr.toLowerCase() != 'n/a') 
        ? rawSubjectStr 
        : 'N/A';

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
      subject: displaySubject,
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
                                                                                                
// =========================================================
// 1. MEMBER REGISTRATION SCREEN
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
  final _subjectController = TextEditingController(); // Added for Subject Combination

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
    _subjectController.dispose(); // Dispose the controller
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
        'subjectCombination': _subjectController.text.trim(), // Included in payload
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

        final userMap = data['user'] ?? {};
        final String userId = userMap['id'] ?? userMap['_id'] ?? '';

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
                userId: userId,
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
                userId: userId,
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
        builder: (_) => const AuthScreen(),
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
                  style: TextStyle(fontSize: 22),
                ),
              ),
              const Center(
                child: Text(
                  'TeacherConnect',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _idController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID / Passport Number',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.work),
                  border: OutlineInputBorder(),
                ),
                items: _roles
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
                controller: _tscController,
                decoration: const InputDecoration(
                  labelText: 'TSC Number',
                  prefixIcon: Icon(Icons.card_membership),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              // Added Subject Combination Field
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject Combination (e.g., ENG/LIT)',
                  prefixIcon: Icon(Icons.menu_book),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _schoolController,
                decoration: const InputDecoration(
                  labelText: 'Current School Name',
                  prefixIcon: Icon(Icons.domain),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              if (_selectedRole == 'Admin') ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _adminPasscodeController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.security, color: Colors.red),
                    labelText: 'Admin Security Passcode',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _navigateToLogin,
                child: const Text('Already have an account? Login'),
              ),
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
      final String userId = prefs.getString('userId') ?? '';
      final String? savedPhone = prefs.getString('savedPhone');
      final String? savedName = prefs.getString('savedName');
      final String? savedRole = prefs.getString('savedRole');
      final String? savedPhotoUrl = prefs.getString('savedPhotoUrl');

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
                userId: userId,
                adminName: savedName ?? 'Admin',
                adminPhone: savedPhone,
                adminPhotoUrl: savedPhotoUrl,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherPortalScreen(
                userId: userId,
                userName: savedName ?? 'Member Teacher',
                userRole: savedRole ?? 'Member Teacher',
                userPhone: savedPhone,
                userPhotoUrl: savedPhotoUrl,
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
        final String userId = userMap['_id'] ?? userMap['userId'] ?? '';
        final String userRole = userMap['role'] ?? 'Member Teacher';
        final String userName = userMap['fullName'] ?? 'Teacher';
        final String userPhone = userMap['phone'] ?? userMap['phoneNumber'] ?? _phoneController.text.trim();
        final String userPhotoUrl = userMap['profilePhotoUrl'] ?? userMap['profilePhoto'] ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', userId);
        await prefs.setString('savedPhone', userPhone);
        await prefs.setString('savedName', userName);
        await prefs.setString('savedRole', userRole);
        await prefs.setString('savedPhotoUrl', userPhotoUrl);
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
                userId: userId,
                adminName: userName,
                adminPhone: userPhone,
                adminPhotoUrl: userPhotoUrl,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherPortalScreen(
                userId: userId,
                userName: userName,
                userRole: userRole,
                userPhone: userPhone,
                userPhotoUrl: userPhotoUrl,
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

            // Phone Number (Single instance)
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

            // Password (Single instance)
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
                                                                                         

// ==========================================
// 3. FORGOT & RESET PASSWORD SCREENS (DIRECT VERIFICATION)
// ==========================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _idController = TextEditingController();
  final _tscController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _idController.dispose();
    _tscController.dispose();
    super.dispose();
  }

  void _proceedToReset() {
    final phone = _phoneController.text.trim();
    final idNo = _idController.text.trim();
    final tsc = _tscController.text.trim();

    if (phone.isEmpty || idNo.isEmpty || tsc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in Phone Number, National ID, and TSC Number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to Reset Password Screen carrying the verification credentials
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          phone: phone,
          nationalId: idNo,
          tscNumber: tsc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Identity'),
        backgroundColor: const Color(0xFF00897B),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
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
              'Enter your registered account credentials below to verify your identity before setting a new password.',
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
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge),
                labelText: 'National ID / Passport Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tscController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.card_membership),
                labelText: 'TSC Number',
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
                onPressed: _proceedToReset,
                child: const Text(
                  'Continue to New Password',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
  final String phone;
  final String nationalId;
  final String tscNumber;

  const ResetPasswordScreen({
    Key? key,
    required this.phone,
    required this.nationalId,
    required this.tscNumber,
  }) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitNewPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter and confirm your new password.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.'), backgroundColor: Colors.red),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final payload = {
        'phoneNumber': widget.phone,
        'idNumber': widget.nationalId,
        'tscNumber': widget.tscNumber,
        'newPassword': newPassword,
      };

      final response = await http.post(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      // Guard against HTML error pages returned by server crashes/404s
      if (response.body.trim().startsWith('<')) {
        throw Exception('Server error (${response.statusCode}): Invalid endpoint or server crash.');
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
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
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Verification failed. Credentials do not match records.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Create New Password',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your secure new password below to finalize your account recovery.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                labelText: 'New Password',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                labelText: 'Confirm New Password',
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

// ==========================================
// PROFILE SCREEN WITH DROPDOWN SELECTORS & ADMIN PERMISSION GATING
// ==========================================
class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Cloudinary Configuration
  final String _cloudinaryCloudName = 'lxxyqoqa';
  final String _cloudinaryUploadPreset = 'ml_default';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  // Identity Permission State (Controls both National ID and TSC Number fields)
  bool _canEditTsc = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _tscNumberController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();

  // Dropdown Selection States
  String? _selectedSubject;
  String? _selectedCounty;
  String? _selectedSubCounty;

  List<String> _subjects = [
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
    'Mathematics / Chemistry',
    'Mathematics / Biology',
    'Mathematics / Physics',
    'Physics / Chemistry',
    'Mathematics / Computer Studies',
    'Biology / Chemistry',
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

  final Map<String, List<String>> _countySubCountyData = {
    'Baringo': ['Baringo Central', 'Baringo North', 'Baringo South', 'Eldama Ravine', 'Mogotio', 'Tiaty'],
    'Bomet': ['Bomet Central', 'Bomet East', 'Chepalungu', 'Konoin', 'Sotik'],
    'Bungoma': ['Bungoma Central', 'Bungoma East', 'Bungoma North', 'Bungoma South', 'Bungoma West', 'Cheptais', 'Kimilili', 'Mount Elgon', 'Sirisia', 'Tongaren'],
    'Busia': ['Bunyala', 'Busia', 'Butula', 'Nambale', 'Samia', 'Teso North', 'Teso South'],
    'Elgeyo Marakwet': ['Keiyo North', 'Keiyo South', 'Marakwet East', 'Marakwet West'],
    'Embu': ['Embu East', 'Embu North', 'Embu West', 'Mbeere North', 'Mbeere South'],
    'Garissa': ['Balambala', 'Dadaab', 'Fafi', 'Garissa', 'Hulugho', 'Ijara', 'Lagdera'],
    'Homa Bay': ['Homa Bay', 'Kabondo Kasipul', 'Karachuonyo', 'Kasipul', 'Mbita', 'Ndhiwa', 'Rangwe', 'Suba'],
    'Isiolo': ['Garbatulla', 'Isiolo', 'Merti'],
    'Kajiado': ['Isinya', 'Kajiado Central', 'Kajiado North', 'Kajiado West', 'Loitokitok', 'Mashuuru'],
    'Kakamega': ['Butere', 'Kakamega Central', 'Kakamega East', 'Kakamega North', 'Kakamega South', 'Khwisero', 'Likuyani', 'Lugari', 'Matungu', 'Mumias East', 'Mumias West', 'Navakholo'],
    'Kericho': ['Belgut', 'Bureau', 'Kericho East', 'Kipkelion East', 'Kipkelion West', 'Soin/Sigowet'],
    'Kiambu': ['Githunguri', 'Juja', 'Kabete', 'Kiambaa', 'Kiambu', 'Kikuyu', 'Lari', 'Limuru', 'Ruiru', 'Thika East', 'Thika West'],
    'Kilifi': ['Ganze', 'Kaloleni', 'Kilifi North', 'Kilifi South', 'Magarini', 'Malindi', 'Rabai'],
    'Kirinyaga': ['Kirinyaga Central', 'Kirinyaga East', 'Kirinyaga West', 'Mwea East', 'Mwea West'],
    'Kisii': ['Gucha', 'Gucha South', 'Kenyenya', 'Kisii Central', 'Kisii South', 'Kitutu Central', 'Marani', 'Masaba South', 'Nyamache', 'Sameta'],
    'Kisumu': ['Kadibo', 'Kisumu Central', 'Kisumu East', 'Kisumu West', 'Muhoroni', 'Nyando', 'Nyakach'],
    'Kitui': ['Ikutha', 'Katulani', 'Kitui Central', 'Kitui Rural', 'Kitui West', 'Kyuso', 'Lower Yatta', 'Mwingi Central', 'Mwingi East', 'Mwingi West', 'Nzambani'],
    'Kwale': ['Kinango', 'Lunga Lunga', 'Matuga', 'Msambweni'],
    'Laikipia': ['Laikipia Central', 'Laikipia East', 'Laikipia North', 'Laikipia West', 'Nyahururu'],
    'Lamu': ['Lamu East', 'Lamu West'],
    'Machakos': ['Athi River', 'Kalama', 'Kangundo', 'Kathiani', 'Machakos', 'Masinga', 'Matungulu', 'Mwala', 'Yatta'],
    'Makueni': ['Kilungu', 'Makueni', 'Kaiti', 'Kibwezi West', 'Kibwezi East', 'Mukaa'],
    'Mandera': ['Banissa', 'Kutulo', 'Lafey', 'Mandera Central', 'Mandera East', 'Mandera North', 'Mandera West'],
    'Marsabit': ['Laisamis', 'Marsabit Central', 'Moyale', 'North Horr'],
    'Meru': ['Imenti Central', 'Imenti North', 'Imenti South', 'Tigania East', 'Tigania West', 'Igembe Central', 'Igembe North', 'Igembe South', 'Buuri'],
    'Migori': ['Awendo', 'Kuria East', 'Kuria West', 'Nyatike', 'Rongo', 'Suna East', 'Suna West', 'Uriri'],
    'Mombasa': ['Changamwe', 'Jomvu', 'Kisauni', 'Likoni', 'Mvita', 'Nyali'],
    "Murang'a": ['Gatanga', 'Kandara', 'Kangema', 'Kigumo', 'Kiharu', 'Mathioya', "Murang'a South"],
    'Nairobi': ['Dagoretti', 'Embakasi', 'Kamukunji', 'Kasarani', 'Kibra', "Lang'ata", 'Makadara', 'Mathare', 'NJiru', 'Starehe', 'Westlands'],
    'Nakuru': ['Gilgil', 'Kuresoi North', 'Kuresoi South', 'Molo', 'Naivasha', 'Nakuru East', 'Nakuru North', 'Nakuru West', 'Njoro', 'Rongai', 'Subukia'],
    'Nandi': ['Chesumei', 'Nandi Central', 'Nandi East', 'Nandi North', 'Nandi South', 'Tinderet'],
    'Narok': ['Narok East', 'Narok North', 'Narok South', 'Narok West', 'Trans Mara East', 'Trans Mara West'],
    'Nyamira': ['Borabu', 'Manga', 'Masaba North', 'Nyamira North', 'Nyamira South'],
    'Nyandarua': ['Kinangop', 'Ndaragwa', 'Ol Kalou', 'Ol Joro Orok', 'Nipini'],
    'Nyeri': ['Kieni East', 'Kieni West', 'Mathira East', 'Mathira West', 'Mukurweini', 'Nyeri Central', 'Nyeri South', 'Tetu'],
    'Samburu': ['Samburu East', 'Samburu North', 'Samburu West'],
    'Siaya': ['Alego Usonga', 'Bondo', 'Gem', 'Rarieda', 'Ugenya', 'Ugunja'],
    'Taita Taveta': ['Mwatate', 'Taveta', 'Taita', 'Voi'],
    'Tana River': ['Bura', 'Garsen', 'Tana Delta', 'Tana North', 'Tana River'],
    'Tharaka Nithi': ['Tharaka North', 'Tharaka South', 'Chuka', "Igambang'ombe", 'Maara'],
    'Trans Nzoia': ['Endebess', 'Kiminini', 'Kwanza', 'Saboti', 'Cherangany'],
    'Turkana': ['Turkana Central', 'Turkana East', 'Turkana North', 'Turkana South', 'Turkana West', 'Loima'],
    'Uasin Gishu': ['Ainabkoi', 'Kapseret', 'Kesses', 'Moiben', 'Soy', 'Turbo'],
    'Vihiga': ['Emuhaya', 'Hamisi', 'Luanda', 'Sabatia', 'Vihiga'],
    'Wajir': ['Buna', 'Eldas', 'Habaswein', 'Tarbaj', 'Wajir East', 'Wajir North', 'Wajir South', 'Wajir West'],
    'West Pokot': ['Kipkomai', 'Pokot Central', 'Pokot North', 'Pokot South', 'West Pokot'],
  };

  String _role = '';
  String _profilePhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _tscNumberController.dispose();
    _nationalIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/profile?userId=${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        setState(() {
          _fullNameController.text = user['fullName'] ?? user['name'] ?? '';
          _phoneController.text = user['phone'] ?? user['phoneNumber'] ?? '';
          _schoolController.text = user['currentSchool'] ?? user['schoolName'] ?? '';
          
          // Robust boolean parsing for identity edit permission flag
          final rawCanEdit = user['canEditTsc'];
          _canEditTsc = rawCanEdit == true || rawCanEdit.toString().toLowerCase() == 'true' || rawCanEdit == 1 || rawCanEdit == '1';
          
          // Safe County and Sub-County dropdown value matching
          final fetchedCounty = user['county'] ?? user['currentCounty'];
          if (fetchedCounty != null && _countySubCountyData.containsKey(fetchedCounty)) {
            _selectedCounty = fetchedCounty;
          }
          
          final fetchedSubCounty = user['subCounty'];
          if (_selectedCounty != null && (_countySubCountyData[_selectedCounty!]?.contains(fetchedSubCounty) ?? false)) {
            _selectedSubCounty = fetchedSubCounty;
          }

          // Safe Subject dropdown value matching
          final fetchedSubject = user['subjectCombination'] ?? user['subjects'] ?? user['subject'];
          if (fetchedSubject != null && _subjects.contains(fetchedSubject)) {
            _selectedSubject = fetchedSubject;
          } else if (fetchedSubject != null && fetchedSubject.toString().isNotEmpty) {
            _subjects.add(fetchedSubject);
            _selectedSubject = fetchedSubject;
          } else {
            _selectedSubject = _subjects.first;
          }

          _tscNumberController.text = user['tscNumber'] ?? '';
          _nationalIdController.text = user['nationalId'] ?? user['nationalID'] ?? '';

          _role = user['role'] ?? 'Member Teacher';
          _profilePhotoUrl = user['profilePhotoUrl'] ?? user['profilePhoto'] ?? '';
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to load profile'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error connecting to server: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  /// Direct Image Upload to Cloudinary & Backend Save
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _cloudinaryUploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['error']?['message'] ?? 'Cloudinary upload failed');
      }

      final String downloadUrl = responseData['secure_url'];

      final backendResponse = await http.put(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/update-photo/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'profilePhoto': downloadUrl, 'profilePhotoUrl': downloadUrl}),
      );

      if (backendResponse.statusCode == 200 || backendResponse.statusCode == 201) {
        setState(() {
          _profilePhotoUrl = downloadUrl;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedPhotoUrl', _profilePhotoUrl);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Color(0xFF00897B),
          ),
        );
      } else {
        throw Exception('Failed to update user profile photo');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final response = await http.put(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/auth/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'fullName': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'currentSchool': _schoolController.text.trim(),
          'county': _selectedCounty ?? '',
          'subCounty': _selectedSubCounty ?? '',
          'subjectCombination': _selectedSubject ?? '',
          'subjects': _selectedSubject ?? '',
          'subject': _selectedSubject ?? '',
          'tscNumber': _tscNumberController.text.trim(),
          'nationalId': _nationalIdController.text.trim(),
          'profilePhotoUrl': _profilePhotoUrl,
          'profilePhoto': _profilePhotoUrl,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF00897B),
          ),
        );

        // If the backend automatically re-locks after saving, update local state
        setState(() {
          if (data['user'] != null && data['user']['canEditTsc'] == false) {
            _canEditTsc = false;
          }
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('savedName', _fullNameController.text.trim());
        await prefs.setString('savedPhone', _phoneController.text.trim());
        await prefs.setString('savedPhotoUrl', _profilePhotoUrl);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Profile'),
        backgroundColor: const Color(0xFF00897B),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar & Photo Upload Stack
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: const Color(0xFF00897B).withOpacity(0.1),
                            backgroundImage: (_profilePhotoUrl.isNotEmpty)
                                ? NetworkImage(_profilePhotoUrl) as ImageProvider
                                : null,
                            child: _profilePhotoUrl.isEmpty && !_isUploadingPhoto
                                ? const Icon(Icons.person, size: 50, color: Color(0xFF00897B))
                                : null,
                          ),
                          if (_isUploadingPhoto)
                            const Positioned.fill(
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.black45,
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF00897B),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                onPressed: _isUploadingPhoto ? null : _pickAndUploadImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _role,
                        style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),

                      // Dynamic Status Notice Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _canEditTsc ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _canEditTsc ? Colors.green.shade200 : Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _canEditTsc ? Icons.lock_open : Icons.info_outline,
                              color: _canEditTsc ? Colors.green : Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _canEditTsc
                                    ? 'Identity edit permission is currently UNLOCKED. You can update your National ID and TSC Number below.'
                                    : 'National ID and TSC numbers are currently locked. Request permission from an Admin to edit them.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: _canEditTsc ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // National ID Field (Gated by _canEditTsc)
                      TextFormField(
                        controller: _nationalIdController,
                        enabled: _canEditTsc,
                        decoration: InputDecoration(
                          labelText: 'National ID / Passport Number',
                          prefixIcon: const Icon(Icons.badge, color: Colors.grey),
                          suffixIcon: Icon(
                            _canEditTsc ? Icons.lock_open : Icons.lock,
                            color: _canEditTsc ? Colors.green : Colors.grey,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: _canEditTsc ? Colors.white : Colors.grey.shade100,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (_canEditTsc && (val == null || val.trim().isEmpty)) {
                            return 'Please enter your National ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // TSC Number Field (Gated by _canEditTsc)
                      TextFormField(
                        controller: _tscNumberController,
                        enabled: _canEditTsc,
                        decoration: InputDecoration(
                          labelText: 'TSC Number',
                          prefixIcon: const Icon(Icons.card_membership, color: Colors.grey),
                          suffixIcon: Icon(
                            _canEditTsc ? Icons.lock_open : Icons.lock,
                            color: _canEditTsc ? Colors.green : Colors.grey,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: _canEditTsc ? Colors.white : Colors.grey.shade100,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (_canEditTsc && (val == null || val.trim().isEmpty)) {
                            return 'Please enter your TSC Number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 10),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Editable Information',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your full name' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your phone number' : null,
                      ),
                      const SizedBox(height: 14),

                      // Dropdown for Subject Combination
                      DropdownButtonFormField<String>(
                        value: _subjects.contains(_selectedSubject) ? _selectedSubject : null,
                        isExpanded: true,
                        menuMaxHeight: 380,
                        decoration: const InputDecoration(
                          labelText: 'Subject Combination',
                          prefixIcon: Icon(Icons.menu_book),
                          border: OutlineInputBorder(),
                        ),
                        items: _subjects.map((sub) {
                          return DropdownMenuItem(
                            value: sub,
                            child: Text(sub, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSubject = val;
                          });
                        },
                        validator: (val) => val == null || val.isEmpty ? 'Please select your subject combination' : null,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _schoolController,
                        decoration: const InputDecoration(
                          labelText: 'Current School Name',
                          prefixIcon: Icon(Icons.domain),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Dropdowns for County and Sub-County Side-by-Side
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
                                  _selectedSubCounty = null; // Reset sub-county when county changes
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
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
                      const SizedBox(height: 30),

                      ElevatedButton(
                        onPressed: _isSaving ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
// TEACHER PORTAL MAIN SCREEN (Streamlined Header)
// =========================================================
class TeacherPortalScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String userRole;
  final String userPhone;
  final String? userPhotoUrl;

  const TeacherPortalScreen({
    Key? key,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.userPhone,
    this.userPhotoUrl,
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForAppUpdate(context);
    });
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

  void _showMyListingsBottomSheet(BuildContext context) {
    // Filter listings matching the current teacher's phone number or name
    final userPosts = [
      ...tscSwaps,
      ...bomJobs,
      ...seekingBom,
    ].where((item) => 
      (item.contactPhone.isNotEmpty && item.contactPhone == widget.userPhone) ||
      (item.teacherName.isNotEmpty && item.teacherName.toLowerCase().trim() == widget.userName.toLowerCase().trim())
    ).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Active Posts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: userPosts.isEmpty
                    ? const Center(
                        child: Text(
                          'You have not posted any listings yet under this phone/name.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: userPosts.length,
                        itemBuilder: (context, index) {
                          final post = userPosts[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(
                                post.category, 
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF009688))
                              ),
                              subtitle: Text(
                                'Subjects: ${post.subject}\nCounty: ${post.currentCounty}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit Button
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.teal),
                                    tooltip: 'Edit Post',
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _showEditPostDialog(context, post);
                                    },
                                  ),
                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'Remove Post',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (dCtx) => AlertDialog(
                                          title: const Text('Delete Listing'),
                                          content: const Text('Are you sure you want to permanently delete this listing?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dCtx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(dCtx, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        try {
                                          final res = await http.delete(
                                            Uri.parse('$_baseUrl/api/listings/${post.id}'),
                                          );
                                          if (res.statusCode == 200 || res.statusCode == 204) {
                                            Navigator.pop(ctx);
                                            _fetchListings();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Listing deleted successfully.')),
                                            );
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Failed to delete: $e')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
  void _showEditPostDialog(BuildContext context, ListingModel post) {
    final TextEditingController nameController = TextEditingController(text: post.teacherName);
    final TextEditingController schoolController = TextEditingController(text: post.schoolName);
    final TextEditingController phoneController = TextEditingController(text: post.contactPhone);
    final TextEditingController tscController = TextEditingController(text: post.tscNumber);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Listing',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tscController,
                  decoration: const InputDecoration(labelText: 'TSC Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: schoolController,
                  decoration: const InputDecoration(labelText: 'School / Qualifications', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: () async {
                      try {
                        final response = await http.put(
                          Uri.parse('$_baseUrl/api/listings/${post.id}'),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'teacherName': nameController.text.trim(),
                            'tscNumber': tscController.text.trim(),
                            'contactPhone': phoneController.text.trim(),
                            'schoolName': schoolController.text.trim(),
                          }),
                        );

                        if (!ctx.mounted) return;

                        if (response.statusCode == 200) {
                          Navigator.pop(ctx);
                          _fetchListings();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Listing updated successfully!'), backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: ${response.body}'), backgroundColor: Colors.red),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    await prefs.setBool('isLoggedIn', false);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

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
            IconButton(
              icon: const Icon(Icons.assignment_ind),
              tooltip: 'My Posts',
              onPressed: () => _showMyListingsBottomSheet(context),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: widget.userId),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  backgroundImage: (widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty)
                      ? NetworkImage(widget.userPhotoUrl!)
                      : null,
                  child: (widget.userPhotoUrl == null || widget.userPhotoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
                ),
              ),
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Admin Dashboard',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminDashboardScreen(
                        userId: widget.userId,
                        adminName: widget.userName,
                        adminPhone: widget.userPhone,
                        adminPhotoUrl: widget.userPhotoUrl,
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
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
                      radius: 24,
                      backgroundColor: Colors.white,
                      backgroundImage: (widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty)
                          ? NetworkImage(widget.userPhotoUrl!)
                          : null,
                      child: (widget.userPhotoUrl == null || widget.userPhotoUrl!.isEmpty)
                          ? Text(
                              widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'T',
                              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 20),
                            )
                          : null,
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
                leading: const Icon(Icons.person, color: Color(0xFF00897B)),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: widget.userId),
                    ),
                  );
                },
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
  final String userId;
  final String adminName;
  final String adminPhone;
  final String? adminPhotoUrl;

  const AdminDashboardScreen({
    Key? key,
    required this.userId,
    required this.adminName,
    this.adminPhone = '',
    this.adminPhotoUrl,
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForAppUpdate(context);
    });
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
                await prefs.setBool('isLoggedIn', false);

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
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: widget.userId),
                ),
              ).then((_) => _fetchDashboardStats());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                backgroundImage: (widget.adminPhotoUrl != null && widget.adminPhotoUrl!.isNotEmpty)
                    ? NetworkImage(widget.adminPhotoUrl!)
                    : null,
                child: (widget.adminPhotoUrl == null || widget.adminPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
            ),
          ),
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
                      userId: widget.userId,
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
                        backgroundImage: (widget.adminPhotoUrl != null && widget.adminPhotoUrl!.isNotEmpty)
                            ? NetworkImage(widget.adminPhotoUrl!)
                            : null,
                        child: (widget.adminPhotoUrl == null || widget.adminPhotoUrl!.isEmpty)
                            ? const Icon(
                                Icons.admin_panel_settings,
                                size: 32,
                                color: Colors.teal,
                              )
                            : null,
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
                                  ? 'Role: Administrator — ${widget.adminPhone}'
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
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.teal),
                        tooltip: 'Edit Profile',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileScreen(userId: widget.userId),
                            ),
                          ).then((_) => _fetchDashboardStats());
                        },
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
                    // Manage Identity Rights Action Tile (WITHOUT const)
                    _buildActionTile(
                      icon: Icons.security,
                      title: 'Manage Member Identity Rights',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminMemberIdentityManagementScreen(),
                          ),
                        ).then((_) => _fetchDashboardStats());
                      },
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
// ADMIN MEMBER IDENTITY MANAGEMENT SCREEN (WITH PULL-TO-REFRESH)
// ==========================================

class AdminMemberIdentityManagementScreen extends StatefulWidget {
  const AdminMemberIdentityManagementScreen({Key? key}) : super(key: key);

  @override
  State<AdminMemberIdentityManagementScreen> createState() => _AdminMemberIdentityManagementScreenState();
}

class _AdminMemberIdentityManagementScreenState extends State<AdminMemberIdentityManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _members = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/members'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _members = data['members'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load members (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleIdentityEditPermission(String memberId, bool currentStatus, int index) async {
    final bool targetStatus = !currentStatus;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.put(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/grant-identity-edit/$memberId'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'canEditTsc': targetStatus}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _members[index]['canEditTsc'] = targetStatus;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Permission updated successfully'),
            backgroundColor: Colors.teal,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to update permission'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating permission: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Identity Rights'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading && _members.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _errorMessage != null && _members.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchMembers,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchMembers,
                  color: Colors.teal,
                  child: _members.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 250),
                            Center(child: Text('No registered members found.')),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _members.length,
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final String memberId = member['id'] ?? member['_id'] ?? '';
                            final String name = member['fullName'] ?? member['name'] ?? 'Unknown Teacher';
                            final String tsc = member['tscNumber'] ?? 'N/A';
                            final String idNo = member['nationalId'] ?? member['idNumber'] ?? 'N/A';
                            
                            final rawCanEdit = member['canEditTsc'];
                            final bool canEdit = rawCanEdit == true || 
                                                 rawCanEdit.toString().toLowerCase() == 'true' || 
                                                 rawCanEdit == 1 || 
                                                 rawCanEdit == '1';

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: canEdit ? Colors.green.shade100 : Colors.grey.shade200,
                                  child: Icon(
                                    canEdit ? Icons.lock_open : Icons.lock,
                                    color: canEdit ? Colors.green : Colors.grey,
                                  ),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('TSC: $tsc | ID: $idNo\nStatus: ${canEdit ? "Unlocked for Editing" : "Locked"}'),
                                isThreeLine: true,
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: canEdit ? Colors.orange : Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () => _toggleIdentityEditPermission(memberId, canEdit, index),
                                  child: Text(
                                    canEdit ? 'Revoke' : 'Grant Edit',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            );
                          },
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
                        DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))), // 👈 Added Numbering Header
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
        // 1. Row Number cell matching the '#' column header
        DataCell(Text('${index + 1}')),
        
        DataCell(Text(listing.teacherName.isNotEmpty ? listing.teacherName : 'N/A')),
        DataCell(Text(listing.category)),
        // Subject Combination column mapped correctly
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              listing.subject.isNotEmpty ? listing.subject : 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(Text(listing.currentCounty)),
        DataCell(Text(listing.targetCounty.isNotEmpty ? listing.targetCounty : listing.salary)),
        DataCell(Text(listing.schoolName.isNotEmpty ? listing.schoolName : 'N/A')),
        DataCell(Text(listing.contactPhone)),
        DataCell(Text(tsc)),
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
              listing.isApproved ? 'APPROVED' : 'PENDING',
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
                  tooltip: 'Approve Listing',
                  onPressed: () => onApprove(listing.id),
                ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: 'Edit Listing',
                onPressed: () => onEdit(listing),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete Listing',
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
// PAYMENT HISTORY SCREEN (PAGINATED TABLE)
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
  List<dynamic> _payments = [];
  bool _isLoading = true;

  final String _baseUrl = 'https://teacher-connect-backend.vercel.app';

  @override
  void initState() {
    super.initState();
    _fetchPaymentHistory();
  }

  Future<void> _fetchPaymentHistory() async {
    setState(() => _isLoading = true);

    final isAll = widget.userPhoneNumber == 'ALL';
    final baseUrl = isAll
        ? '$_baseUrl/api/admin/payments'
        : '$_baseUrl/api/payments/user/${widget.userPhoneNumber}';

    final url = Uri.parse('$baseUrl?limit=1000'); // Fetch all for table pagination

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

        if (mounted) {
          setState(() {
            _payments = newItems;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment History"),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? const Center(child: Text("No transaction history found."))
              : RefreshIndicator(
                  onRefresh: _fetchPaymentHistory,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: PaginatedDataTable(
                      showCheckboxColumn: false,
                      rowsPerPage: 10,
                      columns: const [
                        DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Receipt Number', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Purpose', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Amount (KSh)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      source: _PaymentDataTableSource(_payments),
                    ),
                  ),
                ),
    );
  }
}

// ==========================================
// PAYMENT DATA SOURCE FOR EXACT CELL ALIGNMENT
// ==========================================
class _PaymentDataTableSource extends DataTableSource {
  final List<dynamic> _payments;

  _PaymentDataTableSource(this._payments);

  @override
  DataRow? getRow(int index) {
    if (index >= _payments.length) return null;
    final item = _payments[index] as Map<String, dynamic>;
    
    final String status = (item['status'] ?? 'completed').toString().toLowerCase();
    final bool isSuccessful = status == 'completed' || status == 'successful';
    final String purpose = (item['purpose'] ?? 'SWAP_UNLOCK').toString().replaceAll('_', ' ').toUpperCase();

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
        // 1. Numbering Column
        DataCell(Text('${index + 1}')),
        
        // 2. Receipt Number
        DataCell(Text(
          item['mpesaReceiptNumber'] ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),

        // 3. Purpose
        DataCell(Text(purpose)),

        // 4. Phone Number
        DataCell(Text(item['phoneNumber'] ?? 'N/A')),

        // 5. Amount
        DataCell(Text(
          "KSh ${item['amount'] ?? 100}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        )),

        // 6. Status Badge
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSuccessful ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: isSuccessful ? Colors.green.shade900 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _payments.length;

  @override
  int get selectedRowCount => 0;
}     

// ==========================================
// MANAGE BOM JOB SEEKERS (PAGINATED TABLE)
// ==========================================
class ManageJobSeekersScreen extends StatefulWidget {
  const ManageJobSeekersScreen({Key? key}) : super(key: key);

  @override
  State<ManageJobSeekersScreen> createState() => _ManageJobSeekersScreenState();
}

class _ManageJobSeekersScreenState extends State<ManageJobSeekersScreen> {
  List<dynamic> _seekers = [];
  bool _isLoading = true;

  final String _baseUrl = 'https://teacher-connect-backend.vercel.app';

  @override
  void initState() {
    super.initState();
    _fetchSeekers();
  }

  Future<void> _fetchSeekers() async {
    setState(() => _isLoading = true);

    final url = Uri.parse('$_baseUrl/api/job-seekers?limit=1000');

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

        if (mounted) {
          setState(() {
            _seekers = newItems;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching job seekers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSeeker(String id) async {
    if (id.isEmpty) return;
    final url = Uri.parse('$_baseUrl/api/admin/job-seekers/$id');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job seeker deleted successfully')),
        );
        _fetchSeekers();
      }
    } catch (e) {
      debugPrint('Error deleting job seeker: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BOM Job Seekers'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _seekers.isEmpty
              ? const Center(child: Text('No job seekers found.'))
              : RefreshIndicator(
                  onRefresh: _fetchSeekers,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: PaginatedDataTable(
                      showCheckboxColumn: false,
                      rowsPerPage: 10,
                      headingRowHeight: 56.0,
                      dataRowMinHeight: 55.0,
                      dataRowMaxHeight: 65.0,
                      columns: const [
                        DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Teacher / Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Qualification', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Subject Combo', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      source: _JobSeekerDataTableSource(
                        _seekers,
                        onDelete: (id) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Job Seeker'),
                              content: const Text('Are you sure you want to remove this job seeker profile?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _deleteSeeker(id);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
    );
  }
}

// ==========================================
// JOB SEEKER DATA SOURCE WITH EXACT ALIGNMENT
// ==========================================
class _JobSeekerDataTableSource extends DataTableSource {
  final List<dynamic> _seekers;
  final Function(String) onDelete;

  _JobSeekerDataTableSource(this._seekers, {required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= _seekers.length) return null;
    final item = _seekers[index] as Map<String, dynamic>;
    final seekerId = item['_id'] ?? item['id'] ?? '';
    final name = item['teacherName'] ?? item['name'] ?? 'Job Seeker';
    final qualification = item['qualification'] ?? 'N/A';
    final subjects = item['subjects'] ?? 'N/A';

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
        // 1. Numbering Column
        DataCell(Text('${index + 1}')),

        // 2. Teacher Name
        DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),

        // 3. Qualification
        DataCell(Text(qualification)),

        // 4. Subject Combination
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subjects,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // 5. Actions
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Seeker',
            onPressed: () => onDelete(seekerId),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _seekers.length;

  @override
  int get selectedRowCount => 0;
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
    // Pass context to the data source for row tapping / profile navigation
    final memberDataSource = _MemberDataTableSource(_members, context);

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
                              'Subject Combo',
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
  final BuildContext _context;

  _MemberDataTableSource(this._members, this._context);

  @override
  DataRow? getRow(int index) {
    if (index >= _members.length) return null;

    final member = _members[index];
    final memberId = member['_id'] ?? member['id'] ?? '';
    final name = member['fullName'] ?? member['name'] ?? 'N/A';
    final phone = member['phoneNumber'] ?? member['phone'] ?? 'N/A';
    final tsc = member['tscNumber'] ?? member['tsc'] ?? 'N/A';
    
    final subject = member['subjectCombination'] ?? 
                    member['subjects'] ?? 
                    member['subject'] ?? 
                    'N/A';

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
        // Clickable Name Cell opening the Profile Screen
        DataCell(
          GestureDetector(
            onTap: () {
              if (memberId.isNotEmpty) {
                Navigator.push(
                  _context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: memberId),
                  ),
                );
              }
            },
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF00897B),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        DataCell(Text(phone)),
        DataCell(Text(tsc)),
        DataCell(Text(idNum)),
        // Subject Combination Badge Cell
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subject,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
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
// TEACHER RESOURCES TAB (FOLDER DIRECTORY VIEW WITH ADMIN BYPASS & PDF PREVIEW)
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
      debugPrint('Error fetching dynamic subjects: $e');
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
    final bool isAdmin =
        currentRole.contains('admin') || currentRole == 'administrator';

    if (resourceInput is Map) {
      final String resourceId = resourceInput['_id']?.toString() ??
          resourceInput['id']?.toString() ??
          '';
      if (resourceId.isNotEmpty) {
        targetUrl =
            'https://teacher-connect-backend.vercel.app/api/resources/download/$resourceId?isAdmin=$isAdmin';
      }
    } else if (resourceInput is String) {
      String input = resourceInput.trim();
      if (input.isNotEmpty) {
        if (!input.startsWith('http://') && !input.startsWith('https://')) {
          targetUrl =
              'https://teacher-connect-backend.vercel.app/api/resources/download/$input?isAdmin=$isAdmin';
        } else {
          targetUrl = input;
          if (targetUrl.contains('cloudinary.com') &&
              !targetUrl.contains('fl_attachment')) {
            targetUrl =
                targetUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
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
  
  // ============================================================================
  // VISUAL PDF PREVIEW (USING GOOGLE VIEWER TO PREVENT AUTO-DOWNLOAD)
  // ============================================================================
  void _showPdfPreviewModal(
    BuildContext context,
    String pdfUrl,
    String title,
    double price,
    VoidCallback onDownloadPressed,
  ) async {
    final String encodedUrl = Uri.encodeComponent(pdfUrl);
    final String viewerUrl = 'https://docs.google.com/viewer?url=$encodedUrl&embedded=true';
    
    final Uri uri = Uri.parse(viewerUrl);

    try {
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open preview document.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening preview: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentRole = widget.userRole?.toLowerCase() ?? '';
    final bool isAdmin =
        currentRole.contains('admin') || currentRole == 'administrator';

    final filteredResources = _selectedCategory == 'All'
        ? _resources
        : _resources.where((res) {
            final resCat = (res['category'] ?? '').toString().toLowerCase();
            final selectedCat = _selectedCategory.toLowerCase();

            if (selectedCat.contains('notes') && resCat.contains('notes')) {
              return true;
            }
            if (selectedCat.contains('exam') && resCat.contains('exam')) {
              return true;
            }
            if (selectedCat.contains('schemes') && resCat.contains('scheme')) {
              return true;
            }
            if (selectedCat.contains('lesson') && resCat.contains('lesson')) {
              return true;
            }
            if (selectedCat.contains('project') && resCat.contains('project')) {
              return true;
            }

            return resCat == selectedCat;
          }).toList();

    return Column(
      children: [
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
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: _subjects.length,
                        itemBuilder: (context, index) {
                          final subjectName = _subjects[index];

                          final folderResources = filteredResources.where((r) {
                            final resSubject = (r['subject'] ?? '')
                                .toString()
                                .toLowerCase();
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
                                    onPreview: (ctx, url, title, price, callback) =>
                                        _showPdfPreviewModal(
                                            ctx, url, title, price, callback),
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
                                      const Icon(Icons.chevron_right,
                                          color: Colors.grey),
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
// SUBJECT FOLDER DETAIL SCREEN (With Admin Edit, Delete & In-App PDF Preview)
// ============================================================================
class SubjectFolderDetailScreen extends StatefulWidget {
  final String subject;
  final List<dynamic> resources;
  final bool isAdmin;
  final Function(dynamic) onDownload;
  final Function(BuildContext, String, String, double, VoidCallback) onPreview;

  const SubjectFolderDetailScreen({
    Key? key,
    required this.subject,
    required this.resources,
    required this.isAdmin,
    required this.onDownload,
    required this.onPreview,
  }) : super(key: key);

  @override
  State<SubjectFolderDetailScreen> createState() =>
      _SubjectFolderDetailScreenState();
}

class _SubjectFolderDetailScreenState
    extends State<SubjectFolderDetailScreen> {
  late List<dynamic> _localResources;

  @override
  void initState() {
    super.initState();
    _localResources = List.from(widget.resources);
  }

  // --- 1. EDIT RESOURCE DIALOG ---
  Future<void> _editResource(Map<String, dynamic> resource) async {
    final String resourceId =
        resource['_id']?.toString() ?? resource['id']?.toString() ?? '';
    final titleController =
        TextEditingController(text: resource['title'] ?? '');
    final priceController =
        TextEditingController(text: (resource['price'] ?? 50).toString());
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
                  Uri.parse(
                      'https://teacher-connect-backend.vercel.app/api/resources/$resourceId?isAdmin=true'),
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
                      SnackBar(
                          content: Text('Failed to update: ${response.body}')),
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
        content: const Text(
            'Are you sure you want to delete this resource? This action cannot be undone.'),
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
        Uri.parse(
            'https://teacher-connect-backend.vercel.app/api/resources/$resourceId?isAdmin=true'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _localResources.removeWhere((item) =>
                (item['_id']?.toString() ?? item['id']?.toString()) ==
                resourceId);
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
        foregroundColor: Colors.white,
      ),
      body: _localResources.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No resources found in ${widget.subject}',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 16),
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
                final resourceId =
                    res['_id']?.toString() ?? res['id']?.toString() ?? '';
                double price = (res['price'] ?? 50.0).toDouble();

                if (price > 0 && price < 50) price = 50.0;
                if (price > 100) price = 100.0;

                final bool isPaidResource = price >= 50.0;
                final bool canDownloadDirectly =
                    widget.isAdmin || !isPaidResource;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.picture_as_pdf,
                              color: Colors.teal,
                              size: 36,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Category: $category${isPaidResource ? " • Price: KES ${price.toStringAsFixed(0)}" : ""}',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Preview Button (Routes directly through Backend Download API)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.teal,
                                side: const BorderSide(color: Colors.teal),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                              ),
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text('Preview',
                                  style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                final String previewUrl =
                                    'https://teacher-connect-backend.vercel.app/api/resources/download/$resourceId?isAdmin=${widget.isAdmin}';

                                widget.onPreview(
                                  context,
                                  previewUrl,
                                  title,
                                  price,
                                  () {
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
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            // Download / Pay Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canDownloadDirectly
                                    ? Colors.teal
                                    : Colors.teal.shade700,
                                elevation: 1,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              icon: Icon(
                                canDownloadDirectly
                                    ? Icons.download
                                    : Icons.lock_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: Text(
                                canDownloadDirectly
                                    ? 'Download'
                                    : 'KES ${price.toStringAsFixed(0)}',
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

                            // Admin-Only Edit & Delete Buttons
                            if (widget.isAdmin) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.edit_outlined,
                                    color: Colors.blue, size: 20),
                                tooltip: 'Edit Resource',
                                onPressed: () => _editResource(res),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                tooltip: 'Delete Resource',
                                onPressed: () => _deleteResource(resourceId),
                              ),
                            ],
                          ],
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
          Navigator.pop(context, true); // Return back to resources list with refresh flag
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
              
              const SizedBox(height: 16), // Added proper spacing here!

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
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
// MANAGE BOM SCHOOL VACANCIES (PAGINATED TABLE)
// ==========================================
class ManageBomVacanciesScreen extends StatefulWidget {
  const ManageBomVacanciesScreen({Key? key}) : super(key: key);

  @override
  State<ManageBomVacanciesScreen> createState() => _ManageBomVacanciesScreenState();
}

class _ManageBomVacanciesScreenState extends State<ManageBomVacanciesScreen> {
  List<dynamic> _vacancies = [];
  bool _isLoading = true;

  final String _baseUrl = 'https://teacher-connect-backend.vercel.app';

  @override
  void initState() {
    super.initState();
    _fetchVacancies();
  }

  Future<void> _fetchVacancies() async {
    setState(() => _isLoading = true);

    final url = Uri.parse('$_baseUrl/api/bom-vacancies?limit=1000');

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

        if (mounted) {
          setState(() {
            _vacancies = newItems;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching BOM vacancies: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteVacancy(String id) async {
    if (id.isEmpty) return;
    final url = Uri.parse('$_baseUrl/api/admin/bom-vacancies/$id');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vacancy deleted successfully')),
        );
        _fetchVacancies();
      }
    } catch (e) {
      debugPrint('Error deleting vacancy: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BOM School Vacancies'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vacancies.isEmpty
              ? const Center(child: Text('No BOM vacancies found.'))
              : RefreshIndicator(
                  onRefresh: _fetchVacancies,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: PaginatedDataTable(
                      showCheckboxColumn: false,
                      rowsPerPage: 10,
                      headingRowHeight: 56.0,
                      dataRowMinHeight: 55.0,
                      dataRowMaxHeight: 65.0,
                      columns: const [
                        DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('School Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Subject Combo', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Location / County', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      source: _BomVacancyDataTableSource(
                        _vacancies,
                        onDelete: (id) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Vacancy'),
                              content: const Text('Are you sure you want to delete this vacancy?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _deleteVacancy(id);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
    );
  }
}

// ==========================================
// BOM VACANCY DATA SOURCE WITH EXACT ALIGNMENT
// ==========================================
class _BomVacancyDataTableSource extends DataTableSource {
  final List<dynamic> _vacancies;
  final Function(String) onDelete;

  _BomVacancyDataTableSource(this._vacancies, {required this.onDelete});

  @override
  DataRow? getRow(int index) {
    if (index >= _vacancies.length) return null;
    final item = _vacancies[index] as Map<String, dynamic>;
    final vacancyId = item['_id'] ?? item['id'] ?? '';
    final schoolName = item['schoolName'] ?? item['title'] ?? 'BOM Vacancy';
    final subjects = item['subjects'] ?? 'N/A';
    final county = item['county'] ?? 'N/A';

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
        // 1. Row Numbering Column
        DataCell(Text('${index + 1}')),

        // 2. School Name
        DataCell(Text(schoolName, style: const TextStyle(fontWeight: FontWeight.bold))),

        // 3. Subject Combination
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              subjects,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // 4. Location / County
        DataCell(Text(county)),

        // 5. Actions
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Vacancy',
            onPressed: () => onDelete(vacancyId),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _vacancies.length;

  @override
  int get selectedRowCount => 0;
}

            
// ==========================================
// 4. FREE POSTING MODAL (UPDATED)
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
    'Baringo': ['Baringo Central', 'Baringo North', 'Baringo South', 'Eldama Ravine', 'Mogotio', 'Tiaty'],
    'Bomet': ['Bomet Central', 'Bomet East', 'Chepalungu', 'Konoin', 'Sotik'],
    'Bungoma': ['Bungoma Central', 'Bungoma East', 'Bungoma North', 'Bungoma South', 'Bungoma West', 'Cheptais', 'Kimilili', 'Mount Elgon', 'Sirisia', 'Tongaren'],
    'Busia': ['Bunyala', 'Busia', 'Butula', 'Nambale', 'Samia', 'Teso North', 'Teso South'],
    'Elgeyo Marakwet': ['Keiyo North', 'Keiyo South', 'Marakwet East', 'Marakwet West'],
    'Embu': ['Embu East', 'Embu North', 'Embu West', 'Mbeere North', 'Mbeere South'],
    'Garissa': ['Balambala', 'Dadaab', 'Fafi', 'Garissa', 'Hulugho', 'Ijara', 'Lagdera'],
    'Homa Bay': ['Homa Bay', 'Kabondo Kasipul', 'Karachuonyo', 'Kasipul', 'Mbita', 'Ndhiwa', 'Rangwe', 'Suba'],
    'Isiolo': ['Garbatulla', 'Isiolo', 'Merti'],
    'Kajiado': ['Isinya', 'Kajiado Central', 'Kajiado North', 'Kajiado West', 'Loitokitok', 'Mashuuru'],
    'Kakamega': ['Butere', 'Kakamega Central', 'Kakamega East', 'Kakamega North', 'Kakamega South', 'Khwisero', 'Likuyani', 'Lugari', 'Matungu', 'Mumias East', 'Mumias West', 'Navakholo'],
    'Kericho': ['Belgut', 'Bureau', 'Kericho East', 'Kipkelion East', 'Kipkelion West', 'Soin/Sigowet'],
    'Kiambu': ['Githunguri', 'Juja', 'Kabete', 'Kiambaa', 'Kiambu', 'Kikuyu', 'Lari', 'Limuru', 'Ruiru', 'Thika East', 'Thika West'],
    'Kilifi': ['Ganze', 'Kaloleni', 'Kilifi North', 'Kilifi South', 'Magarini', 'Malindi', 'Rabai'],
    'Kirinyaga': ['Kirinyaga Central', 'Kirinyaga East', 'Kirinyaga West', 'Mwea East', 'Mwea West'],
    'Kisii': ['Gucha', 'Gucha South', 'Kenyenya', 'Kisii Central', 'Kisii South', 'Kitutu Central', 'Marani', 'Masaba South', 'Nyamache', 'Sameta'],
    'Kisumu': ['Kadibo', 'Kisumu Central', 'Kisumu East', 'Kisumu West', 'Muhoroni', 'Nyando', 'Nyakach'],
    'Kitui': ['Ikutha', 'Katulani', 'Kitui Central', 'Kitui Rural', 'Kitui West', 'Kyuso', 'Lower Yatta', 'Mwingi Central', 'Mwingi East', 'Mwingi West', 'Nzambani'],
    'Kwale': ['Kinango', 'Lunga Lunga', 'Matuga', 'Msambweni'],
    'Laikipia': ['Laikipia Central', 'Laikipia East', 'Laikipia North', 'Laikipia West', 'Nyahururu'],
    'Lamu': ['Lamu East', 'Lamu West'],
    'Machakos': ['Athi River', 'Kalama', 'Kangundo', 'Kathiani', 'Machakos', 'Masinga', 'Matungulu', 'Mwala', 'Yatta'],
    'Makueni': ['Kilungu', 'Makueni', 'Kaiti', 'Kibwezi West', 'Kibwezi East', 'Mukaa'],
    'Mandera': ['Banissa', 'Kutulo', 'Lafey', 'Mandera Central', 'Mandera East', 'Mandera North', 'Mandera West'],
    'Marsabit': ['Laisamis', 'Marsabit Central', 'Moyale', 'North Horr'],
    'Meru': ['Imenti Central', 'Imenti North', 'Imenti South', 'Tigania East', 'Tigania West', 'Igembe Central', 'Igembe North', 'Igembe South', 'Buuri'],
    'Migori': ['Awendo', 'Kuria East', 'Kuria West', 'Nyatike', 'Rongo', 'Suna East', 'Suna West', 'Uriri'],
    'Mombasa': ['Changamwe', 'Jomvu', 'Kisauni', 'Likoni', 'Mvita', 'Nyali'],
    "Murang'a": ['Gatanga', 'Kandara', 'Kangema', 'Kigumo', 'Kiharu', 'Mathioya', "Murang'a South"],
    'Nairobi': ['Dagoretti', 'Embakasi', 'Kamukunji', 'Kasarani', 'Kibra', "Lang'ata", 'Makadara', 'Mathare', 'NJiru', 'Starehe', 'Westlands'],
    'Nakuru': ['Gilgil', 'Kuresoi North', 'Kuresoi South', 'Molo', 'Naivasha', 'Nakuru East', 'Nakuru North', 'Nakuru West', 'Njoro', 'Rongai', 'Subukia'],
    'Nandi': ['Chesumei', 'Nandi Central', 'Nandi East', 'Nandi North', 'Nandi South', 'Tinderet'],
    'Narok': ['Narok East', 'Narok North', 'Narok South', 'Narok West', 'Trans Mara East', 'Trans Mara West'],
    'Nyamira': ['Borabu', 'Manga', 'Masaba North', 'Nyamira North', 'Nyamira South'],
    'Nyandarua': ['Kinangop', 'Ndaragwa', 'Ol Kalou', 'Ol Joro Orok', 'Nipini'],
    'Nyeri': ['Kieni East', 'Kieni West', 'Mathira East', 'Mathira West', 'Mukurweini', 'Nyeri Central', 'Nyeri South', 'Tetu'],
    'Samburu': ['Samburu East', 'Samburu North', 'Samburu West'],
    'Siaya': ['Alego Usonga', 'Bondo', 'Gem', 'Rarieda', 'Ugenya', 'Ugunja'],
    'Taita Taveta': ['Mwatate', 'Taveta', 'Taita', 'Voi'],
    'Tana River': ['Bura', 'Garsen', 'Tana Delta', 'Tana North', 'Tana River'],
    'Tharaka Nithi': ['Tharaka North', 'Tharaka South', 'Chuka', "Igambang'ombe", 'Maara'],
    'Trans Nzoia': ['Endebess', 'Kiminini', 'Kwanza', 'Saboti', 'Cherangany'],
    'Turkana': ['Turkana Central', 'Turkana East', 'Turkana North', 'Turkana South', 'Turkana West', 'Loima'],
    'Uasin Gishu': ['Ainabkoi', 'Kapseret', 'Kesses', 'Moiben', 'Soy', 'Turbo'],
    'Vihiga': ['Emuhaya', 'Hamisi', 'Luanda', 'Sabatia', 'Vihiga'],
    'Wajir': ['Buna', 'Eldas', 'Habaswein', 'Tarbaj', 'Wajir East', 'Wajir North', 'Wajir South', 'Wajir West'],
    'West Pokot': ['Kipkomai', 'Pokot Central', 'Pokot North', 'Pokot South', 'West Pokot'],
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
          'Mathematics / Chemistry',
          'Mathematics / Biology',
          'Mathematics / Physics',
          'Physics / Chemistry',
          'Mathematics / Computer Studies',
          'Biology / Chemistry',
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
        _tscController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedCounty == null ||
        _selectedSubCounty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields (Name, TSC Number, Phone, County, Sub-County).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedType == 'TSC Swap' && _selectedTargetCounty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Target County for TSC Swap.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
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
            // ALWAYS VISIBLE TSC NUMBER FIELD
            TextField(
              controller: _tscController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'TSC Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
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
            DropdownButtonFormField<String>(
              value: _subjects.contains(selectedSubject) ? selectedSubject : null,
              isExpanded: true,
              menuMaxHeight: 380,
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
            const SizedBox(height: 12),
            TextField(
              controller: _schoolController,
              decoration: InputDecoration(
                labelText: selectedType == 'TSC Swap' 
                    ? 'Current School Name' 
                    : selectedType == 'Seeking BOM Job' 
                        ? 'Previous School / Qualifications' 
                        : 'School Name',
                border: const OutlineInputBorder(),
              ),
            ),

            if (selectedType == 'TSC Swap') ...[
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

// ==========================================
// APP VERSION CHECK HELPER FUNCTIONS
// ==========================================
Future<void> checkForAppUpdate(BuildContext context) async {
  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version; // e.g., "1.0.3"

    final response = await http.get(
      Uri.parse('https://teacher-connect-backend.vercel.app/api/app-version'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String latestVersion = data['latestVersion'] ?? currentVersion;
      bool forceUpdate = data['forceUpdate'] ?? false;
      
      // Point directly to your GitHub release APK instead of Google Play Store
      String storeUrl = 'https://github.com/mwalimuconnect/TeacherConnect-/releases/download/v1.0.1/app-release.apk';

      if (_isVersionOlder(currentVersion, latestVersion)) {
        if (!context.mounted) return;
        _showUpdateDialog(context, latestVersion, storeUrl, forceUpdate);
      }
    }
  } catch (e) {
    debugPrint("App update check failed: $e");
  }
}

bool _isVersionOlder(String current, String latest) {
  List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (int i = 0; i < l.length; i++) {
    if (i >= c.length || l[i] > c[i]) return true;
    if (l[i] < c[i]) return false;
  }
  return false;
}

void _showUpdateDialog(BuildContext context, String version, String storeUrl, bool forceUpdate) {
  showDialog(
    context: context,
    barrierDismissible: !forceUpdate,
    builder: (BuildContext dialogContext) {
      return PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.system_update, color: Colors.teal),
              SizedBox(width: 10),
              Text('Update Available!'),
            ],
          ),
          content: Text(
            'A new version ($version) of TeacherConnect is ready. Please update your app to continue.',
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later', style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                final Uri url = Uri.parse(storeUrl);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}


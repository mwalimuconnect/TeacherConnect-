import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:teacherconnect/auth_screen.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:teacherconnect/services/upload_service.dart';

import 'package:file_picker/file_picker.dart';

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

// DATA MODELS

// ==========================================

class ListingModel {

  final String? id;

  final String teacherName;
    
  final String subject;

  final String currentCounty;

  final String targetCounty;

  final String contactPhone;

  final String? email;

  final bool isPaid;

  ListingModel({

    this.id,

    required this.teacherName,

    required this.subject,

    required this.currentCounty,

    required this.targetCounty,

    required this.contactPhone,

    this.email,

    this.isPaid = false,

  });

  factory ListingModel.fromJson(Map<String, dynamic> json) {

    return ListingModel(

      id: json['_id'] as String?,

      teacherName: json['fullName'] as String? ?? json['teacherName'] as String? ?? '',

      subject: json['subjectCombination'] as String? ?? json['subject'] as String? ?? json['subjects'] as String? ?? '',

      currentCounty: json['county'] as String? ?? json['currentCounty'] as String? ?? '',

      targetCounty: json['targetCounty'] as String? ?? json['desiredCounty'] as String? ?? '',

      contactPhone: json['phone'] as String? ?? json['contactPhone'] as String? ?? '',

      email: json['email'] as String?,

      isPaid: json['isPaid'] as bool? ?? false,

    );

  }

  Map<String, dynamic> toJson() {

    return {

      'fullName': teacherName,

      'subjectCombination': subject,

      'county': currentCounty,

      'targetCounty': targetCounty,

      'phone': contactPhone,

      if (email != null) 'email': email,

      'isPaid': isPaid,

    };

  }

}

final sampleListing1 = ListingModel(

  id: '1',

  teacherName: 'Swap Candidate',

  subject: 'English / Literature',

  currentCounty: 'Kisii County (Kenyenya)',

  targetCounty: 'Nyamira County (Manga, Borabu)',

  contactPhone: '0712345678',

  isPaid: false,

);

final sampleListing2 = ListingModel(

  id: '2',

  teacherName: 'BOM School Vacancy',

  subject: 'English / Literature',

  currentCounty: 'Kisii',

  targetCounty: 'Salary: KSh 18,000 / month',

  contactPhone: '0712345678',

  isPaid: false,
);

final sampleListing3 = ListingModel(

  id: '3',

  teacherName: 'Available Teacher (TSC Compliant)',

  subject: 'English / Literature',

  currentCounty: 'Available Immediately',

  targetCounty: 'Experience: 2 Years',

  contactPhone: '0712345678',

  isPaid: false,

);

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
// 2. LOGIN SCREEN
// =========================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Dismiss soft keyboard
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

        // Extract user payload cleanly
        final userMap = data['user'] ?? {};
        final String userRole = userMap['role'] ?? 'Member Teacher';
        final String userName = userMap['fullName'] ?? 'Teacher';
        // Read backend 'phone' field, fallback to 'phoneNumber' or input text
        final String userPhone = userMap['phone'] ?? userMap['phoneNumber'] ?? _phoneController.text.trim();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Color(0xFF00897B),
            duration: Duration(seconds: 2),
          ),
        );

        // Case-insensitive role verification
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
          children: [
            const Text(
              'Welcome Back to',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.normal),
            ),
            const Text(
              'TeacherConnect',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
            const SizedBox(height: 24),

            // Login Button
            SizedBox(
              width: double.infinity,
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
            const SizedBox(height: 12),

            // Link back to Register
            TextButton(
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
          ],
        ),
      ),
    );
  }
}
                                                                                                                                                                                                                                                                                                   
// =========================================================
// 2. TEACHER PORTAL MAIN SCREEN
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

bool get isAdmin => widget.userRole.
    toLowerCase().contains('admin');

  bool isListingUnlocked(ListingModel listing) {

    return listing.isPaid || isAdmin;

  }

  void _showPaymentModal(BuildContext 
      context, ListingModel listing) {

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

              const Text('Enter M-Pesa phone number to pay KSh 100:'),

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

                child: const Text('Pay via M-Pesa STK Push',

                    style: TextStyle(color: Colors.white)),

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

        Uri.parse('https://teacher-connect-backend.vercel.app/api/stkpush'),

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

  void _showPostDialog(BuildContext context) {

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      shape: const RoundedRectangleBorder(

        borderRadius:BorderRadius.vertical(top: Radius.circular(24)),

      ),

      builder: (context) => DynamicPostListingModal(

        userName: widget.userName,

        userPhone: widget.userPhone,

      ),

    );

  }

  Future<void> _handleLogout() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    if (!mounted) return;

    Navigator.pushReplacement(

      context,

      MaterialPageRoute(builder: (_) => const MemberRegistrationScreen())
    );

  }

  @override

  Widget build(BuildContext context) {

    return DefaultTabController(

      length: 4,

      child: Scaffold(

        appBar: AppBar(

          title: const Text('Teacher Portal'),

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

            tabs: [

              Tab(text: 'TSC Swaps'),

              Tab(text: 'BOM Jobs'),

              Tab(text: 'Seeking BOM'),
                
              Tab(text: 'Teacher Resources'),

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

                      widget.userName.isNotEmpty ? widget.userName[0] : 'T',

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

            Expanded(

              child: TabBarView(

                children: [

                  ListView(

                    children: [

                      _buildListingCard(sampleListing1),

                    ],

                  ),

                  ListView(

                    children: [

                      _buildListingCard(sampleListing2),

                    ],

                  ),

                  ListView(

                    children: [

                      _buildListingCard(sampleListing3),

                    ],

                  ),
const TeacherResourcesTab(),
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

  Widget _buildListingCard(ListingModel listing) {

final bool hasPaid = isListingUnlocked(listing);

    return Card(

      margin: const EdgeInsets.all(16),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

      elevation: 2,

      child: Padding(

        padding: const EdgeInsets.all(16.0),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                const Icon(Icons.work_outline, color: Color(0xFF009688)),

                const SizedBox(width: 8),

                Expanded(

                  child: Text(

                    "${listing.teacherName} (${listing.subject})",

                    style: const TextStyle(

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ),

              ],

            ),

            const SizedBox(height: 8),

            Text("Location: ${listing.currentCounty}"),

            const SizedBox(height: 4),

            Text("Target / Info: ${listing.targetCounty}"),

            const Divider(height: 24),

            SizedBox(

              width: double.infinity,

              child: ElevatedButton.icon(

                style: ElevatedButton.styleFrom(

                  backgroundColor: const Color(0xFF009688),

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(20),

                  ),

                ),

                icon: Icon(

                  hasPaid ? Icons.visibility : Icons.lock,

                  color: Colors.white,

                ),

                label: Text(

                  hasPaid ? 'View Full Details' : 'Pay KSh 100 to View',

                  style: const TextStyle(color: Colors.white),

                ),

                onPressed: () {

                  if (hasPaid) {

                    showDialog(

                      context: context,

                      builder: (_) => AlertDialog(

                        title: Text(listing.teacherName),

                        content: Text(

                          'Full Details Unlocked!\nContact: ${listing.contactPhone.isNotEmpty ? listing.contactPhone : "0712345678"}\n\nSubjects: ${listing.subject}\nFrom: ${listing.currentCounty}\nTo: ${listing.targetCounty}',

                        ),

                        actions: [

                          TextButton(

                            onPressed: () => Navigator.pop(context),

                            child: const Text('Close'),

                          )

                        ],

                      ),

                    );

                  } else {

                    _showPaymentModal(context, listing);

                  }

                },

              ),

            ),

          ],

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

  final Map<String, dynamic> _stats = {
    'totalListings': 0,
    'pendingApprovals': 0,
    'paymentsReceived': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/stats'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats['totalListings'] = data['totalListings'] ?? 0;
          _stats['pendingApprovals'] = data['pendingApprovals'] ?? 0;
          _stats['paymentsReceived'] = data['paymentsReceived'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    builder: (_) => const MemberRegistrationScreen(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.teal,
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
                      userName: widget.adminName,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.teal,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.adminName.isNotEmpty
                              ? widget.adminName
                              : 'System Admin',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Role: Administrator',
                          style: TextStyle(
                            color: Colors.teal,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'System Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageListingsScreen(),
                            ),
                          ).then((_) => _fetchDashboardStats());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: _buildStatCard(
                          'Total Listings',
                          '${_stats['totalListings']}',
                          Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PendingApprovalsScreen(),
                            ),
                          ).then((_) => _fetchDashboardStats());
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: _buildStatCard(
                          'Pending Approvals',
                          '${_stats['pendingApprovals']}',
                          Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
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
                        borderRadius: BorderRadius.circular(12),
                        child: _buildStatCard(
                          'Payments Received',
                          'KSh ${_stats['paymentsReceived']}',
                          Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Admin Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.payment, color: Colors.teal),
                title: const Text('Payment History'),
                trailing: const Icon(Icons.chevron_right),
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
              ListTile(
                leading: const Icon(Icons.hourglass_top, color: Colors.teal),
                title: const Text('Pending Approvals'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PendingApprovalsScreen(),
                    ),
                  ).then((_) => _fetchDashboardStats());
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Colors.teal),
                title: const Text('View All Swap Listings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageListingsScreen(),
                    ),
                  ).then((_) => _fetchDashboardStats());
                },
              ),
              ListTile(
                leading: const Icon(Icons.business_center, color: Colors.teal),
                title: const Text('BOM School Vacancies'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageBomVacanciesScreen(),
                    ),
                  ).then((_) => _fetchDashboardStats());
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Colors.teal),
                title: const Text('BOM Job Seekers'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageJobSeekersScreen(),
                    ),
                  ).then((_) => _fetchDashboardStats());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// MANAGE SWAP LISTINGS (PAGINATED)
// ==========================================
class ManageListingsScreen extends StatefulWidget {
  final String? categoryType;

  const ManageListingsScreen({Key? key, this.categoryType}) : super(key: key);

  @override
  State<ManageListingsScreen> createState() => _ManageListingsScreenState();
}

class _ManageListingsScreenState extends State<ManageListingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _listings = [];

  int _currentPage = 1;
  final int _limit = 15;
  bool _isLoadingInitial = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchListings(categoryType: widget.categoryType);
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
        !_isLoadingInitial &&
        !_isFetchingMore &&
        _hasMore) {
      _fetchListings(isLoadMore: true, categoryType: widget.categoryType);
    }
  }

  Future<void> _fetchListings({bool isLoadMore = false, String? categoryType}) async {
    if (isLoadMore) {
      if (!_hasMore || _isFetchingMore) return;
      setState(() {
        _isFetchingMore = true;
      });
    } else {
      setState(() {
        _isLoadingInitial = true;
        _currentPage = 1;
        _listings.clear();
      });
    }

    final String activeType = categoryType ?? widget.categoryType ?? '';
    final String typeQueryParam = activeType.isNotEmpty
        ? '&type=${Uri.encodeComponent(activeType)}'
        : '';

    final url = Uri.parse(
      'https://teacher-connect-backend.vercel.app/api/listings?page=$_currentPage&limit=$_limit$typeQueryParam',
    );

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
          _listings.addAll(newItems);
          _hasMore = newItems.length == _limit;
          if (_hasMore) {
            _currentPage++;
          }
        });
      } else {
        debugPrint('Failed to load listings. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching listings: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _deleteListing(String id) async {
    final url = Uri.parse(
      'https://teacher-connect-backend.vercel.app/api/admin/listing/$id',
    );

    try {
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing deleted successfully')),
        );
        _fetchListings(categoryType: widget.categoryType);
      }
    } catch (_) {}
  }

  void _editListing(Map<String, dynamic> item) {
    final nameController = TextEditingController(
      text: item['teacherName'] ?? item['fullName'] ?? '',
    );
    final subjectController = TextEditingController(
      text: item['subjectCombination'] ?? item['subjects'] ?? item['subject'] ?? '',
    );
    final currentCountyController = TextEditingController(
      text: item['currentCounty'] ?? item['county'] ?? '',
    );
    final targetCountyController = TextEditingController(
      text: item['targetCounty'] ?? item['targetLocation'] ?? item['desiredCounty'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Swap Listing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Teacher Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject(s)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: currentCountyController,
                decoration: const InputDecoration(
                  labelText: 'Current County',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCountyController,
                decoration: const InputDecoration(
                  labelText: 'Target County',
                  border: OutlineInputBorder(),
                ),
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
                    final listingId = item['_id'] ?? item['id'];

                    await _updateListingOnServer(
                      listingId,
                      {
                        'teacherName': nameController.text.trim(),
                        'fullName': nameController.text.trim(),
                        'subject': subjectController.text.trim(),
                        'subjects': subjectController.text.trim(),
                        'subjectCombination': subjectController.text.trim(),
                        'currentCounty': currentCountyController.text.trim(),
                        'county': currentCountyController.text.trim(),
                        'targetCounty': targetCountyController.text.trim(),
                      },
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      _fetchListings(categoryType: widget.categoryType);
                    }
                  },
                  child: const Text('Save Changes',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateListingOnServer(
      String id, Map<String, dynamic> updateData) async {
    final url = Uri.parse(
        'https://teacher-connect-backend.vercel.app/api/admin/listings/$id');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated successfully')),
        );
        _fetchListings(categoryType: widget.categoryType);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update listing (${response.statusCode})')),
        );
      }
    } catch (e) {
      debugPrint('Error updating listing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage All Swap Listings'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
              ? const Center(child: Text("No swap listings found."))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _listings.length + (_isFetchingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _listings.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final item = _listings[index];
                    final listingId = item['_id'] ?? item['id'];

                    final String teacherName =
                        item['teacherName'] ?? item['fullName'] ?? 'Teacher';
                    final String subjects = item['subjectCombination'] ??
                        item['subjects'] ??
                        item['subject'] ??
                        'N/A';
                    final String currentCounty =
                        item['currentCounty'] ?? item['county'] ?? 'N/A';
                    final String targetCounty = item['targetCounty'] ??
                        item['targetLocation'] ??
                        item['desiredCounty'] ??
                        'N/A';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: ListTile(
                        title: Text(
                          "$teacherName - $subjects",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            "Current: $currentCounty | Target: $targetCounty"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editListing(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Listing'),
                                    content: const Text(
                                        'Are you sure you want to delete this listing permanently?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteListing(listingId);
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
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

// PENDING APPROVALS SCREEN (PAGINATED)

// ==========================================
class PendingApprovalsScreen extends StatefulWidget {
    
    const PendingApprovalsScreen({Key? key}) : super(key: key);
    
   @override

  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();

}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {

  final ScrollController _scrollController = ScrollController();

  final List<dynamic> _pendingItems = [];

  int _currentPage = 1;

  final int _limit = 15;

  bool _isLoadingInitial = true;

  bool _isFetchingMore = false;

  bool _hasMore = true;

  @override

  void initState() {

    super.initState();

    _fetchPendingItems();

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

      _fetchPendingItems(isLoadMore: true);

    }

  }

  Future<void> _fetchPendingItems({bool isLoadMore = false}) async {

    if (isLoadMore) {

      setState(() => _isFetchingMore = true);

    } else {

      setState(() {

        _isLoadingInitial = true;

        _currentPage = 1;

        _pendingItems.clear();

      });

    }

    try {

      final response = await http.get(

        Uri.parse(

            'https://teacher-connect-backend.vercel.app/api/admin/pending-listings?page=$_currentPage&limit=$_limit'),

      );

      if (response.statusCode == 200) {

        final decoded = jsonDecode(response.body);

        List<dynamic> newItems = [];

        if (decoded is List) {

          newItems = decoded;

        } else if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {

          newItems = decoded['data'] as List<dynamic>;

        }

        setState(() {

          _pendingItems.addAll(newItems);

          _hasMore = newItems.length == _limit;

          if (_hasMore) _currentPage++;

        });

      }

    } catch (e) {

      debugPrint('Error fetching pending listings: $e');

    } finally {

      if (mounted) {

        setState(() {

          _isLoadingInitial = false;

          _isFetchingMore = false;

        });

      }

    }

  }

  Future<void> _updateStatus(String id, String status) async {

    try {

      final response = await http.patch(

        Uri.parse('https://teacher-connect-backend.vercel.app/api/admin/approve-listing/$id'),

        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({'status': status}),

      );

      if (response.statusCode == 200 && mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Item marked as $status')),

        );

        _fetchPendingItems();

      }

    } catch (e) {

      debugPrint('Error updating status: $e');

    }

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Pending Approvals')),

      body: _isLoadingInitial

          ? const Center(child: CircularProgressIndicator())

          : _pendingItems.isEmpty

              ? const Center(child: Text('No pending approvals found'))

              : ListView.builder(

                  controller: _scrollController,

                  itemCount: _pendingItems.length + (_isFetchingMore ? 1 : 0),

                  itemBuilder: (context, index) {

                    if (index == _pendingItems.length) {

                      return const Padding(

                        padding: EdgeInsets.symmetric(vertical: 16.0),

                        child: Center(child: CircularProgressIndicator()),

                      );

                    }

                    final item = _pendingItems[index];

                    return Card(

                      margin: const EdgeInsets.symmetric(

                          horizontal: 12, vertical: 6),

                      child: ListTile(

                        title: Text(item['title'] ??

                            item['schoolName'] ??

                            'Listing Request'),

                        subtitle: Text(

                            'Type: ${item['type'] ?? 'Swap'} | Code: ${item['tscNumber'] ?? 'N/A'}'),

                        trailing: Row(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            IconButton(

                              icon: const Icon(Icons.check_circle,

                                  color: Colors.green),

                              onPressed: () =>

                                  _updateStatus(item['_id'], 'approved'),

                            ),

                            IconButton(

                              icon: const Icon(Icons.cancel,

                                  color: Colors.red),

                              onPressed: () =>

                                  _updateStatus(item['_id'], 'rejected'),

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

// ============================================================================
// TEACHER RESOURCES TAB (PAGINATED + SEARCH + FILTER CHIPS)
// ============================================================================

class TeacherResourcesTab extends StatefulWidget {
  const TeacherResourcesTab({Key? key}) : super(key: key);

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
  ];

  @override
  void initState() {
    super.initState();
    _fetchResources();
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
        setState(() {
          _resources = data is List ? data : (data['resources'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load resources. Server returned status code ${response.statusCode}';
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

  Future<void> _downloadOrOpenUrl(String rawUrl) async {
    if (rawUrl.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid resource link.')),
        );
      }
      return;
    }

    // Force Cloudinary attachment header so DOCX/PDF files download cleanly
    String formattedUrl = rawUrl.trim();
    if (formattedUrl.contains('/upload/') && !formattedUrl.contains('/fl_attachment/')) {
      formattedUrl = formattedUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
    }

    final Uri uri = Uri.parse(formattedUrl);

    try {
      // 1. Primary Attempt: Launch in external browser/file handler
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      // 2. Fallback Attempt: Platform default view
      if (!launched) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $formattedUrl')),
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

  void showPaymentModal(
    BuildContext parentContext,
    String resourceTitle,
    double price,
    VoidCallback onPaymentSuccess,
  ) {
    TextEditingController phoneController = TextEditingController(text: "254");

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Unlock $resourceTitle"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Price: KES ${price.toStringAsFixed(0)}"),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "M-Pesa Phone Number",
                      hintText: "254712345678",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          String rawPhone = phoneController.text.trim();
                          String formattedPhone =
                              rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
                          if (formattedPhone.startsWith('0')) {
                            formattedPhone = '254${formattedPhone.substring(1)}';
                          }

                          if (formattedPhone.length != 12) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text("Enter a valid phone number (e.g., 254712345678)"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

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

                            setState(() => isLoading = false);

                            if (response.statusCode == 200) {
                              final data = jsonDecode(response.body);
                              if (data['success'] == true) {
                                if (Navigator.canPop(dialogContext)) {
                                  Navigator.pop(dialogContext);
                                }
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  const SnackBar(
                                    content: Text("STK Push sent! Please check your phone to enter your M-Pesa PIN."),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                onPaymentSuccess();
                              } else {
                                ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(
                                    content: Text(data['error'] ?? "Failed to initiate M-Pesa payment."),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                const SnackBar(
                                  content: Text("Server error. Please try again later."),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
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
                      : const Text("Pay Now"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredResources = _selectedCategory == 'All'
        ? _resources
        : _resources
            .where((res) => res['category'] == _selectedCategory)
            .toList();

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

        // Category Selector Chips
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

        // Main Resource List
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
                      child: filteredResources.isEmpty
                          ? const Center(
                              child: Text('No resources found in this category.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12.0),
                              itemCount: filteredResources.length,
                              itemBuilder: (context, index) {
                                final res = filteredResources[index];
                                final title = res['title'] ?? 'Untitled Resource';
                                final category = res['category'] ?? 'General';
                                final fileUrl = res['fileUrl'] ?? '';
                                double price =
                                    (res['price'] ?? 50.0).toDouble();

                                // Enforce payment requirement between KSh 50 and 100
                                if (price > 0 && price < 50) price = 50.0;
                                if (price > 100) price = 100.0;

                                final bool isPaid = price >= 50.0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10.0),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.picture_as_pdf,
                                        color: Colors.teal, size: 36),
                                    title: Text(title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        'Category: $category${isPaid ? " • Price: KES ${price.toStringAsFixed(0)}" : " • Free"}'),
                                    trailing: IconButton(
                                      icon: Icon(
                                        isPaid ? Icons.lock : Icons.download,
                                        color: isPaid ? Colors.orange : Colors.teal,
                                      ),
                                      onPressed: () {
                                        if (isPaid) {
                                          showPaymentModal(context, title, price,
                                              () {
                                            if (fileUrl.isNotEmpty) {
                                              _downloadOrOpenUrl(fileUrl);
                                            }
                                          });
                                        } else {
                                          if (fileUrl.isNotEmpty) {
                                            _downloadOrOpenUrl(fileUrl);
                                          }
                                        }
                                      },
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
                                                                          
// ==========================================
// 1. FILE UPLOAD SERVICE CLASS
// ==========================================
class UploadService {
  static const String baseUrl = 'https://teacher-connect-backend.vercel.app/api';
    static Future<String?> uploadResourceFile(PlatformFile platformFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );

      // Handle file bytes (Web/Memory) or file path (Mobile/Desktop)
      if (platformFile.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            platformFile.bytes!,
            filename: platformFile.name,
          ),
        );
      } else if (platformFile.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            platformFile.path!,
          ),
        );
      } else {
        return null;
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        return jsonResponse['fileUrl']; // Returns Cloudinary URL
      } else {
        print('Upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }
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
  String _selectedSubject = 'English';
  String _selectedForm = 'Form 1';
  String _selectedCategory = 'Exam';

  // File Picker & Loading States
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  // Dropdown Options
  final List<String> _subjects = ['English', 'Literature', 'Kiswahili', 'Mathematics', 'Biology', 'Chemistry', 'Physics', 'History'];
  final List<String> _forms = ['Form 1', 'Form 2', 'Form 3', 'Form 4', 'Grade 7', 'Grade 8', 'Grade 9'];
  final List<String> _categories = ['Exam', 'Scheme of Work', 'Lesson Plan', 'Notes', 'Revision Mock'];

  // Step A: Pick File Logic
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  // Step B: Submit Form Logic (Uploads to Cloudinary + Posts to MongoDB)
  Future<void> _submitResource() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }

    setState(() => _isUploading = true);

    // 1. Upload File to Cloudinary via Express /api/upload
    String? uploadedFileUrl = await UploadService.uploadResourceFile(_selectedFile!);

    if (uploadedFileUrl == null) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload file to Cloudinary. Try again.')),
        );
      }
      return;
    }

    // 2. Create Resource Record in MongoDB via Express /api/resources
    try {
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
                value: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                items: _subjects.map((sub) => DropdownMenuItem(value: sub, child: Text(sub))).toList(),
                onChanged: (val) => setState(() => _selectedSubject = val!),
              ),
              const SizedBox(height: 16),

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
                      const Icon(Icons.attach_file, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile != null
                              ? _selectedFile!.name
                              : 'Tap to select document (PDF, DOCX, PPT)',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 12),
                            Text('Uploading & Saving...'),
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

  String selectedSubject = 'English / Literature';

  bool isSubmitting = false;

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

    'Murang\'a': [

      'Gatanga',

      'Kandara',

      'Kangema',

      'Kigumo',

      'Kiharu',

      'Mathioya',

      'Murang\'a South'

    ],

    'Nairobi': [

      'Dagoretti',

      'Embakasi',

      'Kamukunji',

      'Kasarani',

      'Kibra',

      'Lang\'ata',

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

      'Igambang\'ombe',

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

          'teacherName': _nameController.text.trim(),

          'name': _nameController.text.trim(),

          'subject': selectedSubject,

          'subjects': selectedSubject,

          'category': selectedType,

          'currentCounty': '${_selectedCounty ?? ''} (${_selectedSubCounty ?? ''})',

          'county': _selectedCounty ?? '',

          'subCounty': _selectedSubCounty ?? '',

          'schoolName': _schoolController.text.trim(),

          'tscNumber': _tscController.text.trim(),

          'targetCounty': targetCountyText,

          'desiredCounty': targetCountyText,

          'salary': _salaryController.text.trim(),

          'contactPhone': effectivePhone,

          'phone': effectivePhone,

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

        Navigator.pop(context);

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

              value: selectedSubject,

              decoration: const InputDecoration(

                labelText: 'Subject Combination',

                border: OutlineInputBorder(),

              ),

              items: [

                'English / Literature',

                'Mathematics / Chemistry',

                'Mathematics / Biology',

                'Mathematics / Physics',

                'Kiswahili / History',

                'Kiswahili / CRE',

                'Kiswahili / Geography',

                'Biology / Chemistry',

                'Agriculture / Biology',

                'History / CRE',

                'Geography / Business',

                'Geography / CRE',

                'Computer / Any',

                'HomeScience / Any',

              ].map((sub) {

                return DropdownMenuItem(value: sub, child: Text(sub));

              }).toList(),

              onChanged: (val) {

                if (val != null) {

                  setState(() => selectedSubject = val);

                }

              },

            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(

              decoration: const InputDecoration(

                labelText: 'County',

                border: OutlineInputBorder(),

              ),

              value: _selectedCounty,

              hint: const Text('Select County'),

              items: _countySubCountyData.keys.map((String county) {

                return DropdownMenuItem<String>(

                  value: county,

                  child: Text(county),

                );

              }).toList(),

              onChanged: (String? newValue) {

                setState(() {

                  _selectedCounty = newValue;

                  _selectedSubCounty = null;

                });

              },

            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(

              decoration: const InputDecoration(

                labelText: 'Sub-County',

                border: OutlineInputBorder(),

              ),

              value: _selectedSubCounty,

              hint: Text(_selectedCounty == null

                  ? 'Select County First'

                  : 'Select Sub-County'),

              disabledHint: const Text('Select County First'),

              items: (_selectedCounty == null

                      ? <String>[]

                      : _countySubCountyData[_selectedCounty] ?? [])

                  .map((String subCounty) {

                return DropdownMenuItem<String>(

                  value: subCounty,

                  child: Text(subCounty),

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

              DropdownButtonFormField<String>(

                decoration: const InputDecoration(

                  labelText: 'Target County (Desired Destination)',

                  border: OutlineInputBorder(),

                  prefixIcon: Icon(Icons.map),

                ),

                value: _selectedTargetCounty,

                hint: const Text('Select Target County'),

                items: _countySubCountyData.keys.map((String county) {

                  return DropdownMenuItem<String>(

                    value: county,

                    child: Text(county),

                  );

                }).toList(),

                onChanged: (String? newValue) {

                  setState(() {

                    _selectedTargetCounty = newValue;

                    _selectedTargetSubCounty = null;

                  });

                },

              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(

                decoration: const InputDecoration(

                  labelText: 'Target Sub-County (Optional/Any)',

                  border: OutlineInputBorder(),

                  prefixIcon: Icon(Icons.location_city),

                ),

                value: _selectedTargetSubCounty,

                hint: const Text('Select Target Sub-County'),

                items: _selectedTargetCounty == null

                    ? []

                    : (_countySubCountyData[_selectedTargetCounty] ?? [])

                        .map((String subCounty) {

                        return DropdownMenuItem<String>(

                          value: subCounty,

                          child: Text(subCounty),

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
  
         

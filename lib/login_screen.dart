import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_web_portal.dart'; // Admin Dashboard
import 'register_screen.dart'; // Principal Registration
import 'parent_screen.dart'; // Parent App
import 'driver_screen.dart'; // Driver App
import 'parent_register_screen.dart'; // Activation
import 'super_admin_screen.dart'; // Super Admin Panel
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    setState(() => _errorMessage = '');

    try {
      // 1. Authenticate with Firebase
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Fetch User Profile (Check Role FIRST)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.email)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;

        String role = data?['role'] ?? 'parent';
        String schoolId = data?['school_id'] ?? 'school_001';
        bool isActive = data?['is_active'] ?? true;

        // --- RULE 1: SUPER ADMIN (No Checks needed) ---
        if (role == 'super_admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SuperAdminScreen()),
          );
          return;
        }

        // --- RULE 2: PARENTS & DRIVERS (Strict Email Verification) ---
        if (role == 'parent' || role == 'driver') {
          if (!userCred.user!.emailVerified) {
            await userCred.user!.reload(); // Double check status
            if (!userCred.user!.emailVerified) {
              await _auth.signOut();
              setState(
                () => _errorMessage = "Email not verified! Check your inbox.",
              );
              setState(() => _isLoading = false);
              return;
            }
          }
        }

        // --- RULE 3: PRINCIPALS (Must be Approved by You) ---
        if (role == 'admin') {
          if (!isActive) {
            await _auth.signOut();
            setState(
              () => _errorMessage =
                  "School pending approval. Contact Super Admin.",
            );
            setState(() => _isLoading = false);
            return;
          }
        }

        // 3. SUCCESS - ROUTING
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminWebPortal(schoolId: schoolId),
            ),
          );
        } else if (role == 'driver') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DriverScreen(schoolId: schoolId),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ParentScreen(schoolId: schoolId),
            ),
          );
        }
      } else {
        setState(
          () => _errorMessage = "User profile not found. Contact Admin.",
        );
        _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? "Login failed";
      if (e.code == 'invalid-credential') msg = "Wrong email or password.";
      setState(() => _errorMessage = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 120, // You can make this bigger or smaller!
                ),
                const SizedBox(height: 20),
                const Text(
                  "Login",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _login,
                          child: const Text("LOGIN"),
                        ),
                      ),

                const SizedBox(height: 20),
                const Divider(),

                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParentRegisterScreen(),
                    ),
                  ),
                  child: const Text(
                    "First time? Activate Account (Parent/Driver)",
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  ),
                  child: const Text(
                    "Register New School (Principal Only)",
                    style: TextStyle(color: Colors.grey),
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

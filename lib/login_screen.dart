import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';
import 'admin_web_portal.dart'; // Import for the Web Portal
import 'register_screen.dart'; // Import for Registration

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
    setState(() => _errorMessage = ''); // Clear previous errors

    try {
      // 1. Auth with Email/Password
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Fetch User Profile from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.email)
          .get();

      // Check if widget is still on screen before using context
      if (!mounted) return;

      if (userDoc.exists) {
        // Safer way to get data
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;

        // Default to empty if field is missing to prevent crash
        String role = data?['role'] ?? 'parent';
        String schoolId = data?['school_id'] ?? 'school_001';

        // 3. LOGIC: Check Role & Redirect
        if (role == 'admin') {
          // --- ADMIN FLOW ---
          // Send to Admin Web Portal with the correct School ID
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminWebPortal(schoolId: schoolId),
            ),
          );
        } else {
          // --- APP FLOW (Parent/Driver) ---
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(userRole: role, schoolId: schoolId),
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
      setState(() => _errorMessage = e.message ?? "Login failed");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text(
                "Child Safe Login",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Email Input
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Password Input
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),

              const SizedBox(height: 10),
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
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

              // NEW: Registration Button for Principals
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
                child: const Text("Register New School (Principal)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _schoolNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  void _registerSchool() async {
    if (_schoolNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Generate a Unique School ID (e.g., "school_171542...")
      String schoolId = "school_${DateTime.now().millisecondsSinceEpoch}";

      // 2. Create the Principal's Auth Account
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. Create School Document (Status: Pending)
      await _db.collection('schools').doc(schoolId).set({
        'name': _schoolNameController.text.trim(),
        'address': _addressController.text.trim(),
        'admin_email': _emailController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending', // <--- CRITICAL: Starts as pending
      });

      // 4. Create User Document (Role: Admin)
      await _db.collection('users').doc(_emailController.text.trim()).set({
        'role': 'admin',
        'school_id': schoolId,
        'email': _emailController.text.trim(),
        'is_active': false, // They cannot login until you approve
      });

      // 5. Show Success Message & Go Back
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Registration Successful"),
          content: const Text(
            "Your school has been registered!\n\n"
            "Status: PENDING APPROVAL\n\n"
            "Our team will verify your details within 24 hours. "
            "You will be able to login once approved.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Go back to Login
              },
              child: const Text("OK, Understood"),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Error"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register New School"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.school, size: 60, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text(
                "School Registration",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Create an account to manage your fleet.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _schoolNameController,
                decoration: const InputDecoration(
                  labelText: "School Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: "Address (City, State)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Official Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Create Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),

              const SizedBox(height: 25),
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
                        onPressed: _registerSchool,
                        child: const Text("SUBMIT FOR APPROVAL"),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

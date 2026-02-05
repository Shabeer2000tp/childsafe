import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _schoolNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  void _registerSchool() async {
    if (_schoolNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create Auth User
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Generate a Unique School ID (e.g., "school_1723...")
      String newSchoolId =
          "school_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

      // 3. Create the School Document
      await _db.collection('schools').doc(newSchoolId).set({
        'school_name': _schoolNameController.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'admin_email': _emailController.text.trim(),
      });

      // 4. Create the User (Admin) Document
      await _db.collection('users').doc(_emailController.text.trim()).set({
        'name': 'Principal Admin',
        'role': 'admin', // NEW ROLE: ADMIN
        'school_id': newSchoolId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("School Registered Successfully! Login now."),
        ),
      );

      // Go back to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
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
        child: Column(
          children: [
            const Text(
              "Create School Account",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _schoolNameController,
              decoration: const InputDecoration(
                labelText: "School Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Principal Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _registerSchool,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      child: const Text(
                        "REGISTER SCHOOL",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

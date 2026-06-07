import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParentRegisterScreen extends StatefulWidget {
  const ParentRegisterScreen({super.key});

  @override
  _ParentRegisterScreenState createState() => _ParentRegisterScreenState();
}

class _ParentRegisterScreenState extends State<ParentRegisterScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // Track which step the user is on
  int _currentStep = 1;
  bool _isLoading = false;

  // --- STEP 1: VERIFY EMAIL IN DATABASE ---
  void _verifyEmail() async {
    // SECURITY: Always lowercase emails for database matching
    String email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter your email")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if Admin has pre-approved this email
      DocumentSnapshot userDoc = await _db.collection('users').doc(email).get();

      if (!userDoc.exists) {
        throw FirebaseAuthException(
          code: 'not-found',
          message: "This email is not registered by any school. Contact Admin.",
        );
      }

      // Allow BOTH Parents and Drivers
      String role = userDoc['role'];
      if (role != 'parent' && role != 'driver') {
        throw FirebaseAuthException(
          code: 'wrong-role',
          message: "This account type cannot be activated here.",
        );
      }

      // SUCCESS: Email found! Move to Step 2
      setState(() {
        _currentStep = 2;
      });
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

  // --- STEP 2: CREATE PASSWORD & SEND EMAIL ---
  void _createAccount() async {
    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter a password")));
      return;
    }

    if (password != _confirmController.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create Auth Account securely
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send Verification Email
      if (userCred.user != null && !userCred.user!.emailVerified) {
        await userCred.user!.sendEmailVerification();
      }

      // SECURITY: Force sign out so they don't bypass the verification link!
      await _auth.signOut();

      // Success Dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text(
            "Verification Sent",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "A link has been sent to $email.\n\nPlease check your inbox/spam folder and click the link to finish activation.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Go back to Login Screen
              },
              child: const Text("OK, I'll Check"),
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
        title: const Text("Activate Account"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // TOP: PROGRESS BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepCircle(1, "Verify"),
                Container(width: 50, height: 2, color: Colors.grey[300]),
                _buildStepCircle(2, "Password"),
              ],
            ),
            const SizedBox(height: 40),

            // --- UI FOR STEP 1: VERIFY ---
            if (_currentStep == 1) ...[
              const Icon(Icons.verified_user, size: 50, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text(
                "Step 1: Verification",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Enter the email provided to the school.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email (Parent or Driver)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _verifyEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("VERIFY EMAIL"),
                      ),
                    ),
            ],

            // --- UI FOR STEP 2: PASSWORD ---
            if (_currentStep == 2) ...[
              const Icon(Icons.lock, size: 50, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                "Step 2: Set Password",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Create a secure password for your account.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Email Field (Locked)
              TextField(
                controller: _emailController,
                enabled: false, // User cannot change email now
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),

              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("ACTIVATE ACCOUNT"),
                      ),
                    ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper widget for the circles at the top
  Widget _buildStepCircle(int step, String label) {
    bool isActive = _currentStep >= step;
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: isActive ? Colors.indigo : Colors.grey[300],
          child: Text(
            "$step",
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.indigo : Colors.grey,
          ),
        ),
      ],
    );
  }
}

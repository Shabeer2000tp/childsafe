import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'parent_screen.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'attendance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// Globals to store session data
String? globalSchoolId;
String? globalUserRole;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Child Safe',
      theme: ThemeData(primarySwatch: Colors.indigo),
      // Check if user is already logged in
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // NOTE: In a real app, we would re-fetch the user role/school here
            // if the app was restarted. For this demo, we rely on the Login Screen logic.
            // If this fails on restart, just Logout and Login again.
            return LoginScreen();
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String userRole;
  final String schoolId;

  const HomeScreen({super.key, required this.userRole, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    bool isDriver = (userRole == 'driver');

    return Scaffold(
      appBar: AppBar(
        title: Text(isDriver ? "Driver - $schoolId" : "Parent - $schoolId"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              // This triggers the StreamBuilder in MyApp to show LoginScreen
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- DRIVER CONTROLS ---
            if (isDriver) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.drive_eta),
                label: const Text("Start Trip (GPS)"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Pass the schoolId to the Driver Console
                      builder: (context) => LocationScreen(schoolId: schoolId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.nfc),
                label: const Text("Attendance Console"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AttendanceScreen()),
                  );
                },
              ),
            ],

            // --- PARENT CONTROLS ---
            if (!isDriver)
              ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text("Track School Bus"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Pass the schoolId to the Map
                      builder: (context) => ParentScreen(schoolId: schoolId),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// --- UPDATED LOCATION SCREEN (Supports Multi-School) ---
class LocationScreen extends StatefulWidget {
  final String schoolId; // 1. Accept the ID

  const LocationScreen({super.key, required this.schoolId});

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final LocationService _locationService = LocationService();

  bool _isTracking = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  String _statusLog = "Ready to start trip.";

  void _toggleTracking() async {
    if (_isTracking) {
      // STOP TRACKING
      await _positionStreamSubscription?.cancel();
      setState(() {
        _isTracking = false;
        _statusLog = "Trip ended. Tracking stopped.";
      });
    } else {
      // START TRACKING
      bool hasPermission = await _locationService.handlePermission();
      if (!hasPermission) {
        setState(() => _statusLog = "Permission Denied!");
        return;
      }

      setState(() {
        _isTracking = true;
        _statusLog = "Starting trip for ${widget.schoolId}...";
      });

      _positionStreamSubscription = _locationService.getPositionStream().listen(
        (Position position) {
          setState(() {
            _statusLog =
                "Live Update:\nLAT: ${position.latitude}\nLNG: ${position.longitude}";
          });

          // 2. Pass the schoolId to the service
          _locationService.sendLocationToCloud(
            position.latitude,
            position.longitude,
            widget.schoolId,
          );
        },
        onError: (e) {
          setState(() => _statusLog = "Error: $e");
        },
      );
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Console (${widget.schoolId})'),
        backgroundColor: _isTracking ? Colors.green : Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTracking ? Icons.trip_origin : Icons.local_parking,
              size: 80,
              color: _isTracking ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _statusLog,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? Colors.red : Colors.green,
                ),
                onPressed: _toggleTracking,
                child: Text(
                  _isTracking ? "STOP TRIP" : "START TRIP",
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

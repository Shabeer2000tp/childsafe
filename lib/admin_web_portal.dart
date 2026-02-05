import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // To go back on logout

class AdminWebPortal extends StatefulWidget {
  final String schoolId; // 1. Accept the ID

  AdminWebPortal({required this.schoolId});

  @override
  _AdminWebPortalState createState() => _AdminWebPortalState();
}

class _AdminWebPortalState extends State<AdminWebPortal> {
  String _selectedView = "Dashboard";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 1. SIDEBAR
          Container(
            width: 250,
            color: Colors.indigo.shade900,
            child: Column(
              children: [
                const SizedBox(height: 30),
                Text(
                  "ADMIN PANEL\n${widget.schoolId}", // Show ID
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                _buildMenuItem("Dashboard", Icons.dashboard),
                _buildMenuItem("Manage Routes", Icons.map),
                _buildMenuItem("Manage Students", Icons.people),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // 2. CONTENT
          Expanded(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(20),
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon) {
    bool isSelected = _selectedView == title;
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: TextStyle(color: isSelected ? Colors.white : Colors.white70),
      ),
      tileColor: isSelected ? Colors.indigo : null,
      onTap: () => setState(() => _selectedView = title),
    );
  }

  Widget _buildMainContent() {
    if (_selectedView == "Manage Routes")
      return RouteManager(schoolId: widget.schoolId);
    if (_selectedView == "Manage Students")
      return StudentManager(schoolId: widget.schoolId);
    return const Center(child: Text("Welcome Principal. Select an option."));
  }
}

// --- SUB-WIDGET: ROUTE MANAGER ---
class RouteManager extends StatefulWidget {
  final String schoolId;
  RouteManager({required this.schoolId});

  @override
  _RouteManagerState createState() => _RouteManagerState();
}

class _RouteManagerState extends State<RouteManager> {
  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();

  void _saveRoute() {
    if (_routePoints.isEmpty) return;
    // Save to THIS school's routes
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('routes')
        .add({
          'name': 'Route A',
          'stops': _routePoints
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
        });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Route Saved!")));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text("Create Bus Route"),
          actions: [
            ElevatedButton.icon(
              onPressed: _saveRoute,
              icon: const Icon(Icons.save),
              label: const Text("SAVE"),
            ),
          ],
        ),
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.8505, 76.2711),
              initialZoom: 13.0,
              onTap: (tapPosition, point) =>
                  setState(() => _routePoints.add(point)),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              if (_routePoints.isNotEmpty)
                MarkerLayer(
                  markers: _routePoints
                      .map(
                        (p) => Marker(
                          point: p,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- SUB-WIDGET: STUDENT MANAGER (With Map Picker) ---
class StudentManager extends StatefulWidget {
  final String schoolId;
  StudentManager({required this.schoolId});

  @override
  _StudentManagerState createState() => _StudentManagerState();
}

class _StudentManagerState extends State<StudentManager> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Function to Add Student with Map Picker
  void _showAddStudentDialog() {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController parentEmailCtrl = TextEditingController();
    LatLng? selectedHomeLocation;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Needed to update the dialog state (Map selection)
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add New Student"),
              content: SizedBox(
                width: 500, // Wide dialog for Web
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Student Name",
                      ),
                    ),
                    TextField(
                      controller: parentEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: "Parent Email (for Login)",
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Tap map to set Home Location:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    // Mini Map Picker
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: const LatLng(
                              10.8505,
                              76.2711,
                            ), // Default Kerala
                            initialZoom: 13.0,
                            onTap: (tapPosition, point) {
                              setStateDialog(() {
                                selectedHomeLocation = point;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            if (selectedHomeLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: selectedHomeLocation!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.home,
                                      color: Colors.green,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedHomeLocation != null)
                      Text(
                        "Selected: ${selectedHomeLocation!.latitude.toStringAsFixed(4)}, ${selectedHomeLocation!.longitude.toStringAsFixed(4)}",
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty ||
                        parentEmailCtrl.text.isEmpty ||
                        selectedHomeLocation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please fill all fields and pick a location.",
                          ),
                        ),
                      );
                      return;
                    }

                    // 1. Create Student Document for THIS School
                    await _db.collection('students').add({
                      'name': nameCtrl.text,
                      'parent_id': parentEmailCtrl.text.trim(),
                      'school_id': widget.schoolId, // Dynamic School ID
                      'status': 'At Home',
                      'home_location': {
                        'lat': selectedHomeLocation!.latitude,
                        'lng': selectedHomeLocation!.longitude,
                      },
                    });

                    // 2. Create User Login for Parent
                    await _db
                        .collection('users')
                        .doc(parentEmailCtrl.text.trim())
                        .set({
                          'role': 'parent',
                          'school_id': widget.schoolId, // Dynamic School ID
                          'student_name': nameCtrl.text,
                        });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Student Added Successfully!"),
                      ),
                    );
                  },
                  child: const Text("Save Student"),
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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        label: const Text("Add Student"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Only show students for THIS school
        stream: _db
            .collection('students')
            .where('school_id', isEqualTo: widget.schoolId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No students found. Add one!"));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    data['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Parent: ${data['parent_id']}\nStatus: ${data['status']}",
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.edit, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

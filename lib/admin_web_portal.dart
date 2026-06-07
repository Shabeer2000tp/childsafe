import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';

class AdminWebPortal extends StatefulWidget {
  final String schoolId;

  const AdminWebPortal({super.key, required this.schoolId});

  @override
  _AdminWebPortalState createState() => _AdminWebPortalState();
}

class _AdminWebPortalState extends State<AdminWebPortal> {
  String _selectedView = "Dashboard";

  void _resolveAlert(String alertId) async {
    await FirebaseFirestore.instance.collection('alerts').doc(alertId).update({
      'is_active': false,
      'resolved_at': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Alert marked as resolved.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // 1. SIDEBAR
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade900,
                  boxShadow: [
                    const BoxShadow(blurRadius: 10, color: Colors.black26),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "ADMIN PORTAL",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      widget.schoolId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildMenuItem("Dashboard", Icons.dashboard_rounded),
                    _buildMenuItem(
                      "Manage Buses",
                      Icons.directions_bus_filled_rounded,
                    ),
                    _buildMenuItem("Manage Routes", Icons.map_rounded),
                    _buildMenuItem("Manage Drivers", Icons.person_pin_rounded),
                    _buildMenuItem("Manage Students", Icons.people_rounded),
                    _buildMenuItem(
                      "View Attendance",
                      Icons.calendar_month_rounded,
                    ),
                    _buildMenuItem(
                      "Notifications",
                      Icons.notifications_active_rounded,
                    ),
                    const Spacer(),
                    Container(
                      margin: const EdgeInsets.all(20),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text("Logout"),
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 2. MAIN CONTENT AREA
              Expanded(
                child: Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.all(30),
                  child: _buildMainContent(),
                ),
              ),
            ],
          ),

          // 3. EMERGENCY ALERT OVERLAY
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('alerts')
                .where('school_id', isEqualTo: widget.schoolId)
                .where('is_active', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const SizedBox();

              var alert = snapshot.data!.docs.first;
              Map<String, dynamic> alertData =
                  alert.data() as Map<String, dynamic>;
              String msg = alertData.containsKey('message')
                  ? alertData['message'].toString()
                  : 'Emergency Alert';

              return Container(
                width: double.infinity,
                height: 90,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    const BoxShadow(blurRadius: 20, color: Colors.redAccent),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CRITICAL EMERGENCY REPORTED",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            "Message: $msg",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () => _resolveAlert(alert.id),
                      child: const Text("MARK RESOLVED"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon) {
    bool isSelected = _selectedView == title;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.white60),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _selectedView = title),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_selectedView == "Manage Buses")
      return BusManager(schoolId: widget.schoolId);
    if (_selectedView == "Manage Routes")
      return RouteManager(schoolId: widget.schoolId);
    if (_selectedView == "Manage Drivers")
      return DriverManager(schoolId: widget.schoolId);
    if (_selectedView == "Manage Students")
      return StudentManager(schoolId: widget.schoolId);
    if (_selectedView == "View Attendance")
      return AttendanceReport(schoolId: widget.schoolId);
    if (_selectedView == "Notifications")
      return NotificationManager(schoolId: widget.schoolId);

    return DashboardOverview(
      schoolId: widget.schoolId,
      onNav: (view) => setState(() => _selectedView = view),
    );
  }
}

// ============================================================================
// 1. DASHBOARD OVERVIEW
// ============================================================================
class DashboardOverview extends StatelessWidget {
  final String schoolId;
  final Function(String) onNav;
  const DashboardOverview({
    super.key,
    required this.schoolId,
    required this.onNav,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "System Overview",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              _buildStatCard(
                "Total Students",
                Icons.people,
                Colors.blue,
                FirebaseFirestore.instance
                    .collection('students')
                    .where('school_id', isEqualTo: schoolId)
                    .snapshots(),
              ),
              const SizedBox(width: 20),
              _buildStatCard(
                "Active Drivers",
                Icons.directions_bus,
                Colors.orange,
                FirebaseFirestore.instance
                    .collection('users')
                    .where('school_id', isEqualTo: schoolId)
                    .where('role', isEqualTo: 'driver')
                    .snapshots(),
              ),
              const SizedBox(width: 20),
              _buildStatCard(
                "Routes",
                Icons.map,
                Colors.purple,
                FirebaseFirestore.instance
                    .collection('schools')
                    .doc(schoolId)
                    .collection('routes')
                    .snapshots(),
              ),
              const SizedBox(width: 20),
              _buildStatCard(
                "Alerts",
                Icons.warning,
                Colors.red,
                FirebaseFirestore.instance
                    .collection('alerts')
                    .where('school_id', isEqualTo: schoolId)
                    .where('is_active', isEqualTo: true)
                    .snapshots(),
              ),
            ],
          ),

          const SizedBox(height: 30),

          Container(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                const BoxShadow(color: Colors.black12, blurRadius: 15),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: const LatLng(10.8505, 76.2711),
                      initialZoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.childsafe.admin',
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('live_location')
                            .where('school_id', isEqualTo: schoolId)
                            .where('status', isEqualTo: 'active')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          return MarkerLayer(
                            markers: snapshot.data!.docs.map((doc) {
                              Map<String, dynamic> data =
                                  doc.data() as Map<String, dynamic>;
                              if (!data.containsKey('latitude') ||
                                  !data.containsKey('longitude'))
                                return Marker(
                                  point: const LatLng(0, 0),
                                  child: const SizedBox(),
                                );

                              return Marker(
                                point: LatLng(
                                  data['latitude'],
                                  data['longitude'],
                                ),
                                width: 50,
                                height: 50,
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Colors.indigo,
                                  size: 40,
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          const BoxShadow(blurRadius: 5, color: Colors.black26),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 10),
                          SizedBox(width: 8),
                          Text(
                            "Live Map View",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    IconData icon,
    Color color,
    Stream<QuerySnapshot> stream,
  ) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            String count = snapshot.hasData
                ? snapshot.data!.docs.length.toString()
                : "...";
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// 2. BUS MANAGER
// ============================================================================
class BusManager extends StatefulWidget {
  final String schoolId;
  const BusManager({super.key, required this.schoolId});
  @override
  _BusManagerState createState() => _BusManagerState();
}

class _BusManagerState extends State<BusManager> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _addBusDialog() {
    TextEditingController numCtrl = TextEditingController();
    TextEditingController plateCtrl = TextEditingController();
    TextEditingController capacityCtrl = TextEditingController();
    String? selectedDefaultRoute;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Add New Bus"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numCtrl,
                decoration: const InputDecoration(
                  labelText: "Bus Number (e.g. Bus 1)",
                  prefixIcon: Icon(Icons.directions_bus),
                ),
              ),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(
                  labelText: "License Plate",
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
              TextField(
                controller: capacityCtrl,
                decoration: const InputDecoration(
                  labelText: "Capacity",
                  prefixIcon: Icon(Icons.event_seat),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              _buildRouteDropdown(
                selectedDefaultRoute,
                (val) => setStateDialog(() => selectedDefaultRoute = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (numCtrl.text.isEmpty || plateCtrl.text.isEmpty) return;
                await _db
                    .collection('schools')
                    .doc(widget.schoolId)
                    .collection('buses')
                    .add({
                      'bus_number': numCtrl.text.trim(),
                      'plate_number': plateCtrl.text.trim(),
                      'capacity': capacityCtrl.text.trim(),
                      'default_route_id': selectedDefaultRoute ?? "",
                      'created_at': FieldValue.serverTimestamp(),
                    });
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Bus Added!")));
              },
              child: const Text("Add Bus"),
            ),
          ],
        ),
      ),
    );
  }

  void _editBusDialog(String docId, Map<String, dynamic> data) {
    TextEditingController numCtrl = TextEditingController(
      text: data['bus_number']?.toString() ?? '',
    );
    TextEditingController plateCtrl = TextEditingController(
      text: data['plate_number']?.toString() ?? '',
    );
    TextEditingController capacityCtrl = TextEditingController(
      text: data['capacity']?.toString() ?? '',
    );
    String? selectedDefaultRoute = data['default_route_id']?.toString() == ""
        ? null
        : data['default_route_id']?.toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Edit Bus Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numCtrl,
                decoration: const InputDecoration(
                  labelText: "Bus Number",
                  prefixIcon: Icon(Icons.directions_bus),
                ),
              ),
              TextField(
                controller: plateCtrl,
                decoration: const InputDecoration(
                  labelText: "License Plate",
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
              ),
              TextField(
                controller: capacityCtrl,
                decoration: const InputDecoration(
                  labelText: "Capacity",
                  prefixIcon: Icon(Icons.event_seat),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),
              const Text(
                "Default Route:",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildRouteDropdown(
                selectedDefaultRoute,
                (val) => setStateDialog(() => selectedDefaultRoute = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _db
                    .collection('schools')
                    .doc(widget.schoolId)
                    .collection('buses')
                    .doc(docId)
                    .update({
                      'bus_number': numCtrl.text.trim(),
                      'plate_number': plateCtrl.text.trim(),
                      'capacity': capacityCtrl.text.trim(),
                      'default_route_id': selectedDefaultRoute ?? "",
                    });
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Bus Updated!")));
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteDropdown(String? selectedVal, Function(String?) onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('schools')
          .doc(widget.schoolId)
          .collection('routes')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var routes = snapshot.data!.docs;
        bool validSelection = routes.any((r) => r.id == selectedVal);
        if (!validSelection) selectedVal = null;

        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.alt_route),
          ),
          isExpanded: true,
          initialValue: selectedVal,
          hint: const Text("Select Default Route"),
          items: routes.map((r) {
            Map<String, dynamic> rData = r.data() as Map<String, dynamic>;
            String rName = rData['name']?.toString() ?? 'Unnamed Route';
            return DropdownMenuItem<String>(value: r.id, child: Text(rName));
          }).toList(),
          onChanged: onChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBusDialog,
        label: const Text("Add Bus"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('schools')
            .doc(widget.schoolId)
            .collection('buses')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty)
            return const Center(child: Text("No buses found. Add one!"));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

              String busNumber =
                  data['bus_number']?.toString() ?? 'Unknown Bus';
              String plate = data['plate_number']?.toString() ?? 'No Plate';
              String capacity = data['capacity']?.toString() ?? 'N/A';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.yellow.shade800,
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    busNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text("Plate: $plate | Seats: $capacity"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editBusDialog(doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _db
                            .collection('schools')
                            .doc(widget.schoolId)
                            .collection('buses')
                            .doc(doc.id)
                            .delete(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// 3. DRIVER MANAGER
// ============================================================================
class DriverManager extends StatefulWidget {
  final String schoolId;
  const DriverManager({super.key, required this.schoolId});
  @override
  _DriverManagerState createState() => _DriverManagerState();
}

class _DriverManagerState extends State<DriverManager> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _addDriverDialog() {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController emailCtrl = TextEditingController();
    String? selectedBusId;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add New Driver"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Driver Name",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: "Driver Email",
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildBusDropdown(
                    selectedBusId,
                    (val) => setStateDialog(() => selectedBusId = val),
                  ),
                ],
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty)
                            return;
                          setStateDialog(() => isSaving = true);
                          try {
                            await _db
                                .collection('users')
                                .doc(emailCtrl.text.trim().toLowerCase())
                                .set({
                                  'name': nameCtrl.text.trim(),
                                  'email': emailCtrl.text.trim().toLowerCase(),
                                  'role': 'driver',
                                  'school_id': widget.schoolId,
                                  'assigned_bus':
                                      selectedBusId ?? "Not Assigned",
                                  'created_at': FieldValue.serverTimestamp(),
                                  'is_active': false,
                                });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Driver Whitelisted!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setStateDialog(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Whitelist Driver"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editDriverDialog(String docId, String currentName, String currentBus) {
    TextEditingController nameCtrl = TextEditingController(text: currentName);
    String? selectedBusId = currentBus == "Not Assigned" ? null : currentBus;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Driver"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "Driver Name",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Re-assign Bus:",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildBusDropdown(
                    selectedBusId,
                    (val) => setStateDialog(() => selectedBusId = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _db.collection('users').doc(docId).update({
                      'name': nameCtrl.text.trim(),
                      'assigned_bus': selectedBusId ?? "Not Assigned",
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Driver Updated!")),
                    );
                  },
                  child: const Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBusDropdown(String? selectedVal, Function(String?) onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('schools')
          .doc(widget.schoolId)
          .collection('buses')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        var buses = snapshot.data!.docs;
        bool validSelection = buses.any(
          (b) =>
              (b.data() as Map<String, dynamic>)['bus_number']?.toString() ==
              selectedVal,
        );
        if (!validSelection) selectedVal = null;

        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.directions_bus),
          ),
          isExpanded: true,
          initialValue: selectedVal,
          hint: const Text("Select Bus"),
          items: buses.map((b) {
            Map<String, dynamic> data = b.data() as Map<String, dynamic>;
            String bName = data['bus_number']?.toString() ?? 'Unnamed Bus';
            String bPlate = data['plate_number']?.toString() ?? '';
            return DropdownMenuItem<String>(
              value: bName,
              child: Text("$bName ($bPlate)"),
            );
          }).toList(),
          onChanged: onChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDriverDialog,
        label: const Text("Add Driver"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('users')
            .where('school_id', isEqualTo: widget.schoolId)
            .where('role', isEqualTo: 'driver')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty)
            return const Center(child: Text("No drivers found."));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              String name = data['name']?.toString() ?? 'Unknown';
              String email = data['email']?.toString() ?? 'No Email';
              String assignedBus =
                  data['assigned_bus']?.toString() ?? "Not Assigned";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.person, color: Colors.orange),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text("$email\nAssigned Bus: $assignedBus"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _editDriverDialog(doc.id, name, assignedBus),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _db.collection('users').doc(doc.id).delete(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// 4. ROUTE MANAGER (UPDATED WITH CLICKABLE STOP EDITING)
// ============================================================================
class RouteManager extends StatefulWidget {
  final String schoolId;
  const RouteManager({super.key, required this.schoolId});
  @override
  _RouteManagerState createState() => _RouteManagerState();
}

class _RouteManagerState extends State<RouteManager>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  String? _editingId;
  List<Map<String, dynamic>> _currentStops = [];
  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();

  LatLng? _schoolLocation;
  List<List<LatLng>> _otherRoutesPolylines = [];
  bool _isSettingSchoolMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllRoutesForOverlay();
    _fetchSchoolLocation();
  }

  void _fetchSchoolLocation() async {
    var doc = await _db.collection('schools').doc(widget.schoolId).get();
    if (doc.exists && doc.data()!.containsKey('location')) {
      var loc = doc.data()!['location'];
      setState(() => _schoolLocation = LatLng(loc['lat'], loc['lng']));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_schoolLocation!, 14.0);
      });
    }
  }

  void _fetchAllRoutesForOverlay() async {
    var snapshot = await _db
        .collection('schools')
        .doc(widget.schoolId)
        .collection('routes')
        .get();
    List<List<LatLng>> tempPolylines = [];
    for (var doc in snapshot.docs) {
      if (doc.id == _editingId) continue;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List stops = data['stops'] ?? [];
      if (stops.isNotEmpty) {
        tempPolylines.add(
          stops.map((s) => LatLng(s['lat'], s['lng'])).toList(),
        );
      }
    }
    setState(() => _otherRoutesPolylines = tempPolylines);
  }

  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location services disabled")),
      );
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    Position position = await Geolocator.getCurrentPosition();
    _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
  }

  // --- NEW: EDIT SPECIFIC STOP DIALOG ---
  void _editStopDialog(int index) {
    TextEditingController stopNameCtrl = TextEditingController(
      text: _currentStops[index]['name'],
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Stop #${index + 1}"),
        content: TextField(
          controller: stopNameCtrl,
          decoration: const InputDecoration(labelText: "Stop Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _currentStops.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete Stop"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStops[index]['name'] = stopNameCtrl.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _handleMapTap(LatLng point) {
    if (_isSettingSchoolMode) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Set School Location"),
          content: const Text("Confirm this location?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _db.collection('schools').doc(widget.schoolId).update({
                  'location': {'lat': point.latitude, 'lng': point.longitude},
                });
                setState(() {
                  _schoolLocation = point;
                  _isSettingSchoolMode = false;
                });
                Navigator.pop(context);
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      );
    } else {
      int stopNumber = _currentStops.length + 1;
      TextEditingController stopNameCtrl = TextEditingController(
        text: "Stop $stopNumber",
      );
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Add Stop #$stopNumber"),
          content: TextField(
            controller: stopNameCtrl,
            decoration: const InputDecoration(labelText: "Stop Name"),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(
                  () => _currentStops.add({
                    'lat': point.latitude,
                    'lng': point.longitude,
                    'name': stopNameCtrl.text.trim().isEmpty
                        ? "Stop $stopNumber"
                        : stopNameCtrl.text.trim(),
                  }),
                );
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        ),
      );
    }
  }

  void _saveRoute() async {
    if (_currentStops.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter name and add stops!")),
      );
      return;
    }
    Map<String, dynamic> routeData = {
      'name': _nameController.text.trim(),
      'stops': _currentStops,
      'last_updated': FieldValue.serverTimestamp(),
    };
    if (_editingId == null) {
      routeData['created_at'] = FieldValue.serverTimestamp();
      await _db
          .collection('schools')
          .doc(widget.schoolId)
          .collection('routes')
          .add(routeData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Route Created!")));
    } else {
      await _db
          .collection('schools')
          .doc(widget.schoolId)
          .collection('routes')
          .doc(_editingId)
          .update(routeData);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Route Updated!")));
    }
    _resetEditor();
  }

  void _loadRouteForEditing(String docId, Map<String, dynamic> data) {
    setState(() {
      _editingId = docId;
      _nameController.text = data['name']?.toString() ?? '';
      _currentStops = List<Map<String, dynamic>>.from(data['stops'] ?? []);
      _tabController.animateTo(1);
      if (_currentStops.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(
            LatLng(_currentStops[0]['lat'], _currentStops[0]['lng']),
            14.0,
          );
        });
      }
    });
    _fetchAllRoutesForOverlay();
  }

  void _resetEditor() {
    setState(() {
      _editingId = null;
      _currentStops.clear();
      _nameController.clear();
      _tabController.animateTo(0);
    });
    _fetchAllRoutesForOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            onTap: (index) {
              if (index == 0) _resetEditor();
            },
            tabs: [
              const Tab(icon: Icon(Icons.list), text: "Route List"),
              Tab(
                icon: Icon(
                  _editingId == null
                      ? Icons.add_location_alt
                      : Icons.edit_location,
                ),
                text: _editingId == null ? "Create New" : "Edit Route",
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('schools')
                    .doc(widget.schoolId)
                    .collection('routes')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.data!.docs.isEmpty)
                    return const Center(child: Text("No routes."));
                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      Map<String, dynamic> data =
                          doc.data() as Map<String, dynamic>;
                      List stops = data['stops'] ?? [];
                      String rName =
                          data['name']?.toString() ?? 'Unnamed Route';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade50,
                            child: const Icon(
                              Icons.route,
                              color: Colors.indigo,
                            ),
                          ),
                          title: Text(
                            rName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("${stops.length} Stops"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () =>
                                    _loadRouteForEditing(doc.id, data),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _db
                                    .collection('schools')
                                    .doc(widget.schoolId)
                                    .collection('routes')
                                    .doc(doc.id)
                                    .delete(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Route Name",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.alt_route),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _saveRoute,
                          icon: const Icon(Icons.save),
                          label: Text(_editingId == null ? "SAVE" : "UPDATE"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                        ),
                        if (_editingId != null)
                          TextButton(
                            onPressed: _resetEditor,
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: const LatLng(10.8505, 76.2711),
                            initialZoom: 13.0,
                            onTap: (tapPosition, point) => _handleMapTap(point),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.childsafe.admin',
                            ),
                            PolylineLayer(
                              polylines: _otherRoutesPolylines
                                  .map(
                                    (points) => Polyline(
                                      points: points,
                                      color: Colors.black26,
                                      strokeWidth: 6.0,
                                    ),
                                  )
                                  .toList(),
                            ),
                            PolylineLayer(
                              polylines: _otherRoutesPolylines
                                  .map(
                                    (points) => Polyline(
                                      points: points,
                                      color: Colors.grey,
                                      strokeWidth: 4.0,
                                    ),
                                  )
                                  .toList(),
                            ),
                            if (_currentStops.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _currentStops
                                        .map((s) => LatLng(s['lat'], s['lng']))
                                        .toList(),
                                    color: Colors.indigo.shade900,
                                    strokeWidth: 8.0,
                                  ),
                                ],
                              ),
                            if (_currentStops.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _currentStops
                                        .map((s) => LatLng(s['lat'], s['lng']))
                                        .toList(),
                                    color: Colors.blueAccent,
                                    strokeWidth: 5.0,
                                  ),
                                ],
                              ),
                            if (_currentStops.isNotEmpty)
                              MarkerLayer(
                                markers: _currentStops.asMap().entries.map((
                                  entry,
                                ) {
                                  int idx = entry.key;
                                  Map s = entry.value;
                                  return Marker(
                                    point: LatLng(s['lat'], s['lng']),
                                    width: 100,
                                    height: 50,
                                    // --- UPDATED: CLICKABLE MARKER ---
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _editStopDialog(idx),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.blue,
                                              ),
                                            ),
                                            child: Text(
                                              "${idx + 1}. ${s['name']}",
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                            size: 25,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            if (_schoolLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _schoolLocation!,
                                    width: 60,
                                    height: 60,
                                    child: const Column(
                                      children: [
                                        Icon(
                                          Icons.school,
                                          color: Colors.indigo,
                                          size: 40,
                                        ),
                                        Text(
                                          "School",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: FloatingActionButton.extended(
                            heroTag: "school_btn",
                            onPressed: () {
                              setState(
                                () => _isSettingSchoolMode =
                                    !_isSettingSchoolMode,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isSettingSchoolMode
                                        ? "Tap map to set School Location"
                                        : "School set mode cancelled",
                                  ),
                                ),
                              );
                            },
                            label: Text(
                              _isSettingSchoolMode
                                  ? "Tap Map Now"
                                  : "Set School",
                            ),
                            icon: Icon(
                              _isSettingSchoolMode
                                  ? Icons.touch_app
                                  : Icons.school,
                            ),
                            backgroundColor: _isSettingSchoolMode
                                ? Colors.orange
                                : Colors.white,
                            foregroundColor: _isSettingSchoolMode
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: FloatingActionButton(
                            heroTag: "loc_btn",
                            onPressed: _getCurrentLocation,
                            backgroundColor: Colors.white,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        if (_currentStops.isNotEmpty && !_isSettingSchoolMode)
                          Positioned(
                            bottom: 20,
                            left: 20,
                            child: FloatingActionButton.small(
                              backgroundColor: Colors.white,
                              child: const Icon(
                                Icons.undo,
                                color: Colors.black,
                              ),
                              onPressed: () =>
                                  setState(() => _currentStops.removeLast()),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 5. STUDENT MANAGER
// ============================================================================
class StudentManager extends StatefulWidget {
  final String schoolId;
  const StudentManager({super.key, required this.schoolId});
  @override
  _StudentManagerState createState() => _StudentManagerState();
}

class _StudentManagerState extends State<StudentManager> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- NEW: Search & Sort State Variables ---
  String _searchQuery = "";
  String _sortBy = "name_asc"; // Default sort: A to Z

  void _showAddStudentDialog() {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController parentEmailCtrl = TextEditingController();
    TextEditingController rfidCtrl = TextEditingController();
    String? selectedRouteId;
    String? selectedStopName;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add Student"),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                          labelText: "Parent Email",
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: rfidCtrl,
                        decoration: const InputDecoration(
                          labelText: "RFID (Optional)",
                        ),
                      ),
                      const SizedBox(height: 15),

                      StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('schools')
                            .doc(widget.schoolId)
                            .collection('routes')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const LinearProgressIndicator();

                          var routes = snapshot.data!.docs;
                          List<dynamic> stops = [];

                          if (selectedRouteId != null) {
                            try {
                              var selectedRouteDoc = routes.firstWhere(
                                (r) => r.id == selectedRouteId,
                              );
                              Map<String, dynamic> rData =
                                  selectedRouteDoc.data()
                                      as Map<String, dynamic>;
                              if (rData.containsKey('stops')) {
                                stops = rData['stops'] as List<dynamic>;
                              }
                            } catch (e) {}
                          }

                          return Column(
                            children: [
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: "Route",
                                ),
                                isExpanded: true,
                                value:
                                    routes.any(
                                      (doc) => doc.id == selectedRouteId,
                                    )
                                    ? selectedRouteId
                                    : null,
                                items: routes.map((r) {
                                  Map<String, dynamic> rData =
                                      r.data() as Map<String, dynamic>;
                                  String rName =
                                      rData['name']?.toString() ??
                                      'Unnamed Route';
                                  return DropdownMenuItem<String>(
                                    value: r.id,
                                    child: Text(
                                      rName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setStateDialog(() {
                                    selectedRouteId = val;
                                    selectedStopName = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: "Assign Stop",
                                ),
                                isExpanded: true,
                                value: selectedStopName,
                                hint: const Text("Select a route first"),
                                items: stops.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  var s = entry.value;
                                  String sName =
                                      (s is Map &&
                                          s.containsKey('name') &&
                                          s['name'] != null &&
                                          s['name']
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                      ? s['name'].toString()
                                      : 'Stop ${idx + 1}';
                                  return DropdownMenuItem<String>(
                                    value: sName,
                                    child: Text(
                                      sName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: stops.isEmpty
                                    ? null
                                    : (val) => setStateDialog(
                                        () => selectedStopName = val,
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isSaving)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nameCtrl.text.isEmpty ||
                              parentEmailCtrl.text.isEmpty ||
                              selectedRouteId == null ||
                              selectedStopName == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please fill all required fields and select a Stop!",
                                ),
                              ),
                            );
                            return;
                          }
                          setStateDialog(() => isSaving = true);
                          try {
                            await _db.collection('students').add({
                              'name': nameCtrl.text.trim(),
                              'parent_id': parentEmailCtrl.text
                                  .trim()
                                  .toLowerCase(),
                              'school_id': widget.schoolId,
                              'route_id': selectedRouteId,
                              'stop_name': selectedStopName,
                              'rfid_tag_id': rfidCtrl.text.trim(),
                              'status': 'At Home',
                            });
                            await _db
                                .collection('users')
                                .doc(parentEmailCtrl.text.trim().toLowerCase())
                                .set({
                                  'role': 'parent',
                                  'school_id': widget.schoolId,
                                  'student_name': nameCtrl.text.trim(),
                                  'is_active': false,
                                });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Student Added & Parent Whitelisted!",
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setStateDialog(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Save Student"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStudentDialog(
    String docId,
    String currentName,
    String currentRouteId,
    String currentStopName,
    String currentRfid,
  ) {
    TextEditingController nameCtrl = TextEditingController(text: currentName);
    TextEditingController rfidCtrl = TextEditingController(text: currentRfid);
    String? selectedRouteId = currentRouteId.isEmpty ? null : currentRouteId;
    String? selectedStopName = currentStopName.isEmpty ? null : currentStopName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Student"),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: "Name"),
                      ),
                      TextField(
                        controller: rfidCtrl,
                        decoration: const InputDecoration(labelText: "RFID"),
                      ),
                      const SizedBox(height: 15),
                      StreamBuilder<QuerySnapshot>(
                        stream: _db
                            .collection('schools')
                            .doc(widget.schoolId)
                            .collection('routes')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const LinearProgressIndicator();

                          var routes = snapshot.data!.docs;
                          List<dynamic> stops = [];

                          if (selectedRouteId != null) {
                            try {
                              var selectedRouteDoc = routes.firstWhere(
                                (r) => r.id == selectedRouteId,
                              );
                              Map<String, dynamic> rData =
                                  selectedRouteDoc.data()
                                      as Map<String, dynamic>;
                              if (rData.containsKey('stops')) {
                                stops = rData['stops'] as List<dynamic>;
                              }
                            } catch (e) {}
                          }

                          return Column(
                            children: [
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: "Route",
                                ),
                                isExpanded: true,
                                value:
                                    routes.any(
                                      (doc) => doc.id == selectedRouteId,
                                    )
                                    ? selectedRouteId
                                    : null,
                                items: routes.map((r) {
                                  Map<String, dynamic> rData =
                                      r.data() as Map<String, dynamic>;
                                  String rName =
                                      rData['name']?.toString() ??
                                      'Unnamed Route';
                                  return DropdownMenuItem<String>(
                                    value: r.id,
                                    child: Text(
                                      rName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setStateDialog(() {
                                    selectedRouteId = val;
                                    selectedStopName = null;
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: "Assign Stop",
                                ),
                                isExpanded: true,
                                value: selectedStopName,
                                hint: const Text("Select a route first"),
                                items: stops.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  var s = entry.value;
                                  String sName =
                                      (s is Map &&
                                          s.containsKey('name') &&
                                          s['name'] != null &&
                                          s['name']
                                              .toString()
                                              .trim()
                                              .isNotEmpty)
                                      ? s['name'].toString()
                                      : 'Stop ${idx + 1}';
                                  return DropdownMenuItem<String>(
                                    value: sName,
                                    child: Text(
                                      sName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: stops.isEmpty
                                    ? null
                                    : (val) => setStateDialog(
                                        () => selectedStopName = val,
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _db.collection('students').doc(docId).update({
                      'name': nameCtrl.text.trim(),
                      'rfid_tag_id': rfidCtrl.text.trim(),
                      'route_id': selectedRouteId ?? '',
                      'stop_name': selectedStopName ?? '',
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("Update"),
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
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        label: const Text("Add Student"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- 🔍 NEW: SEARCH & SORT BAR ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Search Field
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search by Student Name or RFID Tag...",
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.indigo,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase().trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Sort Dropdown
                    const Icon(Icons.sort, color: Colors.grey),
                    const SizedBox(width: 10),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        items: const [
                          DropdownMenuItem(
                            value: "name_asc",
                            child: Text("Name (A to Z)"),
                          ),
                          DropdownMenuItem(
                            value: "name_desc",
                            child: Text("Name (Z to A)"),
                          ),
                          DropdownMenuItem(
                            value: "route",
                            child: Text("Sort by Route"),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _sortBy = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- 📋 STUDENT LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('students')
                  .where('school_id', isEqualTo: widget.schoolId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs;

                if (docs.isEmpty)
                  return const Center(child: Text("No students found."));

                // 1. FILTERING LOGIC (Search)
                var filteredDocs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String name = (data['name'] ?? '').toString().toLowerCase();
                  String rfid = (data['rfid_tag_id'] ?? '')
                      .toString()
                      .toLowerCase();

                  if (_searchQuery.isEmpty) return true;
                  return name.contains(_searchQuery) ||
                      rfid.contains(_searchQuery);
                }).toList();

                // 2. SORTING LOGIC
                filteredDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;

                  String nameA = (dataA['name'] ?? '').toString().toLowerCase();
                  String nameB = (dataB['name'] ?? '').toString().toLowerCase();
                  String routeA = (dataA['route_id'] ?? '').toString();
                  String routeB = (dataB['route_id'] ?? '').toString();

                  if (_sortBy == "name_asc") {
                    return nameA.compareTo(nameB);
                  } else if (_sortBy == "name_desc") {
                    return nameB.compareTo(nameA);
                  } else if (_sortBy == "route") {
                    return routeA.compareTo(routeB);
                  }
                  return 0;
                });

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No matches found for your search.",
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  );
                }

                // 3. BUILD THE LIST
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var data = filteredDocs[index];
                    var docId = data.id;

                    Map<String, dynamic> sData =
                        data.data() as Map<String, dynamic>;
                    String routeId = sData['route_id']?.toString() ?? '';
                    String stopName =
                        sData['stop_name']?.toString() ?? 'No Stop Assigned';
                    String rfid = sData['rfid_tag_id']?.toString() ?? '';
                    String parentId =
                        sData['parent_id']?.toString() ?? 'Unknown';
                    String studentName = sData['name']?.toString() ?? 'Unknown';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(
                          studentName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Parent: $parentId\nStop: $stopName\nRFID: ${rfid.isEmpty ? 'N/A' : rfid}",
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _showEditStudentDialog(
                                docId,
                                studentName,
                                routeId,
                                stopName == 'No Stop Assigned' ? '' : stopName,
                                rfid,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _db
                                  .collection('students')
                                  .doc(docId)
                                  .delete(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. ATTENDANCE REPORT
// ============================================================================
class AttendanceReport extends StatefulWidget {
  final String schoolId;
  const AttendanceReport({super.key, required this.schoolId});
  @override
  _AttendanceReportState createState() => _AttendanceReportState();
}

class _AttendanceReportState extends State<AttendanceReport> {
  DateTime _selectedDate = DateTime.now();
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = _selectedDate.toIso8601String().split('T')[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Attendance Report: $dateStr",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_month),
                label: const Text("Select Date"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('school_id', isEqualTo: widget.schoolId)
                .where('date', isEqualTo: dateStr)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var records = snapshot.data!.docs;
              if (records.isEmpty)
                return const Center(
                  child: Text(
                    "No attendance records found.",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              return ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  var doc = records[index];
                  Map<String, dynamic> data =
                      doc.data() as Map<String, dynamic>;

                  String sName = data.containsKey('student_name')
                      ? data['student_name'].toString()
                      : 'Unknown';
                  String method = data.containsKey('method')
                      ? data['method'].toString()
                      : 'N/A';
                  String routeId = data.containsKey('route_id')
                      ? data['route_id'].toString()
                      : 'Unknown';
                  String time =
                      data.containsKey('timestamp') && data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp)
                            .toDate()
                            .toString()
                            .split(' ')[1]
                            .substring(0, 5)
                      : '--:--';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.check, color: Colors.white),
                      ),
                      title: Text(
                        sName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Method: $method \nRoute: $routeId"),
                      trailing: Text(
                        time,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 7. NOTIFICATION MANAGER
// ============================================================================
class NotificationManager extends StatefulWidget {
  final String schoolId;
  NotificationManager({required this.schoolId});
  @override
  _NotificationManagerState createState() => _NotificationManagerState();
}

class _NotificationManagerState extends State<NotificationManager> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  bool _isSending = false;

  void _sendNotification() async {
    if (_titleCtrl.text.isEmpty || _msgCtrl.text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'school_id': widget.schoolId,
        'title': _titleCtrl.text.trim(),
        'message': _msgCtrl.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'sender': 'Admin',
      });
      _titleCtrl.clear();
      _msgCtrl.clear();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📢 Notification Sent to All Parents!"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error sending: $e"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "📢 Send Announcement",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "This message will appear on every parent's app immediately.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Title (e.g. Holiday Alert)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _msgCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Message Body",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendNotification,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSending ? "SENDING..." : "SEND BROADCAST"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📜 Sent History",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('announcements')
                      .where('school_id', isEqualTo: widget.schoolId)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return Center(
                        child: Text(
                          "Error loading data: ${snapshot.error}",
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      return const Center(
                        child: Text(
                          "No announcements sent yet.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        Map<String, dynamic> data =
                            doc.data() as Map<String, dynamic>;

                        String title = data.containsKey('title')
                            ? data['title'].toString()
                            : 'No Title';
                        String msg = data.containsKey('message')
                            ? data['message'].toString()
                            : '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(
                                Icons.notifications,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(msg),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => FirebaseFirestore.instance
                                  .collection('announcements')
                                  .doc(doc.id)
                                  .delete(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

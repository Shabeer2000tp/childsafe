import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'login_screen.dart';
import 'dart:async';
import 'dart:io';

class ParentScreen extends StatefulWidget {
  final String schoolId;
  const ParentScreen({super.key, required this.schoolId});

  @override
  _ParentScreenState createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Route Data
  List<LatLng> _routePolyline = [];
  List<Marker> _stopMarkers = [];
  bool _isRouteLoaded = false;

  // Tracking data for the menus & ETA
  String _currentRouteId = "";
  String _currentStudentId = "";
  LatLng? _currentHomeLatLng;
  String _assignedStopName = "No Stop Assigned";
  LatLng? _assignedStopLatLng;

  // Dynamic Trip Data
  LatLng? _lastKnownBusPos;
  LatLng? _myLocation;

  // State
  bool _hasAlerted = false;
  late DateTime _appLaunchTime;
  StreamSubscription? _announcementSub;

  @override
  void initState() {
    super.initState();
    _appLaunchTime = DateTime.now();
    _initNotifications();
    _getCurrentLocation();
    _listenForAnnouncements();
  }

  @override
  void dispose() {
    _announcementSub?.cancel();
    super.dispose();
  }

  // --- 1. NOTIFICATION SETUP ---
  void _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  // --- 2. SHOW NOTIFICATION ---
  Future<void> _showSystemNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'school_alerts_id',
          'School Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: Colors.indigo,
          playSound: true,
        );
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  // --- 3. AUTO-LISTENER FOR ADMIN MESSAGES ---
  void _listenForAnnouncements() {
    _announcementSub = _db
        .collection('announcements')
        .where('school_id', isEqualTo: widget.schoolId)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              var data = change.doc.data() as Map<String, dynamic>;
              if (data['timestamp'] != null) {
                DateTime msgTime = (data['timestamp'] as Timestamp).toDate();
                if (msgTime.isAfter(_appLaunchTime)) {
                  _showSystemNotification(
                    "📢 ${data['title']}",
                    data['message'],
                  );
                  if (mounted) _showAutoPopup(data['title'], data['message']);
                }
              }
            }
          }
        });
  }

  void _showAutoPopup(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.deepOrange, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // --- 4. GEOFENCE (BUS NEAR STOP OR HOME) ---
  void _checkGeofence(LatLng busPos, LatLng targetPos) {
    if (_hasAlerted) return;
    const Distance distance = Distance();
    double meters = distance.as(LengthUnit.Meter, busPos, targetPos);

    if (meters < 1000) {
      _hasAlerted = true;
      _showSystemNotification(
        "🚌 Bus is Arriving!",
        "The bus is ${meters.toInt()}m away from your stop. Please be ready.",
      );
      Future.microtask(() {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.green.shade50,
              title: const Row(
                children: [
                  Icon(Icons.directions_bus, color: Colors.green),
                  SizedBox(width: 10),
                  Text("Bus Nearby!"),
                ],
              ),
              content: Text(
                "The bus is ${meters.toInt()} meters away from your assigned stop.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      });
    }
  }

  // --- EXISTING HELPERS ---
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition();
    setState(() => _myLocation = LatLng(position.latitude, position.longitude));
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notification History"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('announcements')
                .where('school_id', isEqualTo: widget.schoolId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty)
                return const Center(child: Text("No history."));
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index];
                  return ListTile(
                    title: Text(
                      data['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(data['message']),
                    leading: const Icon(Icons.message, color: Colors.grey),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _centerOnBus() {
    if (_lastKnownBusPos != null) {
      _mapController.move(_lastKnownBusPos!, 15.0);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Bus not active.")));
    }
  }

  void _centerOnMe() async {
    await _getCurrentLocation();
    if (_myLocation != null) _mapController.move(_myLocation!, 15.0);
  }

  void _makePhoneCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phone number not available.")),
      );
      return;
    }
    final Uri url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // --- SET HOME LOCATION DIALOG ---
  void _showSetHomeLocationDialog() {
    if (_currentStudentId.isEmpty) return;

    LatLng initialCenter =
        _currentHomeLatLng ?? _myLocation ?? const LatLng(10.8505, 76.2711);
    LatLng? pickedLocation = initialCenter;
    MapController dialogMapController = MapController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text(
            "Set Home Location",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: Column(
              children: [
                const Text(
                  "Tap the map to pin your home, or use the GPS button to set your current location.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: dialogMapController,
                            options: MapOptions(
                              initialCenter: initialCenter,
                              initialZoom: 15.0,
                              onTap: (tapPosition, point) {
                                setStateDialog(() => pickedLocation = point);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.childsafe.parent',
                              ),
                              if (pickedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: pickedLocation!,
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

                          Positioned(
                            top: 10,
                            right: 10,
                            child: FloatingActionButton(
                              heroTag: "dialog_loc_btn",
                              mini: true,
                              backgroundColor: Colors.white,
                              onPressed: () async {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Fetching GPS... (Make sure Emulator location is set)",
                                    ),
                                  ),
                                );
                                try {
                                  bool serviceEnabled =
                                      await Geolocator.isLocationServiceEnabled();
                                  if (!serviceEnabled)
                                    throw Exception(
                                      "Location services disabled",
                                    );

                                  LocationPermission permission =
                                      await Geolocator.checkPermission();
                                  if (permission == LocationPermission.denied) {
                                    permission =
                                        await Geolocator.requestPermission();
                                    if (permission == LocationPermission.denied)
                                      throw Exception("Permission denied");
                                  }

                                  Position? position =
                                      await Geolocator.getLastKnownPosition();
                                  position ??=
                                      await Geolocator.getCurrentPosition(
                                        desiredAccuracy: LocationAccuracy.high,
                                        timeLimit: const Duration(seconds: 5),
                                      );

                                  LatLng newLoc = LatLng(
                                    position.latitude,
                                    position.longitude,
                                  );

                                  setStateDialog(() {
                                    pickedLocation = newLoc;
                                  });
                                  dialogMapController.move(newLoc, 17.0);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("GPS Error: $e"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blueAccent,
                              ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (pickedLocation == null) return;
                await _db.collection('students').doc(_currentStudentId).update({
                  'home_location': {
                    'lat': pickedLocation!.latitude,
                    'lng': pickedLocation!.longitude,
                  },
                });

                setState(() {
                  _currentHomeLatLng = pickedLocation;
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Home Location Saved!"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.save),
              label: const Text("Save Location"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CONTACT DIRECTORY BOTTOM SHEET ---
  void _showContactDirectory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Settings & Directory",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),

              // 1. SET HOME LOCATION
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.home, color: Colors.white),
                ),
                title: const Text(
                  "Home Location",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _currentHomeLatLng == null
                      ? "Not set. Tap to add."
                      : "Tap to update your home location",
                ),
                trailing: const Icon(
                  Icons.edit_location_alt,
                  color: Colors.teal,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showSetHomeLocationDialog();
                },
              ),
              const Divider(),

              // 2. SCHOOL ADMIN
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.business, color: Colors.white),
                ),
                title: const Text(
                  "School Administration",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Tap to call the school office"),
                trailing: const Icon(Icons.call, color: Colors.green),
                onTap: () {
                  Navigator.pop(context);
                  _makePhoneCall("+919876543210");
                },
              ),
              const Divider(),

              // 3. DYNAMIC DRIVER
              _currentRouteId.isEmpty
                  ? const ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(Icons.directions_bus, color: Colors.white),
                      ),
                      title: Text(
                        "Bus Driver",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("No route assigned yet."),
                    )
                  : StreamBuilder<DocumentSnapshot>(
                      stream: _db
                          .collection('live_location')
                          .doc('route_$_currentRouteId')
                          .snapshots(),
                      builder: (context, snapshot) {
                        String driverName = "Assigned Bus Driver";
                        String? driverPhone;

                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          if (data.containsKey('driver_name'))
                            driverName = data['driver_name'];
                          if (data.containsKey('driver_phone'))
                            driverPhone = data['driver_phone'];
                        }

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(
                              Icons.directions_bus,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            driverName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            driverPhone != null
                                ? "Tap to call the driver directly"
                                : "Phone number currently unavailable",
                          ),
                          trailing: driverPhone != null
                              ? const Icon(Icons.call, color: Colors.green)
                              : null,
                          onTap: () {
                            if (driverPhone != null) {
                              Navigator.pop(context);
                              _makePhoneCall(driverPhone);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Driver phone number not available yet.",
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  String _calculateETA(LatLng busPos, LatLng targetPos) {
    const Distance distance = Distance();
    double km = distance.as(LengthUnit.Kilometer, busPos, targetPos);
    double hours = km / 25.0; // Assuming average bus speed of 25km/h in traffic
    int minutes = (hours * 60).round();
    if (minutes < 1) return "<1 min";
    return "$minutes min";
  }

  void _loadRouteShape(String routeId) async {
    if (_isRouteLoaded) return;
    var doc = await _db
        .collection('schools')
        .doc(widget.schoolId)
        .collection('routes')
        .doc(routeId)
        .get();
    if (doc.exists && doc.data()!.containsKey('stops')) {
      List<dynamic> stops = doc.data()!['stops'];

      // Plot the lines and markers
      List<LatLng> points = stops
          .map((s) => LatLng(s['lat'], s['lng']))
          .toList();
      List<Marker> markers = points
          .map(
            (p) => Marker(
              point: p,
              width: 30,
              height: 30,
              child: const Icon(
                Icons.location_on,
                size: 15,
                color: Colors.grey,
              ),
            ),
          )
          .toList();

      // Find the exact coordinates of the assigned stop!
      LatLng? foundStopLatLng;
      for (var stop in stops) {
        if (stop['name'] == _assignedStopName) {
          foundStopLatLng = LatLng(stop['lat'], stop['lng']);
          break;
        }
      }

      if (mounted) {
        setState(() {
          _routePolyline = points;
          _stopMarkers = markers;
          _assignedStopLatLng = foundStopLatLng;
          _isRouteLoaded = true;
        });
      }
    }
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String today = DateTime.now().toIso8601String().split('T')[0];
    String currentSession = DateTime.now().hour >= 12 ? "Afternoon" : "Morning";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Child Safe Tracker"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showContactDirectory,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: _db
                .collection('users')
                .doc(_auth.currentUser!.email)
                .snapshots(),
            builder: (context, userSnap) {
              if (!userSnap.hasData)
                return const Center(child: CircularProgressIndicator());
              var userData = userSnap.data!;
              String studentName = userData['student_name'] ?? 'Unknown';

              return StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('students')
                    .where('school_id', isEqualTo: widget.schoolId)
                    .where('name', isEqualTo: studentName)
                    .limit(1)
                    .snapshots(),
                builder: (context, studentQuery) {
                  if (!studentQuery.hasData ||
                      studentQuery.data!.docs.isEmpty) {
                    return _buildEmptyState(
                      "Student Not Found",
                      "Your account is not linked to a student. Please contact the school admin.",
                      Icons.person_off,
                    );
                  }

                  var studentDoc = studentQuery.data!.docs.first;
                  String studentId = studentDoc.id;
                  Map<String, dynamic> studentDataMap =
                      studentDoc.data() as Map<String, dynamic>;
                  String routeId = studentDataMap.containsKey('route_id')
                      ? studentDataMap['route_id']
                      : '';
                  String stopName =
                      studentDataMap.containsKey('stop_name') &&
                          studentDataMap['stop_name'] != null
                      ? studentDataMap['stop_name']
                      : 'No Stop Assigned';

                  // Tracking for functions
                  _currentRouteId = routeId;
                  _currentStudentId = studentId;
                  _assignedStopName = stopName;

                  if (routeId.isNotEmpty) _loadRouteShape(routeId);

                  LatLng? homeLatLng;
                  try {
                    var h = studentDataMap['home_location'];
                    if (h != null) homeLatLng = LatLng(h['lat'], h['lng']);
                  } catch (e) {
                    homeLatLng = null;
                  }

                  _currentHomeLatLng = homeLatLng;

                  return Column(
                    children: [
                      // --- ATTENDANCE STATUS BAR ---
                      StreamBuilder<DocumentSnapshot>(
                        stream: _db
                            .collection('attendance')
                            .doc("${studentId}_${today}_$currentSession")
                            .snapshots(),
                        builder: (context, attendanceSnap) {
                          bool isPresent =
                              attendanceSnap.hasData &&
                              attendanceSnap.data!.exists;
                          bool isDroppedOff = false;

                          if (isPresent) {
                            var attData =
                                attendanceSnap.data!.data()
                                    as Map<String, dynamic>;
                            if (attData.containsKey('status') &&
                                attData['status'] == 'Dropped Off') {
                              isDroppedOff = true;
                            }
                          }

                          Color bgColor = Colors.orange.shade50;
                          Color iconColor = Colors.orange;
                          IconData icon = Icons.info;
                          String text =
                              "$studentName has NOT boarded yet ($currentSession)";

                          if (isDroppedOff) {
                            bgColor = Colors.blue.shade50;
                            iconColor = Colors.blue;
                            icon = Icons.school;
                            text = currentSession == "Morning"
                                ? "$studentName REACHED SCHOOL SAFELY"
                                : "$studentName REACHED HOME SAFELY";
                          } else if (isPresent) {
                            bgColor = Colors.green.shade50;
                            iconColor = Colors.green;
                            icon = Icons.check_circle;
                            text = currentSession == "Morning"
                                ? "$studentName is ON THE BUS (Going to School)"
                                : "$studentName is ON THE BUS (Going Home)";
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            color: bgColor,
                            child: Row(
                              children: [
                                Icon(icon, color: iconColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: iconColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // --- MISSING HOME LOCATION BANNER ---
                      if (homeLatLng == null)
                        Container(
                          color: Colors.red.shade50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  "Home location not set! Arrival alerts won't work.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _showSetHomeLocationDialog,
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                ),
                                child: const Text(
                                  "SET NOW",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // --- MAP OR EMPTY STATE ---
                      Expanded(
                        child: routeId.isEmpty
                            ? _buildEmptyState(
                                "No Route Assigned",
                                "Your child has not been assigned to a bus route yet.",
                                Icons.map_outlined,
                              )
                            : StreamBuilder<DocumentSnapshot>(
                                stream: _db
                                    .collection('live_location')
                                    .doc('route_$routeId')
                                    .snapshots(),
                                builder: (context, busSnap) {
                                  if (!busSnap.hasData ||
                                      !busSnap.data!.exists) {
                                    return _buildEmptyState(
                                      "Bus is Offline",
                                      "Live map tracking will appear here once the driver starts the trip.",
                                      Icons.location_off,
                                    );
                                  }

                                  Map<String, dynamic> busData =
                                      busSnap.data!.data()
                                          as Map<String, dynamic>;

                                  if (busData['status'] == 'inactive') {
                                    return _buildEmptyState(
                                      "Trip Ended",
                                      "The bus has finished its route and is currently offline.",
                                      Icons.directions_bus_filled_outlined,
                                    );
                                  }

                                  LatLng busPos = LatLng(
                                    busData['latitude'],
                                    busData['longitude'],
                                  );
                                  double heading = (busData['heading'] ?? 0)
                                      .toDouble();

                                  Future.microtask(() {
                                    if (mounted) {
                                      if (_lastKnownBusPos != busPos)
                                        setState(
                                          () => _lastKnownBusPos = busPos,
                                        );
                                      // Geofence using the assigned stop if we have it, otherwise fallback to home location
                                      LatLng? targetLocation =
                                          _assignedStopLatLng ?? homeLatLng;
                                      if (targetLocation != null) {
                                        _checkGeofence(busPos, targetLocation);
                                      }
                                    }
                                  });

                                  String driverPhone =
                                      busData.containsKey('driver_phone')
                                      ? busData['driver_phone']
                                      : "";
                                  String busNumber =
                                      busData.containsKey('bus_number')
                                      ? busData['bus_number']
                                      : "Bus";
                                  int speed = busData['speed'] ?? 0;

                                  // Choose the best target for ETA
                                  LatLng? targetEtaLatLng =
                                      _assignedStopLatLng ?? homeLatLng;

                                  return Stack(
                                    children: [
                                      FlutterMap(
                                        mapController: _mapController,
                                        options: MapOptions(
                                          initialCenter: busPos,
                                          initialZoom: 14.5,
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName:
                                                'com.childsafe.parent',
                                          ),
                                          if (_routePolyline.isNotEmpty)
                                            PolylineLayer(
                                              polylines: [
                                                Polyline(
                                                  points: _routePolyline,
                                                  color: Colors.blue
                                                      .withOpacity(0.7),
                                                  strokeWidth: 4.0,
                                                ),
                                              ],
                                            ),
                                          if (targetEtaLatLng != null)
                                            PolylineLayer(
                                              polylines: [
                                                Polyline(
                                                  points: [
                                                    busPos,
                                                    targetEtaLatLng,
                                                  ],
                                                  color: Colors.grey
                                                      .withOpacity(0.5),
                                                  strokeWidth: 2.0,
                                                  pattern:
                                                      const StrokePattern.dotted(),
                                                ),
                                              ],
                                            ),
                                          MarkerLayer(markers: _stopMarkers),

                                          // Highlight the EXACT Assigned Stop
                                          if (_assignedStopLatLng != null)
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: _assignedStopLatLng!,
                                                  width: 50,
                                                  height: 50,
                                                  child: const Icon(
                                                    Icons.location_on,
                                                    color: Colors.redAccent,
                                                    size: 40,
                                                  ),
                                                ),
                                              ],
                                            ),

                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: busPos,
                                                width: 50,
                                                height: 50,
                                                child: Transform.rotate(
                                                  angle:
                                                      (heading *
                                                      (3.14159 / 180)),
                                                  child: const Icon(
                                                    Icons.directions_bus,
                                                    color: Colors.indigo,
                                                    size: 40,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_myLocation != null)
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: _myLocation!,
                                                  width: 40,
                                                  height: 40,
                                                  child: const Icon(
                                                    Icons.my_location,
                                                    color: Colors.blueAccent,
                                                    size: 30,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (homeLatLng != null)
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: homeLatLng,
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
                                      Positioned(
                                        top: 20,
                                        right: 15,
                                        child: Column(
                                          children: [
                                            FloatingActionButton(
                                              heroTag: "btn_bus",
                                              mini: true,
                                              backgroundColor: Colors.white,
                                              onPressed: _centerOnBus,
                                              child: const Icon(
                                                Icons.directions_bus,
                                                color: Colors.indigo,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            FloatingActionButton(
                                              heroTag: "btn_me",
                                              mini: true,
                                              backgroundColor: Colors.white,
                                              onPressed: _centerOnMe,
                                              child: const Icon(
                                                Icons.my_location,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Positioned(
                                        bottom: 20,
                                        left: 15,
                                        right: 15,
                                        child: Card(
                                          elevation: 5,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 15,
                                              vertical: 15,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        "Stop: $stopName",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        "ETA: ${targetEtaLatLng != null ? _calculateETA(busPos, targetEtaLatLng) : '--'}",
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.indigo,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Row(
                                                        children: [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .orange
                                                                      .shade100,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        4,
                                                                      ),
                                                                ),
                                                            child: Text(
                                                              busNumber,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .deepOrange,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            "${speed}km/h",
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                        ),
                                                  ),
                                                  onPressed: () =>
                                                      _makePhoneCall(
                                                        driverPhone,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.call,
                                                    size: 18,
                                                  ),
                                                  label: const Text("CALL"),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          // --- SMART SOS OVERLAY ---
          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('alerts')
                .where('school_id', isEqualTo: widget.schoolId)
                .where('is_active', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return const SizedBox();

              var alert = snapshot.data!.docs.first;
              var alertData = alert.data() as Map<String, dynamic>;

              bool isCritical = true;
              if (alertData.containsKey('type')) {
                isCritical = alertData['type'] == 'critical';
              }

              Color boxColor = isCritical ? Colors.red : Colors.orange.shade800;
              String title = isCritical
                  ? "EMERGENCY ALERT"
                  : "BUS DELAY / BREAKDOWN";
              IconData icon = isCritical ? Icons.warning : Icons.car_repair;
              String subtitle = isCritical
                  ? "The school admin has been notified."
                  : "Students are safe. Admin is arranging a backup.";

              return Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(30),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(blurRadius: 20, color: boxColor)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 60),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          alertData['message'] ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

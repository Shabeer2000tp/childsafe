import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';
import 'login_screen.dart';

class DriverScreen extends StatefulWidget {
  final String schoolId;
  const DriverScreen({super.key, required this.schoolId});

  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Navigation State
  int _currentIndex = 0;

  // Trip & Location State
  bool _isTripActive = false;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  String _driverName = "Driver";
  String _assignedBus = "Unknown Bus";

  // Selection State (Route & Session)
  String _selectedRouteId = "none";
  String _selectedRouteName = "Loading...";
  String _tripSession = "Morning";
  List<Map<String, String>> _routeList = [
    {'id': 'none', 'name': 'Loading...'},
  ];

  // Store route stops for Geofence validation
  List<Map<String, dynamic>> _currentRouteStops = [];

  // Notification & RFID State
  late DateTime _appLaunchTime;
  StreamSubscription? _announcementSub;
  StreamSubscription? _rfidSub;
  String _lastProcessedTag = "";

  // History State
  DateTime _selectedHistoryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _appLaunchTime = DateTime.now();
    _fetchRoutesAndDriverDetails();
    _initNotifications();
    _listenForAnnouncements();
    _listenForRFID(); // <--- HARDWARE LISTENER ACTIVATED!
    _initLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _announcementSub?.cancel();
    _rfidSub?.cancel(); // <--- CLEANUP LISTENER
    super.dispose();
  }

  // ==========================================================================
  // 1. DATA, RFID & NOTIFICATION SETUP
  // ==========================================================================

  void _fetchRoutesAndDriverDetails() async {
    var routeQuery = await _db
        .collection('schools')
        .doc(widget.schoolId)
        .collection('routes')
        .get();
    List<Map<String, String>> realRoutes = [];

    for (var doc in routeQuery.docs) {
      String rName = doc.data().containsKey('name') ? doc['name'] : doc.id;
      realRoutes.add({'id': doc.id, 'name': rName});
    }

    User? user = _auth.currentUser;
    if (user != null) {
      var doc = await _db.collection('users').doc(user.email).get();
      if (doc.exists) {
        _driverName = doc.data()!['name'] ?? "Driver";
        _assignedBus = doc.data()!['assigned_bus'] ?? "Unknown Bus";
      }
    }

    if (mounted) {
      setState(() {
        if (realRoutes.isNotEmpty) {
          _routeList = realRoutes;
          _selectedRouteId = realRoutes.first['id']!;
          _selectedRouteName = realRoutes.first['name']!;
          _fetchRouteStops(_selectedRouteId);
        } else {
          _routeList = [
            {'id': 'none', 'name': 'No Routes Found'},
          ];
          _selectedRouteId = 'none';
          _selectedRouteName = 'No Routes Found';
        }

        if (DateTime.now().hour >= 12) {
          _tripSession = "Afternoon";
        }
      });
    }
  }

  void _fetchRouteStops(String routeId) async {
    if (routeId == 'none' || routeId == 'Loading...') return;
    var doc = await _db
        .collection('schools')
        .doc(widget.schoolId)
        .collection('routes')
        .doc(routeId)
        .get();
    if (doc.exists && doc.data()!.containsKey('stops')) {
      setState(() {
        _currentRouteStops = List<Map<String, dynamic>>.from(
          doc.data()!['stops'],
        );
      });
    }
  }

  // --- 🔴 THE IoT HARDWARE LISTENER 🔴 ---
  void _listenForRFID() {
    _rfidSub = _db.collection('scans').doc('latest_scan').snapshots().listen((
      doc,
    ) async {
      if (!doc.exists) return;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      if (!data.containsKey('tag_id')) return;

      String scannedTag = data['tag_id'].toString().trim();

      // Debounce: Prevent the same card from scanning 10 times a second
      if (scannedTag.isEmpty || scannedTag == _lastProcessedTag) return;

      _lastProcessedTag = scannedTag;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _lastProcessedTag = "");
      });

      if (_selectedRouteId == 'none' || _selectedRouteId == 'Loading...') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Scan ignored: Please select a Route first!"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 1. Find which student owns this RFID card
      var studentQuery = await _db
          .collection('students')
          .where('school_id', isEqualTo: widget.schoolId)
          .where('rfid_tag_id', isEqualTo: scannedTag)
          .get();

      if (studentQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("❌ Unknown RFID Tag: $scannedTag"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      var studentDoc = studentQuery.docs.first;
      String studentId = studentDoc.id;
      String studentName = studentDoc['name'];

      String today = DateTime.now().toIso8601String().split('T')[0];
      String attDocId = "${studentId}_${today}_$_tripSession";

      // 2. Check their current attendance status
      var attDoc = await _db.collection('attendance').doc(attDocId).get();

      if (!attDoc.exists) {
        // CHECK IN!
        await _db.collection('attendance').doc(attDocId).set({
          'student_id': studentId,
          'student_name': studentName,
          'school_id': widget.schoolId,
          'date': today,
          'session': _tripSession,
          'timestamp': FieldValue.serverTimestamp(),
          'method': 'RFID',
          'route_id': _selectedRouteId,
          'bus_number': _assignedBus,
          'status': 'Boarded',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ $studentName BOARDED!"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        var attData = attDoc.data() as Map<String, dynamic>;
        if (attData['status'] == 'Boarded') {
          // CHECK OUT!
          await _db.collection('attendance').doc(attDocId).update({
            'status': 'Dropped Off',
            'dropoff_time': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("👋 $studentName DROPPED OFF!"),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⚠️ $studentName is already dropped off."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    });
  }

  void _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notificationsPlugin.initialize(settings);
    if (Platform.isAndroid) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

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

  Future<void> _showSystemNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'driver_alerts',
          'Driver Alerts',
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

  // ==========================================================================
  // 2. LOCATION & TRIP LOGIC
  // ==========================================================================
  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position initialPos = await Geolocator.getCurrentPosition();
    setState(
      () =>
          _currentPosition = LatLng(initialPos.latitude, initialPos.longitude),
    );

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position pos) {
          setState(
            () => _currentPosition = LatLng(pos.latitude, pos.longitude),
          );
          _mapController.move(_currentPosition!, 16.0);

          if (_isTripActive && _selectedRouteId != 'none') {
            _db.collection('live_location').doc('route_$_selectedRouteId').set({
              'school_id': widget.schoolId,
              'route_id': _selectedRouteId,
              'bus_number': _assignedBus,
              'driver_name': _driverName,
              'session': _tripSession,
              'latitude': pos.latitude,
              'longitude': pos.longitude,
              'heading': pos.heading,
              'speed': (pos.speed * 3.6).round(),
              'status': 'active',
              'last_updated': FieldValue.serverTimestamp(),
            });
          }
        });
  }

  void _toggleTrip() async {
    if (_isTripActive) {
      String today = DateTime.now().toIso8601String().split('T')[0];
      var activeStudents = await _db
          .collection('attendance')
          .where('date', isEqualTo: today)
          .where('session', isEqualTo: _tripSession)
          .where('route_id', isEqualTo: _selectedRouteId)
          .where('status', isEqualTo: 'Boarded')
          .get();

      if (activeStudents.docs.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.red.shade50,
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 35),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "CRITICAL WARNING",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              "Cannot end the trip! There are ${activeStudents.docs.length} student(s) still marked as 'On Bus'.\n\nPlease check the seats and manually drop them off first.",
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("I WILL CHECK THE BUS"),
              ),
            ],
          ),
        );
        return;
      }

      setState(() => _isTripActive = false);
      await _db
          .collection('live_location')
          .doc('route_$_selectedRouteId')
          .update({'status': 'inactive'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trip Ended safely. Bus is offline.")),
      );
    } else {
      setState(() => _isTripActive = true);
      if (_currentPosition != null && _selectedRouteId != 'none') {
        await _db
            .collection('live_location')
            .doc('route_$_selectedRouteId')
            .set({
              'school_id': widget.schoolId,
              'route_id': _selectedRouteId,
              'bus_number': _assignedBus,
              'driver_name': _driverName,
              'session': _tripSession,
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
              'heading': 0.0,
              'speed': 0,
              'status': 'active',
              'last_updated': FieldValue.serverTimestamp(),
            });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Trip Started! Tracking $_selectedRouteName live."),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleIndividualCheckout(
    String studentId,
    String studentName,
    String stopName,
  ) async {
    Map<String, dynamic>? assignedStop;
    try {
      assignedStop = _currentRouteStops.firstWhere(
        (s) => s['name'] == stopName,
      );
    } catch (e) {
      assignedStop = null;
    }

    if (assignedStop != null && _currentPosition != null) {
      const Distance distance = Distance();
      double meters = distance.as(
        LengthUnit.Meter,
        _currentPosition!,
        LatLng(assignedStop['lat'], assignedStop['lng']),
      );

      if (meters > 300) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wrong_location, color: Colors.orange, size: 30),
                SizedBox(width: 10),
                Text(
                  "Wrong Stop?",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              "$studentName is assigned to '$stopName', but the bus is currently ${meters.toInt()} meters away from that location.\n\nAre you sure you want to drop them off here?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _processCheckout(studentId);
                },
                child: const Text("Drop Off Anyway"),
              ),
            ],
          ),
        );
        return;
      }
    }

    _processCheckout(studentId);
  }

  void _processCheckout(String studentId) async {
    String today = DateTime.now().toIso8601String().split('T')[0];
    await _db
        .collection('attendance')
        .doc("${studentId}_${today}_$_tripSession")
        .update({
          'status': 'Dropped Off',
          'dropoff_time': FieldValue.serverTimestamp(),
        });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Student Checked Out"),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // ==========================================================================
  // 3. UI BUILDERS
  // ==========================================================================
  Widget _buildMapTab() {
    // 1. Convert our Firebase stops into LatLng points for the map
    List<LatLng> routePoints = _currentRouteStops.map((stop) {
      return LatLng(stop['lat'] as double, stop['lng'] as double);
    }).toList();

    return Stack(
      children: [
        _currentPosition == null
            ? const Center(child: CircularProgressIndicator())
            : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition!,
                  initialZoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.childsafe.driver',
                  ),

                  // --- FIX: ADDED <Polyline<Object>> AND <Object> TYPES ---
                  if (routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: <Polyline<Object>>[
                        Polyline<Object>(
                          points: routePoints,
                          strokeWidth: 5.0,
                          color: Colors.blueAccent.withOpacity(0.7),
                          // Makes it look like a path!
                        ),
                      ],
                    ),

                  // --- UPDATED: BUS MARKER & STOP PINS ---
                  MarkerLayer(
                    markers: [
                      // Draw the stops as Red Pins
                      ..._currentRouteStops.map((stop) {
                        return Marker(
                          point: LatLng(
                            stop['lat'] as double,
                            stop['lng'] as double,
                          ),
                          width: 40,
                          height: 40,
                          child: const Column(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 30,
                              ),
                            ],
                          ),
                        );
                      }),

                      // Draw the Live Bus Location (drawn last so it stays on top)
                      Marker(
                        point: _currentPosition!,
                        width: 60,
                        height: 60,
                        child: const Icon(
                          Icons.directions_bus,
                          color: Colors.indigo,
                          size: 45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

        // ROUTE & SESSION SELECTION CARD
        Positioned(
          top: 10,
          left: 10,
          right: 10,
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Select Route:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRouteId,
                            items: _routeList
                                .map(
                                  (route) => DropdownMenuItem(
                                    value: route['id'],
                                    child: Text(
                                      route['name']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isTripActive
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedRouteId = val;
                                        _selectedRouteName = _routeList
                                            .firstWhere(
                                              (r) => r['id'] == val,
                                            )['name']!;
                                      });
                                      _fetchRouteStops(val);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("☀️ Morning"),
                        selected: _tripSession == "Morning",
                        selectedColor: Colors.amber.shade200,
                        onSelected: _isTripActive
                            ? null
                            : (selected) {
                                if (selected) {
                                  setState(() => _tripSession = "Morning");
                                }
                              },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("🏫 Afternoon"),
                        selected: _tripSession == "Afternoon",
                        selectedColor: Colors.blue.shade200,
                        onSelected: _isTripActive
                            ? null
                            : (selected) {
                                if (selected) {
                                  setState(() => _tripSession = "Afternoon");
                                }
                              },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTripActive
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        _isTripActive ? Icons.stop : Icons.play_arrow,
                        size: 28,
                      ),
                      label: Text(
                        _isTripActive ? "END TRIP" : "START LIVE TRACKING",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      onPressed:
                          _selectedRouteId == "Loading..." ||
                              _selectedRouteId == "none"
                          ? null
                          : _toggleTrip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text(
                    "Report an Issue",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: const Text(
                    "Select the issue type. This will notify Admin and Parents.",
                  ),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            await _db.collection('alerts').add({
                              'school_id': widget.schoolId,
                              'route_id': _selectedRouteId,
                              'bus_number': _assignedBus,
                              'driver_name': _driverName,
                              'type': 'warning',
                              'message':
                                  'BREAKDOWN / DELAY: $_assignedBus on $_selectedRouteName is experiencing technical issues. Students are safe, expect delays.',
                              'is_active': true,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Alert Sent!"),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          },
                          icon: const Icon(Icons.car_repair),
                          label: const Text("BUS BREAKDOWN (SAFE)"),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            await _db.collection('alerts').add({
                              'school_id': widget.schoolId,
                              'route_id': _selectedRouteId,
                              'bus_number': _assignedBus,
                              'driver_name': _driverName,
                              'type': 'critical',
                              'message':
                                  'CRITICAL EMERGENCY: $_assignedBus on $_selectedRouteName requires immediate assistance!',
                              'is_active': true,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Alert Sent!"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          icon: const Icon(Icons.warning_amber_rounded),
                          label: const Text("CRITICAL EMERGENCY"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.warning_amber_rounded, size: 28),
            label: const Text(
              "REPORT ISSUE / EMERGENCY",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    String today = DateTime.now().toIso8601String().split('T')[0];

    if (_selectedRouteId == "none" || _selectedRouteId == "Loading...") {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Please select a route from the Map tab to view students.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('students')
          .where('school_id', isEqualTo: widget.schoolId)
          .where('route_id', isEqualTo: _selectedRouteId)
          .snapshots(),
      builder: (context, studentSnap) {
        if (!studentSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var studentDocs = studentSnap.data!.docs;

        if (studentDocs.isEmpty) {
          return Center(
            child: Text("No students assigned to $_selectedRouteName."),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('attendance')
              .where('date', isEqualTo: today)
              .where('route_id', isEqualTo: _selectedRouteId)
              .snapshots(),
          builder: (context, attSnap) {
            if (!attSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            Map<String, String> attendanceMap = {};
            int boardedCount = 0;
            int droppedCount = 0;
            int morningTotal = 0;

            for (var doc in attSnap.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              String sId = data['student_id'];
              String status = data['status'];
              String session = data['session'];

              if (session == 'Morning') {
                morningTotal++;
              }

              if (session == _tripSession) {
                attendanceMap[sId] = status;
                if (status == 'Boarded') boardedCount++;
                if (status == 'Dropped Off') droppedCount++;
              }
            }

            int pendingCount = studentDocs.length - boardedCount - droppedCount;
            if (pendingCount < 0) pendingCount = 0;

            bool isMorning = _tripSession == "Morning";
            String massActionTitle = isMorning
                ? "MASS DROP-OFF AT SCHOOL"
                : "MASS BOARD AT SCHOOL";
            Color massActionColor = isMorning
                ? Colors.red.shade400
                : Colors.green.shade600;
            IconData massActionIcon = isMorning
                ? Icons.school
                : Icons.directions_bus;

            return Column(
              children: [
                // --- TOP SUMMARY DASHBOARD ---
                Container(
                  color: Colors.indigo.shade900,
                  padding: const EdgeInsets.fromLTRB(15, 20, 15, 25),
                  child: Column(
                    children: [
                      Text(
                        "$_tripSession Trip Status",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSummaryBox(
                            "Pending",
                            pendingCount.toString(),
                            Colors.grey.shade400,
                          ),
                          _buildSummaryBox(
                            "On Bus",
                            boardedCount.toString(),
                            Colors.green.shade400,
                          ),
                          _buildSummaryBox(
                            "Dropped",
                            droppedCount.toString(),
                            Colors.blue.shade400,
                          ),
                        ],
                      ),

                      if (!isMorning) ...[
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wb_sunny,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Morning Trip Count: $morningTotal Students",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: massActionColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(massActionIcon),
                          label: Text(
                            massActionTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.1,
                            ),
                          ),
                          onPressed: () async {
                            WriteBatch batch = _db.batch();

                            if (isMorning) {
                              var boardedStudents = attSnap.data!.docs.where(
                                (doc) =>
                                    (doc.data() as Map)['status'] ==
                                        'Boarded' &&
                                    (doc.data() as Map)['session'] ==
                                        _tripSession,
                              );
                              if (boardedStudents.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "No students currently on the bus!",
                                    ),
                                  ),
                                );
                                return;
                              }
                              for (var doc in boardedStudents) {
                                batch.update(doc.reference, {
                                  'status': 'Dropped Off',
                                  'dropoff_time': FieldValue.serverTimestamp(),
                                });
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "All students dropped off at school!",
                                  ),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            } else {
                              var unboardedStudents = studentDocs.where(
                                (s) => !attendanceMap.containsKey(s.id),
                              );
                              if (unboardedStudents.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "All students have already boarded.",
                                    ),
                                  ),
                                );
                                return;
                              }
                              for (var sDoc in unboardedStudents) {
                                var newDocRef = _db
                                    .collection('attendance')
                                    .doc("${sDoc.id}_${today}_$_tripSession");
                                batch.set(newDocRef, {
                                  'student_id': sDoc.id,
                                  'student_name':
                                      (sDoc.data() as Map)['name'] ?? 'Unknown',
                                  'school_id': widget.schoolId,
                                  'date': today,
                                  'session': _tripSession,
                                  'timestamp': FieldValue.serverTimestamp(),
                                  'method': 'Manual (Mass Board)',
                                  'route_id': _selectedRouteId,
                                  'bus_number': _assignedBus,
                                  'status': 'Boarded',
                                });
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "All remaining students boarded at school!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                            await batch.commit();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // --- LIST OF STUDENTS ---
                Expanded(
                  child: ListView.builder(
                    itemCount: studentDocs.length,
                    itemBuilder: (context, index) {
                      var studentData = studentDocs[index];
                      String studentId = studentData.id;

                      Map<String, dynamic> sData =
                          studentData.data() as Map<String, dynamic>;
                      String studentName = sData.containsKey('name')
                          ? sData['name']
                          : 'Unknown';
                      String stopName = sData.containsKey('stop_name')
                          ? sData['stop_name']
                          : 'Unknown Stop';

                      String currentStatus =
                          attendanceMap[studentId] ?? "Pending";
                      bool isPresent = currentStatus == 'Boarded';
                      bool isDroppedOff = currentStatus == 'Dropped Off';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDroppedOff
                                ? Colors.blue.shade100
                                : (isPresent
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200),
                            child: Icon(
                              isDroppedOff
                                  ? Icons.school
                                  : (isPresent
                                        ? Icons.directions_bus
                                        : Icons.person),
                              color: isDroppedOff
                                  ? Colors.blue
                                  : (isPresent ? Colors.green : Colors.grey),
                            ),
                          ),
                          title: Text(
                            studentName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: isDroppedOff
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            isDroppedOff
                                ? "Dropped off safely\n$stopName"
                                : (isPresent
                                      ? "Boarded (On Bus)\n$stopName"
                                      : "Not on bus\n$stopName"),
                          ),
                          isThreeLine: true,
                          trailing: isDroppedOff
                              ? const Text(
                                  "CHECKED OUT",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : (isPresent
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.logout,
                                          color: Colors.orange,
                                        ),
                                        tooltip: "Individual Check-out",
                                        onPressed: () =>
                                            _handleIndividualCheckout(
                                              studentId,
                                              studentName,
                                              stopName,
                                            ),
                                      )
                                    : ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          await _db
                                              .collection('attendance')
                                              .doc(
                                                "${studentId}_${today}_$_tripSession",
                                              )
                                              .set({
                                                'student_id': studentId,
                                                'student_name': studentName,
                                                'school_id': widget.schoolId,
                                                'date': today,
                                                'session': _tripSession,
                                                'timestamp':
                                                    FieldValue.serverTimestamp(),
                                                'method': 'Manual (Driver)',
                                                'route_id': _selectedRouteId,
                                                'bus_number': _assignedBus,
                                                'status': 'Boarded',
                                              });
                                        },
                                        child: const Text("Check In"),
                                      )),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================================
  // 4. HISTORY & COMPARISON TAB
  // ==========================================================================
  Widget _buildHistoryTab() {
    if (_selectedRouteId == "none" || _selectedRouteId == "Loading...") {
      return const Center(
        child: Text(
          "Please select a route from the Map tab.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    String formattedDate = _selectedHistoryDate.toIso8601String().split('T')[0];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "History: $formattedDate",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade50,
                  foregroundColor: Colors.indigo,
                ),
                icon: const Icon(Icons.calendar_month),
                label: const Text("Change Date"),
                onPressed: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedHistoryDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedHistoryDate = picked);
                  }
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('attendance')
                .where('school_id', isEqualTo: widget.schoolId)
                .where('route_id', isEqualTo: _selectedRouteId)
                .where('date', isEqualTo: formattedDate)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var records = snapshot.data!.docs;

              if (records.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "No trips recorded on $formattedDate",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              int morningCount = records
                  .where((doc) => (doc.data() as Map)['session'] == 'Morning')
                  .length;
              int afternoonCount = records
                  .where((doc) => (doc.data() as Map)['session'] == 'Afternoon')
                  .length;

              bool isMismatch = morningCount != afternoonCount;

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isMismatch
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isMismatch ? Colors.red : Colors.green,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  "☀️ Morning",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "$morningCount",
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 2,
                              height: 50,
                              color: Colors.grey.shade300,
                            ),
                            Column(
                              children: [
                                const Text(
                                  "🏫 Afternoon",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "$afternoonCount",
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 15,
                          ),
                          decoration: BoxDecoration(
                            color: isMismatch ? Colors.red : Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isMismatch
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMismatch
                                    ? "WARNING: Count Mismatch!"
                                    : "Counts Match Perfectly",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Detailed Log",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> data =
                            records[index].data() as Map<String, dynamic>;
                        String sName =
                            data['student_name']?.toString() ?? 'Unknown';
                        String session =
                            data['session']?.toString() ?? 'Unknown';
                        String status = data['status']?.toString() ?? '';
                        String time = data['timestamp'] != null
                            ? (data['timestamp'] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .split(' ')[1]
                                  .substring(0, 5)
                            : '--:--';

                        bool isMorn = session == 'Morning';

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 5,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isMorn
                                  ? Colors.orange.shade100
                                  : Colors.blue.shade100,
                              child: Icon(
                                isMorn ? Icons.wb_sunny : Icons.school,
                                color: isMorn ? Colors.orange : Colors.blue,
                              ),
                            ),
                            title: Text(
                              sName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "$session Trip - Last Status: $status",
                            ),
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
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBox(String title, String count, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _currentIndex == 0
          ? _buildMapTab()
          : (_currentIndex == 1 ? _buildAttendanceTab() : _buildHistoryTab()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Trip Map"),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check),
            label: "Attendance",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }
}

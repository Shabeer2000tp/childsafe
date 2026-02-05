import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class ParentScreen extends StatefulWidget {
  final String schoolId;

  const ParentScreen({super.key, required this.schoolId});

  @override
  _ParentScreenState createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MapController _mapController = MapController();
  LatLng? _currentBusPosition;

  // --- Calculate Smart ETA ---
  String _calculateETA(LatLng busPos, double homeLat, double homeLng) {
    const Distance distance = Distance();
    double km = distance.as(
      LengthUnit.Kilometer,
      busPos,
      LatLng(homeLat, homeLng),
    );
    double hours = km / 40.0; // 40 km/h avg speed
    int minutes = (hours * 60).round();

    if (minutes < 1) return "Arriving Now";
    if (minutes > 60) return "${(minutes / 60).toStringAsFixed(1)} hrs";
    return "$minutes mins";
  }

  // --- Allow Parent to Set Home Location ---
  void _openLocationPicker(
    String studentDocId,
    Map<String, dynamic>? currentLoc,
  ) {
    LatLng selectedPos = (currentLoc != null)
        ? LatLng(currentLoc['lat'], currentLoc['lng'])
        : const LatLng(10.8505, 76.2711);

    final MapController dialogMapController = MapController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> useCurrentLocation() async {
              LocationPermission permission =
                  await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
                if (permission == LocationPermission.denied) return;
              }
              Position position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
              );
              setStateDialog(() {
                selectedPos = LatLng(position.latitude, position.longitude);
              });
              dialogMapController.move(selectedPos, 15.0);
            }

            return AlertDialog(
              title: const Text("Set Home Location"),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    const Text(
                      "Tap map or use GPS button.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.indigo),
                        ),
                        child: Stack(
                          children: [
                            FlutterMap(
                              mapController: dialogMapController,
                              options: MapOptions(
                                initialCenter: selectedPos,
                                initialZoom: 15.0,
                                onTap: (_, p) =>
                                    setStateDialog(() => selectedPos = p),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.childsafe.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: selectedPos,
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
                              child: FloatingActionButton.small(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.indigo,
                                onPressed: useCurrentLocation,
                                child: const Icon(Icons.my_location),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                    await _db.collection('students').doc(studentDocId).update({
                      'home_location': {
                        'lat': selectedPos.latitude,
                        'lng': selectedPos.longitude,
                      },
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Home Location Updated!")),
                    );
                  },
                  child: const Text("Save Location"),
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
    String? parentEmail = _auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Child - ${widget.schoolId}'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. FETCH STUDENT DATA FIRST (To get Home Location)
        stream: _db
            .collection('students')
            .where('parent_id', isEqualTo: parentEmail)
            .snapshots(),
        builder: (context, studentSnapshot) {
          if (!studentSnapshot.hasData || studentSnapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No student found linked to this email."),
            );
          }

          var studentDoc = studentSnapshot.data!.docs.first;
          String name = studentDoc['name'];
          String status = studentDoc['status'];
          String docId = studentDoc.id;

          // Get Home Location (if set)
          LatLng? homeLatLng;
          try {
            var h = studentDoc['home_location'];
            if (h != null) homeLatLng = LatLng(h['lat'], h['lng']);
          } catch (e) {
            homeLatLng = null;
          }

          return Stack(
            children: [
              // 2. FETCH BUS DATA (For the Map)
              StreamBuilder<DocumentSnapshot>(
                stream: _db
                    .collection('live_location')
                    .doc('bus_${widget.schoolId}')
                    .snapshots(),
                builder: (context, busSnapshot) {
                  if (!busSnapshot.hasData || !busSnapshot.data!.exists) {
                    return const Center(
                      child: Text("Waiting for Bus Signal..."),
                    );
                  }

                  var busData =
                      busSnapshot.data!.data() as Map<String, dynamic>?;
                  if (busData == null)
                    return const Center(child: Text("Bus Data Error"));

                  _currentBusPosition = LatLng(
                    busData['latitude'],
                    busData['longitude'],
                  );

                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentBusPosition!,
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.childsafe.app',
                      ),

                      MarkerLayer(
                        markers: [
                          // BUS MARKER
                          Marker(
                            point: _currentBusPosition!,
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.directions_bus,
                              color: Colors.indigo,
                              size: 40,
                            ),
                          ),

                          // HOME MARKER
                          if (homeLatLng != null)
                            Marker(
                              point: homeLatLng,
                              width: 60,
                              height: 60,
                              child: const Icon(
                                Icons.home,
                                color: Colors.green,
                                size: 40,
                              ),
                            ),
                        ],
                      ),

                      // OPTIONAL: Draw Line between Bus and Home (Corrected)
                      if (homeLatLng != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [_currentBusPosition!, homeLatLng],
                              color: Colors.blue.withOpacity(0.5),
                              strokeWidth: 3.0,
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),

              // 3. STUDENT STATUS CARD
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(blurRadius: 10, color: Colors.black26),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "STUDENT STATUS",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_location, size: 16),
                            label: const Text("Set Home"),
                            onPressed: () => _openLocationPicker(
                              docId,
                              studentDoc['home_location'],
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: status.contains("On Bus")
                                ? Colors.green.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              status.contains("On Bus")
                                  ? Icons.directions_bus
                                  : Icons.school,
                              color: status.contains("On Bus")
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                status,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: status.contains("On Bus")
                                      ? Colors.green
                                      : Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (homeLatLng != null &&
                                  _currentBusPosition != null)
                                Text(
                                  "ETA: ${_calculateETA(_currentBusPosition!, homeLatLng.latitude, homeLatLng.longitude)}",
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

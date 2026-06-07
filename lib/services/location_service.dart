import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Check/Request Permissions
  Future<bool> handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // 2. Get Single Location (One-time)
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await handlePermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Update function signature to accept schoolId
  Future<void> sendLocationToCloud(
    double lat,
    double lng,
    String schoolId,
  ) async {
    // We can use the schoolId as part of the document name, or a query
    // Let's use a dynamic ID like 'bus_school_001'
    await _db.collection('live_location').doc('bus_$schoolId').set({
      'latitude': lat,
      'longitude': lng,
      'school_id': schoolId, // CRITICAL: Tag the data
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  // 4. NEW: Live Location Stream (This was missing!)
  Stream<Position> getPositionStream() {
    // Update when moving more than 10 meters
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  // 5. NEW: Stop Location Updates
  Future<void> stopLocationUpdates(String schoolId) async {
    try {
      await _db.collection('live_location').doc('bus_$schoolId').update({
        'status': 'inactive',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // It's possible the document doesn't exist, so we can ignore errors
      // or create it with an inactive status. For now, we'll just log.
      print("Could not set bus status to inactive: $e");
    }
  }
}

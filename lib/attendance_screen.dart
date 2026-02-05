import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatelessWidget {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  const AttendanceScreen({super.key});

  // Function to simulate the "NFC Scan"
  // Smart Cycle: Home -> Bus -> School -> Bus -> Home
  void _updateStatus(String studentId, String currentStatus) {
    String newStatus = "At Home"; // Default fallback

    if (currentStatus == "At Home") {
      newStatus = "On Bus (To School)";
    } else if (currentStatus == "On Bus (To School)") {
      newStatus = "At School";
    } else if (currentStatus == "At School") {
      newStatus = "On Bus (To Home)";
    } else if (currentStatus == "On Bus (To Home)") {
      newStatus = "At Home";
    }

    // 1. Update Cloud
    _db.collection('students').doc(studentId).update({
      'status': newStatus,
      'last_update': FieldValue.serverTimestamp(),
    });

    // 2. Log History
    _db.collection('attendance_logs').add({
      'student_id': studentId,
      'action': newStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Console (Simulated)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var students = snapshot.data!.docs;

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              var student = students[index];
              String name = student['name'];
              String status = student['status'];
              String id = student.id;
              String buttonText = "ACTION";
              Color buttonColor = Colors.blue;

              if (status == "At Home") {
                buttonText = "PICK UP (Morning)";
                buttonColor = Colors.green;
              } else if (status == "On Bus (To School)") {
                buttonText = "DROP AT SCHOOL";
                buttonColor = Colors.orange;
              } else if (status == "At School") {
                buttonText = "PICK UP (Evening)";
                buttonColor = Colors.green;
              } else if (status == "On Bus (To Home)") {
                buttonText = "DROP AT HOME";
                buttonColor = Colors.blue;
              }

              bool isOnBus = (status == "On Bus");

              return Card(
                margin: EdgeInsets.all(10),
                color: isOnBus ? Colors.green[100] : Colors.grey[100],
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOnBus ? Colors.green : Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Status: $status"),
                  // ... inside the ListTile ...
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                    ),
                    onPressed: () => _updateStatus(id, status),
                    child: Text(buttonText, style: TextStyle(fontSize: 12)),
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

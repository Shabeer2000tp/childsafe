// // import 'package:flutter/material.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_core/firebase_core.dart';
// // import 'login_screen.dart';

// // class SuperAdminScreen extends StatefulWidget {
// //   const SuperAdminScreen({super.key});

// //   @override
// //   _SuperAdminScreenState createState() => _SuperAdminScreenState();
// // }

// // class _SuperAdminScreenState extends State<SuperAdminScreen> {
// //   final FirebaseAuth _auth = FirebaseAuth.instance;
// //   final FirebaseFirestore _db = FirebaseFirestore.instance;

// //   int _selectedIndex = 0;

// //   // Controllers for New School
// //   final TextEditingController _schoolNameCtrl = TextEditingController();
// //   final TextEditingController _schoolAddressCtrl = TextEditingController();

// //   // Controllers for New Admin
// //   final TextEditingController _adminNameCtrl = TextEditingController();
// //   final TextEditingController _adminEmailCtrl = TextEditingController();
// //   final TextEditingController _adminPasswordCtrl = TextEditingController();
// //   String? _selectedSchoolId;

// //   bool _isLoading = false;

// //   // ==========================================================================
// //   // 1. LOGIC: ADD NEW SCHOOL
// //   // ==========================================================================
// //   Future<void> _addSchool() async {
// //     if (_schoolNameCtrl.text.trim().isEmpty) {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(const SnackBar(content: Text("School Name is required")));
// //       return;
// //     }

// //     setState(() => _isLoading = true);
// //     try {
// //       await _db.collection('schools').add({
// //         'name': _schoolNameCtrl.text.trim(),
// //         'address': _schoolAddressCtrl.text.trim(),
// //         'created_at': FieldValue.serverTimestamp(),
// //       });
// //       _schoolNameCtrl.clear();
// //       _schoolAddressCtrl.clear();
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(
// //           content: Text("School added successfully!"),
// //           backgroundColor: Colors.green,
// //         ),
// //       );
// //     } catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
// //       );
// //     }
// //     setState(() => _isLoading = false);
// //   }

// //   // ==========================================================================
// //   // 2. LOGIC: ADD NEW ADMIN (Using Secondary App Trick)
// //   // ==========================================================================
// //   Future<void> _addAdmin() async {
// //     if (_adminNameCtrl.text.trim().isEmpty ||
// //         _adminEmailCtrl.text.trim().isEmpty ||
// //         _adminPasswordCtrl.text.trim().isEmpty ||
// //         _selectedSchoolId == null) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(
// //           content: Text("All fields and a selected school are required"),
// //         ),
// //       );
// //       return;
// //     }

// //     setState(() => _isLoading = true);
// //     try {
// //       // 1. Initialize a temporary Firebase App to prevent logging out the Super Admin
// //       FirebaseApp tempApp = await Firebase.initializeApp(
// //         name: 'tempRegister',
// //         options: Firebase.app().options,
// //       );

// //       // 2. Create the user in the secondary app
// //       await FirebaseAuth.instanceFor(
// //         app: tempApp,
// //       ).createUserWithEmailAndPassword(
// //         email: _adminEmailCtrl.text.trim(),
// //         password: _adminPasswordCtrl.text.trim(),
// //       );

// //       // 3. Delete the temporary app
// //       await tempApp.delete();

// //       // 4. Save the user data to our Firestore database
// //       await _db
// //           .collection('users')
// //           .doc(_adminEmailCtrl.text.trim().toLowerCase())
// //           .set({
// //             'name': _adminNameCtrl.text.trim(),
// //             'email': _adminEmailCtrl.text.trim().toLowerCase(),
// //             'role': 'admin',
// //             'school_id': _selectedSchoolId,
// //             'created_at': FieldValue.serverTimestamp(),
// //           });

// //       _adminNameCtrl.clear();
// //       _adminEmailCtrl.clear();
// //       _adminPasswordCtrl.clear();
// //       setState(() => _selectedSchoolId = null);

// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(
// //           content: Text("Admin account created successfully!"),
// //           backgroundColor: Colors.green,
// //         ),
// //       );
// //     } on FirebaseAuthException catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(e.message ?? "Authentication Error"),
// //           backgroundColor: Colors.red,
// //         ),
// //       );
// //     } catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
// //       );
// //     }
// //     setState(() => _isLoading = false);
// //   }

// //   // ==========================================================================
// //   // 3. UI: MANAGE SCHOOLS TAB
// //   // ==========================================================================
// //   Widget _buildManageSchools() {
// //     return Padding(
// //       padding: const EdgeInsets.all(20.0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           const Text(
// //             "Register New School",
// //             style: TextStyle(
// //               fontSize: 24,
// //               fontWeight: FontWeight.bold,
// //               color: Colors.indigo,
// //             ),
// //           ),
// //           const SizedBox(height: 20),
// //           Card(
// //             elevation: 4,
// //             child: Padding(
// //               padding: const EdgeInsets.all(20.0),
// //               child: Row(
// //                 children: [
// //                   Expanded(
// //                     child: TextField(
// //                       controller: _schoolNameCtrl,
// //                       decoration: const InputDecoration(
// //                         labelText: "School Name",
// //                         border: OutlineInputBorder(),
// //                       ),
// //                     ),
// //                   ),
// //                   const SizedBox(width: 15),
// //                   Expanded(
// //                     child: TextField(
// //                       controller: _schoolAddressCtrl,
// //                       decoration: const InputDecoration(
// //                         labelText: "Location / Address",
// //                         border: OutlineInputBorder(),
// //                       ),
// //                     ),
// //                   ),
// //                   const SizedBox(width: 15),
// //                   SizedBox(
// //                     height: 55,
// //                     child: ElevatedButton.icon(
// //                       style: ElevatedButton.styleFrom(
// //                         backgroundColor: Colors.indigo,
// //                         foregroundColor: Colors.white,
// //                       ),
// //                       onPressed: _isLoading ? null : _addSchool,
// //                       icon: const Icon(Icons.business),
// //                       label: const Text("Add School"),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //           const SizedBox(height: 30),
// //           const Text(
// //             "Registered Schools",
// //             style: TextStyle(
// //               fontSize: 20,
// //               fontWeight: FontWeight.bold,
// //               color: Colors.indigo,
// //             ),
// //           ),
// //           const SizedBox(height: 10),
// //           Expanded(
// //             child: StreamBuilder<QuerySnapshot>(
// //               stream: _db
// //                   .collection('schools')
// //                   .orderBy('created_at', descending: true)
// //                   .snapshots(),
// //               builder: (context, snapshot) {
// //                 if (!snapshot.hasData)
// //                   return const Center(child: CircularProgressIndicator());
// //                 if (snapshot.data!.docs.isEmpty)
// //                   return const Center(
// //                     child: Text("No schools registered yet."),
// //                   );

// //                 return ListView.builder(
// //                   itemCount: snapshot.data!.docs.length,
// //                   itemBuilder: (context, index) {
// //                     var schoolDoc = snapshot.data!.docs[index];
// //                     Map<String, dynamic> schoolData =
// //                         schoolDoc.data() as Map<String, dynamic>;

// //                     // SAFE FETCHING
// //                     String sName = schoolData.containsKey('name')
// //                         ? schoolData['name']
// //                         : 'Unnamed School';
// //                     String sAddress = schoolData.containsKey('address')
// //                         ? schoolData['address']
// //                         : 'No address provided';

// //                     return Card(
// //                       child: ListTile(
// //                         leading: const CircleAvatar(
// //                           backgroundColor: Colors.indigo,
// //                           child: Icon(Icons.school, color: Colors.white),
// //                         ),
// //                         title: Text(
// //                           sName,
// //                           style: const TextStyle(fontWeight: FontWeight.bold),
// //                         ),
// //                         subtitle: Text(
// //                           "ID: ${schoolDoc.id} \nLocation: $sAddress",
// //                         ),
// //                       ),
// //                     );
// //                   },
// //                 );
// //               },
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // ==========================================================================
// //   // 4. UI: MANAGE ADMINS TAB
// //   // ==========================================================================
// //   Widget _buildManageAdmins() {
// //     return Padding(
// //       padding: const EdgeInsets.all(20.0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           const Text(
// //             "Create School Admin",
// //             style: TextStyle(
// //               fontSize: 24,
// //               fontWeight: FontWeight.bold,
// //               color: Colors.indigo,
// //             ),
// //           ),
// //           const SizedBox(height: 20),
// //           Card(
// //             elevation: 4,
// //             child: Padding(
// //               padding: const EdgeInsets.all(20.0),
// //               child: Column(
// //                 children: [
// //                   Row(
// //                     children: [
// //                       Expanded(
// //                         child: TextField(
// //                           controller: _adminNameCtrl,
// //                           decoration: const InputDecoration(
// //                             labelText: "Admin Name",
// //                             border: OutlineInputBorder(),
// //                           ),
// //                         ),
// //                       ),
// //                       const SizedBox(width: 15),
// //                       Expanded(
// //                         child: TextField(
// //                           controller: _adminEmailCtrl,
// //                           decoration: const InputDecoration(
// //                             labelText: "Email Address",
// //                             border: OutlineInputBorder(),
// //                           ),
// //                         ),
// //                       ),
// //                       const SizedBox(width: 15),
// //                       Expanded(
// //                         child: TextField(
// //                           controller: _adminPasswordCtrl,
// //                           obscureText: true,
// //                           decoration: const InputDecoration(
// //                             labelText: "Temporary Password",
// //                             border: OutlineInputBorder(),
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 15),
// //                   Row(
// //                     children: [
// //                       Expanded(
// //                         child: StreamBuilder<QuerySnapshot>(
// //                           stream: _db.collection('schools').snapshots(),
// //                           builder: (context, snapshot) {
// //                             if (!snapshot.hasData)
// //                               return const CircularProgressIndicator();

// //                             // SAFE FETCHING FOR DROPDOWN
// //                             List<DropdownMenuItem<String>> schoolItems =
// //                                 snapshot.data!.docs.map((doc) {
// //                                   Map<String, dynamic> data =
// //                                       doc.data() as Map<String, dynamic>;
// //                                   String sName = data.containsKey('name')
// //                                       ? data['name']
// //                                       : 'Unnamed (${doc.id})';
// //                                   return DropdownMenuItem(
// //                                     value: doc.id,
// //                                     child: Text(sName),
// //                                   );
// //                                 }).toList();

// //                             return DropdownButtonFormField<String>(
// //                               decoration: const InputDecoration(
// //                                 labelText: "Assign to School",
// //                                 border: OutlineInputBorder(),
// //                               ),
// //                               items: schoolItems,
// //                               value: _selectedSchoolId,
// //                               onChanged: (val) =>
// //                                   setState(() => _selectedSchoolId = val),
// //                             );
// //                           },
// //                         ),
// //                       ),
// //                       const SizedBox(width: 15),
// //                       SizedBox(
// //                         height: 55,
// //                         width: 200,
// //                         child: ElevatedButton.icon(
// //                           style: ElevatedButton.styleFrom(
// //                             backgroundColor: Colors.green,
// //                             foregroundColor: Colors.white,
// //                           ),
// //                           onPressed: _isLoading ? null : _addAdmin,
// //                           icon: _isLoading
// //                               ? const CircularProgressIndicator(
// //                                   color: Colors.white,
// //                                 )
// //                               : const Icon(Icons.person_add),
// //                           label: Text(
// //                             _isLoading ? "Creating..." : "Create Admin",
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),
// //           const SizedBox(height: 30),
// //           const Text(
// //             "Active Admins",
// //             style: TextStyle(
// //               fontSize: 20,
// //               fontWeight: FontWeight.bold,
// //               color: Colors.indigo,
// //             ),
// //           ),
// //           const SizedBox(height: 10),
// //           Expanded(
// //             child: StreamBuilder<QuerySnapshot>(
// //               stream: _db
// //                   .collection('users')
// //                   .where('role', isEqualTo: 'admin')
// //                   .snapshots(),
// //               builder: (context, snapshot) {
// //                 if (!snapshot.hasData)
// //                   return const Center(child: CircularProgressIndicator());
// //                 if (snapshot.data!.docs.isEmpty)
// //                   return const Center(child: Text("No admins created yet."));

// //                 return ListView.builder(
// //                   itemCount: snapshot.data!.docs.length,
// //                   itemBuilder: (context, index) {
// //                     var adminDoc = snapshot.data!.docs[index];
// //                     Map<String, dynamic> adminData =
// //                         adminDoc.data() as Map<String, dynamic>;

// //                     // SAFE FETCHING
// //                     String aName = adminData.containsKey('name')
// //                         ? adminData['name']
// //                         : 'Unknown Admin';
// //                     String aEmail = adminData.containsKey('email')
// //                         ? adminData['email']
// //                         : 'No Email';
// //                     String aSchoolId = adminData.containsKey('school_id')
// //                         ? adminData['school_id']
// //                         : 'Unassigned';

// //                     return Card(
// //                       child: ListTile(
// //                         leading: const CircleAvatar(
// //                           backgroundColor: Colors.green,
// //                           child: Icon(
// //                             Icons.admin_panel_settings,
// //                             color: Colors.white,
// //                           ),
// //                         ),
// //                         title: Text(
// //                           aName,
// //                           style: const TextStyle(fontWeight: FontWeight.bold),
// //                         ),
// //                         subtitle: Text(
// //                           "Email: $aEmail \nAssigned School ID: $aSchoolId",
// //                         ),
// //                       ),
// //                     );
// //                   },
// //                 );
// //               },
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text(
// //           "Child Safe - Master Portal",
// //           style: TextStyle(fontWeight: FontWeight.bold),
// //         ),
// //         backgroundColor: Colors.blueGrey.shade900,
// //         foregroundColor: Colors.white,
// //         actions: [
// //           IconButton(
// //             icon: const Icon(Icons.logout),
// //             onPressed: () {
// //               _auth.signOut();
// //               Navigator.pushReplacement(
// //                 context,
// //                 MaterialPageRoute(builder: (context) => LoginScreen()),
// //               );
// //             },
// //           ),
// //         ],
// //       ),
// //       body: Row(
// //         children: [
// //           // SIDEBAR NAVIGATION
// //           NavigationRail(
// //             backgroundColor: Colors.blueGrey.shade50,
// //             selectedIndex: _selectedIndex,
// //             onDestinationSelected: (int index) =>
// //                 setState(() => _selectedIndex = index),
// //             labelType: NavigationRailLabelType.all,
// //             selectedIconTheme: const IconThemeData(
// //               color: Colors.indigo,
// //               size: 30,
// //             ),
// //             selectedLabelTextStyle: const TextStyle(
// //               color: Colors.indigo,
// //               fontWeight: FontWeight.bold,
// //             ),
// //             destinations: const [
// //               NavigationRailDestination(
// //                 icon: Icon(Icons.business),
// //                 label: Text('Schools'),
// //               ),
// //               NavigationRailDestination(
// //                 icon: Icon(Icons.security),
// //                 label: Text('Admins'),
// //               ),
// //             ],
// //           ),
// //           const VerticalDivider(thickness: 1, width: 1),

// //           // MAIN CONTENT AREA
// //           Expanded(
// //             child: Container(
// //               color: Colors.grey.shade100,
// //               child: _selectedIndex == 0
// //                   ? _buildManageSchools()
// //                   : _buildManageAdmins(),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'login_screen.dart';

// class SuperAdminScreen extends StatefulWidget {
//   const SuperAdminScreen({super.key});

//   @override
//   _SuperAdminScreenState createState() => _SuperAdminScreenState();
// }

// class _SuperAdminScreenState extends State<SuperAdminScreen> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   int _selectedIndex = 0;

//   // Controllers for New School
//   final TextEditingController _schoolNameCtrl = TextEditingController();
//   final TextEditingController _schoolAddressCtrl = TextEditingController();

//   // Controllers for New Admin
//   final TextEditingController _adminNameCtrl = TextEditingController();
//   final TextEditingController _adminEmailCtrl = TextEditingController();
//   final TextEditingController _adminPasswordCtrl = TextEditingController();
//   String? _selectedSchoolId;

//   bool _isLoading = false;

//   // ==========================================================================
//   // 1. LOGIC: ADD NEW SCHOOL
//   // ==========================================================================
//   Future<void> _addSchool() async {
//     if (_schoolNameCtrl.text.trim().isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("School Name is required")));
//       return;
//     }

//     setState(() => _isLoading = true);
//     try {
//       await _db.collection('schools').add({
//         'name': _schoolNameCtrl.text.trim(),
//         'address': _schoolAddressCtrl.text.trim(),
//         'created_at': FieldValue.serverTimestamp(),
//       });
//       _schoolNameCtrl.clear();
//       _schoolAddressCtrl.clear();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("School added successfully!"),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
//       );
//     }
//     setState(() => _isLoading = false);
//   }

//   // ==========================================================================
//   // 2. LOGIC: ADD NEW ADMIN (Using Secondary App Trick)
//   // ==========================================================================
//   Future<void> _addAdmin() async {
//     if (_adminNameCtrl.text.trim().isEmpty ||
//         _adminEmailCtrl.text.trim().isEmpty ||
//         _adminPasswordCtrl.text.trim().isEmpty ||
//         _selectedSchoolId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("All fields and a selected school are required"),
//         ),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);
//     try {
//       // Create secondary app to prevent logging out the Super Admin
//       FirebaseApp tempApp = await Firebase.initializeApp(
//         name: 'tempRegister',
//         options: Firebase.app().options,
//       );
//       await FirebaseAuth.instanceFor(
//         app: tempApp,
//       ).createUserWithEmailAndPassword(
//         email: _adminEmailCtrl.text.trim(),
//         password: _adminPasswordCtrl.text.trim(),
//       );
//       await tempApp.delete();

//       // Save Admin Profile
//       await _db
//           .collection('users')
//           .doc(_adminEmailCtrl.text.trim().toLowerCase())
//           .set({
//             'name': _adminNameCtrl.text.trim(),
//             'email': _adminEmailCtrl.text.trim().toLowerCase(),
//             'role': 'admin',
//             'school_id': _selectedSchoolId,
//             'created_at': FieldValue.serverTimestamp(),
//           });

//       _adminNameCtrl.clear();
//       _adminEmailCtrl.clear();
//       _adminPasswordCtrl.clear();
//       setState(() => _selectedSchoolId = null);

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Admin account created successfully!"),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } on FirebaseAuthException catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(e.message ?? "Authentication Error"),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
//       );
//     }
//     setState(() => _isLoading = false);
//   }

//   // ==========================================================================
//   // 3. UI: MANAGE SCHOOLS TAB
//   // ==========================================================================
//   Widget _buildManageSchools() {
//     return Padding(
//       padding: const EdgeInsets.all(20.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Register New School",
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: Colors.indigo,
//             ),
//           ),
//           const SizedBox(height: 20),
//           Card(
//             elevation: 4,
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: _schoolNameCtrl,
//                       decoration: const InputDecoration(
//                         labelText: "School Name",
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 15),
//                   Expanded(
//                     child: TextField(
//                       controller: _schoolAddressCtrl,
//                       decoration: const InputDecoration(
//                         labelText: "Location / Address",
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 15),
//                   SizedBox(
//                     height: 55,
//                     child: ElevatedButton.icon(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.indigo,
//                         foregroundColor: Colors.white,
//                       ),
//                       onPressed: _isLoading ? null : _addSchool,
//                       icon: const Icon(Icons.business),
//                       label: const Text("Add School"),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 30),
//           const Text(
//             "Registered Schools",
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.indigo,
//             ),
//           ),
//           const SizedBox(height: 10),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: _db
//                   .collection('schools')
//                   .orderBy('created_at', descending: true)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData)
//                   return const Center(child: CircularProgressIndicator());
//                 if (snapshot.data!.docs.isEmpty)
//                   return const Center(
//                     child: Text("No schools registered yet."),
//                   );

//                 return ListView.builder(
//                   itemCount: snapshot.data!.docs.length,
//                   itemBuilder: (context, index) {
//                     var schoolDoc = snapshot.data!.docs[index];
//                     Map<String, dynamic> data =
//                         schoolDoc.data() as Map<String, dynamic>;

//                     // CRASH PROOFING
//                     String sName =
//                         (data.containsKey('name') &&
//                             data['name'] != null &&
//                             data['name'].toString().trim().isNotEmpty)
//                         ? data['name'].toString()
//                         : 'Unnamed School';
//                     String sAddress =
//                         (data.containsKey('address') &&
//                             data['address'] != null &&
//                             data['address'].toString().trim().isNotEmpty)
//                         ? data['address'].toString()
//                         : 'No Address Provided';

//                     return Card(
//                       child: ListTile(
//                         leading: const CircleAvatar(
//                           backgroundColor: Colors.indigo,
//                           child: Icon(Icons.school, color: Colors.white),
//                         ),
//                         title: Text(
//                           sName,
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         subtitle: Text(
//                           "ID: ${schoolDoc.id} \nLocation: $sAddress",
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ==========================================================================
//   // 4. UI: MANAGE ADMINS TAB
//   // ==========================================================================
//   Widget _buildManageAdmins() {
//     return Padding(
//       padding: const EdgeInsets.all(20.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Create School Admin",
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: Colors.indigo,
//             ),
//           ),
//           const SizedBox(height: 20),
//           Card(
//             elevation: 4,
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextField(
//                           controller: _adminNameCtrl,
//                           decoration: const InputDecoration(
//                             labelText: "Admin Name",
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 15),
//                       Expanded(
//                         child: TextField(
//                           controller: _adminEmailCtrl,
//                           decoration: const InputDecoration(
//                             labelText: "Email Address",
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 15),
//                       Expanded(
//                         child: TextField(
//                           controller: _adminPasswordCtrl,
//                           obscureText: true,
//                           decoration: const InputDecoration(
//                             labelText: "Temporary Password",
//                             border: OutlineInputBorder(),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 15),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: StreamBuilder<QuerySnapshot>(
//                           stream: _db.collection('schools').snapshots(),
//                           builder: (context, snapshot) {
//                             if (!snapshot.hasData)
//                               return const CircularProgressIndicator();

//                             List<DropdownMenuItem<String>>
//                             schoolItems = snapshot.data!.docs.map((doc) {
//                               Map<String, dynamic> data =
//                                   doc.data() as Map<String, dynamic>;

//                               // CRASH PROOFING
//                               String sName =
//                                   (data.containsKey('name') &&
//                                       data['name'] != null &&
//                                       data['name'].toString().trim().isNotEmpty)
//                                   ? data['name'].toString()
//                                   : 'Unnamed School (${doc.id.substring(0, 5)})';

//                               return DropdownMenuItem(
//                                 value: doc.id,
//                                 child: Text(
//                                   sName,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                               );
//                             }).toList();

//                             // Validate selectedSchoolId exists in current list
//                             bool isValidSelection = schoolItems.any(
//                               (item) => item.value == _selectedSchoolId,
//                             );
//                             if (!isValidSelection) _selectedSchoolId = null;

//                             return DropdownButtonFormField<String>(
//                               decoration: const InputDecoration(
//                                 labelText: "Assign to School",
//                                 border: OutlineInputBorder(),
//                               ),
//                               isExpanded: true,
//                               items: schoolItems,
//                               value: _selectedSchoolId,
//                               onChanged: (val) =>
//                                   setState(() => _selectedSchoolId = val),
//                             );
//                           },
//                         ),
//                       ),
//                       const SizedBox(width: 15),
//                       SizedBox(
//                         height: 55,
//                         width: 200,
//                         child: ElevatedButton.icon(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             foregroundColor: Colors.white,
//                           ),
//                           onPressed: _isLoading ? null : _addAdmin,
//                           icon: _isLoading
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white,
//                                 )
//                               : const Icon(Icons.person_add),
//                           label: Text(
//                             _isLoading ? "Creating..." : "Create Admin",
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 30),
//           const Text(
//             "Active Admins",
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: Colors.indigo,
//             ),
//           ),
//           const SizedBox(height: 10),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: _db
//                   .collection('users')
//                   .where('role', isEqualTo: 'admin')
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (!snapshot.hasData)
//                   return const Center(child: CircularProgressIndicator());
//                 if (snapshot.data!.docs.isEmpty)
//                   return const Center(child: Text("No admins created yet."));

//                 return ListView.builder(
//                   itemCount: snapshot.data!.docs.length,
//                   itemBuilder: (context, index) {
//                     var adminDoc = snapshot.data!.docs[index];
//                     Map<String, dynamic> data =
//                         adminDoc.data() as Map<String, dynamic>;

//                     // CRASH PROOFING
//                     String aName =
//                         (data.containsKey('name') && data['name'] != null)
//                         ? data['name'].toString()
//                         : 'Unknown Admin';
//                     String aEmail =
//                         (data.containsKey('email') && data['email'] != null)
//                         ? data['email'].toString()
//                         : 'No Email';
//                     String aSchoolId =
//                         (data.containsKey('school_id') &&
//                             data['school_id'] != null)
//                         ? data['school_id'].toString()
//                         : 'Unassigned';

//                     return Card(
//                       child: ListTile(
//                         leading: const CircleAvatar(
//                           backgroundColor: Colors.green,
//                           child: Icon(
//                             Icons.admin_panel_settings,
//                             color: Colors.white,
//                           ),
//                         ),
//                         title: Text(
//                           aName,
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                         subtitle: Text(
//                           "Email: $aEmail \nAssigned School ID: $aSchoolId",
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "Child Safe - Master Portal",
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.blueGrey.shade900,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () {
//               _auth.signOut();
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => LoginScreen()),
//               );
//             },
//           ),
//         ],
//       ),
//       body: Row(
//         children: [
//           NavigationRail(
//             backgroundColor: Colors.blueGrey.shade50,
//             selectedIndex: _selectedIndex,
//             onDestinationSelected: (int index) =>
//                 setState(() => _selectedIndex = index),
//             labelType: NavigationRailLabelType.all,
//             selectedIconTheme: const IconThemeData(
//               color: Colors.indigo,
//               size: 30,
//             ),
//             selectedLabelTextStyle: const TextStyle(
//               color: Colors.indigo,
//               fontWeight: FontWeight.bold,
//             ),
//             destinations: const [
//               NavigationRailDestination(
//                 icon: Icon(Icons.business),
//                 label: Text('Schools'),
//               ),
//               NavigationRailDestination(
//                 icon: Icon(Icons.security),
//                 label: Text('Admins'),
//               ),
//             ],
//           ),
//           const VerticalDivider(thickness: 1, width: 1),
//           Expanded(
//             child: Container(
//               color: Colors.grey.shade100,
//               child: _selectedIndex == 0
//                   ? _buildManageSchools()
//                   : _buildManageAdmins(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_screen.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  _SuperAdminScreenState createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _selectedIndex = 0;

  // Controllers for New School
  final TextEditingController _schoolNameCtrl = TextEditingController();
  final TextEditingController _schoolAddressCtrl = TextEditingController();

  // Controllers for New Admin
  final TextEditingController _adminNameCtrl = TextEditingController();
  final TextEditingController _adminEmailCtrl = TextEditingController();
  final TextEditingController _adminPasswordCtrl = TextEditingController();
  String? _selectedSchoolId;

  bool _isLoading = false;

  // ==========================================================================
  // 1. LOGIC: ADD NEW SCHOOL
  // ==========================================================================
  Future<void> _addSchool() async {
    if (_schoolNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("School Name is required")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _db.collection('schools').add({
        'name': _schoolNameCtrl.text.trim(),
        'address': _schoolAddressCtrl.text.trim(),
        'status': 'pending', // Added so you can track approval status!
        'created_at': FieldValue.serverTimestamp(),
      });
      _schoolNameCtrl.clear();
      _schoolAddressCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("School added successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  // ==========================================================================
  // 2. LOGIC: ADD NEW ADMIN (Using Secondary App Trick)
  // ==========================================================================
  Future<void> _addAdmin() async {
    if (_adminNameCtrl.text.trim().isEmpty ||
        _adminEmailCtrl.text.trim().isEmpty ||
        _adminPasswordCtrl.text.trim().isEmpty ||
        _selectedSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All fields and a selected school are required"),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Create secondary app to prevent logging out the Super Admin
      FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'tempRegister',
        options: Firebase.app().options,
      );
      await FirebaseAuth.instanceFor(
        app: tempApp,
      ).createUserWithEmailAndPassword(
        email: _adminEmailCtrl.text.trim(),
        password: _adminPasswordCtrl.text.trim(),
      );
      await tempApp.delete();

      // Save Admin Profile
      await _db
          .collection('users')
          .doc(_adminEmailCtrl.text.trim().toLowerCase())
          .set({
            'name': _adminNameCtrl.text.trim(),
            'email': _adminEmailCtrl.text.trim().toLowerCase(),
            'role': 'admin',
            'school_id': _selectedSchoolId,
            'created_at': FieldValue.serverTimestamp(),
          });

      _adminNameCtrl.clear();
      _adminEmailCtrl.clear();
      _adminPasswordCtrl.clear();
      setState(() => _selectedSchoolId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Admin account created successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Authentication Error"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  // ==========================================================================
  // 3. UI: MANAGE SCHOOLS TAB
  // ==========================================================================
  Widget _buildManageSchools() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Register New School",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _schoolNameCtrl,
                      decoration: const InputDecoration(
                        labelText: "School Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TextField(
                      controller: _schoolAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: "Location / Address",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _addSchool,
                      icon: const Icon(Icons.business),
                      label: const Text("Add School"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Registered Schools",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('schools')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty)
                  return const Center(
                    child: Text("No schools registered yet."),
                  );

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var schoolDoc = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        schoolDoc.data() as Map<String, dynamic>;

                    // CRASH PROOFING
                    String sName =
                        (data.containsKey('name') &&
                            data['name'] != null &&
                            data['name'].toString().trim().isNotEmpty)
                        ? data['name'].toString()
                        : 'Unnamed School';
                    String sAddress =
                        (data.containsKey('address') &&
                            data['address'] != null &&
                            data['address'].toString().trim().isNotEmpty)
                        ? data['address'].toString()
                        : 'No Address Provided';
                    String sStatus =
                        (data.containsKey('status') && data['status'] != null)
                        ? data['status'].toString()
                        : 'pending';

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.school, color: Colors.white),
                        ),
                        title: Row(
                          children: [
                            Text(
                              sName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Small badge to show if it's approved or pending
                            if (sStatus == 'approved')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  "Active",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          "ID: ${schoolDoc.id} \nLocation: $sAddress",
                        ),

                        // --- 🟢 RED AND GREEN ACTION BUTTONS HERE 🔴 ---
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sStatus !=
                                'approved') // Only show approve if it's not already approved
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 32,
                                ),
                                tooltip: "Approve School",
                                onPressed: () async {
                                  await _db
                                      .collection('schools')
                                      .doc(schoolDoc.id)
                                      .update({'status': 'approved'});

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("$sName Approved!"),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                              ),

                            IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 32,
                              ),
                              tooltip: "Reject/Delete School",
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Delete School?"),
                                    content: Text(
                                      "Are you sure you want to permanently delete $sName?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          Navigator.pop(
                                            context,
                                          ); // Close dialog

                                          await _db
                                              .collection('schools')
                                              .doc(schoolDoc.id)
                                              .delete();

                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text("School Deleted"),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );
                              },
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

  // ==========================================================================
  // 4. UI: MANAGE ADMINS TAB
  // ==========================================================================
  Widget _buildManageAdmins() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Create School Admin",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _adminNameCtrl,
                          decoration: const InputDecoration(
                            labelText: "Admin Name",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _adminEmailCtrl,
                          decoration: const InputDecoration(
                            labelText: "Email Address",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: TextField(
                          controller: _adminPasswordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Temporary Password",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _db.collection('schools').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData)
                              return const CircularProgressIndicator();

                            List<DropdownMenuItem<String>>
                            schoolItems = snapshot.data!.docs.map((doc) {
                              Map<String, dynamic> data =
                                  doc.data() as Map<String, dynamic>;

                              // CRASH PROOFING
                              String sName =
                                  (data.containsKey('name') &&
                                      data['name'] != null &&
                                      data['name'].toString().trim().isNotEmpty)
                                  ? data['name'].toString()
                                  : 'Unnamed School (${doc.id.substring(0, 5)})';

                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(
                                  sName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList();

                            // Validate selectedSchoolId exists in current list
                            bool isValidSelection = schoolItems.any(
                              (item) => item.value == _selectedSchoolId,
                            );
                            if (!isValidSelection) _selectedSchoolId = null;

                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: "Assign to School",
                                border: OutlineInputBorder(),
                              ),
                              isExpanded: true,
                              items: schoolItems,
                              value: _selectedSchoolId,
                              onChanged: (val) =>
                                  setState(() => _selectedSchoolId = val),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      SizedBox(
                        height: 55,
                        width: 200,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _addAdmin,
                          icon: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Icon(Icons.person_add),
                          label: Text(
                            _isLoading ? "Creating..." : "Create Admin",
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Active Admins",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users')
                  .where('role', isEqualTo: 'admin')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty)
                  return const Center(child: Text("No admins created yet."));

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var adminDoc = snapshot.data!.docs[index];
                    Map<String, dynamic> data =
                        adminDoc.data() as Map<String, dynamic>;

                    // CRASH PROOFING
                    String aName =
                        (data.containsKey('name') && data['name'] != null)
                        ? data['name'].toString()
                        : 'Unknown Admin';
                    String aEmail =
                        (data.containsKey('email') && data['email'] != null)
                        ? data['email'].toString()
                        : 'No Email';
                    String aSchoolId =
                        (data.containsKey('school_id') &&
                            data['school_id'] != null)
                        ? data['school_id'].toString()
                        : 'Unassigned';

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          aName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Email: $aEmail \nAssigned School ID: $aSchoolId",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Child Safe - Master Portal",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
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
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.blueGrey.shade50,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(
              color: Colors.indigo,
              size: 30,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.indigo,
              fontWeight: FontWeight.bold,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.business),
                label: Text('Schools'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.security),
                label: Text('Admins'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Container(
              color: Colors.grey.shade100,
              child: _selectedIndex == 0
                  ? _buildManageSchools()
                  : _buildManageAdmins(),
            ),
          ),
        ],
      ),
    );
  }
}

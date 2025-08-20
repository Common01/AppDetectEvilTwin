// import 'package:flutter/material.dart';
// import 'package:wifi_app/page/admin.dart';
// import 'package:wifi_app/page/login.dart';
// import 'package:wifi_app/page/register.dart';
// import 'package:wifi_app/page/scanwifi.dart';

// class LinkPage extends StatefulWidget {
//   const LinkPage({super.key});

//   @override
//   State<LinkPage> createState() => _LinkPageState();
// }

// class _LinkPageState extends State<LinkPage> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("LinkPage"),
//     ),
//     body: Column(children: [
//       TextButton(
//         onPressed: login, 
//         child: const Text("LoginPage"),
//         ),
//         TextButton(
//         onPressed: scan, 
//         child: const Text("ScanPage"),
//         ),
//         TextButton(
//         onPressed: admin, 
//         child: const Text("AdminPage"),
//         ),
//         TextButton(
//         onPressed: register, 
//         child: const Text("RegisterPage"),
//         ),
//     ],),
//     );
//   }
  
//   void login() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const LoginPage(),
//       ),
//     );
//   }
//   void register() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const RegisterPage(),
//       ),
//     );
//   }
//   void scan() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const ScanPage(),
//       ),
//     );
//   }
//   void admin() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const AdminPage(),
//       ),
//     );
//   }
  
// }
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/views/admin/create_mess.dart';
import 'package:mess_management/views/member/join.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/models/user_model.dart';
import 'package:mess_management/views/admin/admin_home.dart';
import 'package:mess_management/views/manager/manager_home.dart';
import 'package:mess_management/views/member/user_home.dart';

class Landpage extends StatefulWidget {
  const Landpage({super.key});

  @override
  State<Landpage> createState() => _LandpageState();
}

class _LandpageState extends State<Landpage> {
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _checkUserMessStatus();
  }

  void _checkUserMessStatus() async {
    String? uid = _auth.currentUid;
    if (uid != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        UserModel user = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
        if (user.messId != null && user.messId!.isNotEmpty) {
          if (!mounted) return;
          Widget homePage;
          switch (user.role) {
            case UserRole.superAdmin:
              homePage = const AdminHome();
              break;
            case UserRole.manager:
              homePage = const ManagerHome();
              break;
            default:
              homePage = const UserHome();
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => homePage),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "Welcome to Meal Assistant",
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/landpage.jpeg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton("Create new meal +", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMess()))),
              const SizedBox(height: 30),
              _buildButton("Join in a meal   +", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Join()))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 200,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[400],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 10,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

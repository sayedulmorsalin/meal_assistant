import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meal_assistant/views/admin/create_mess.dart';
import 'package:meal_assistant/views/member/join.dart';
import 'package:meal_assistant/services/auth_service.dart';
import 'package:meal_assistant/models/user_model.dart';
import 'package:meal_assistant/views/manager/manager_home.dart';
import 'package:meal_assistant/views/member/user_home.dart';

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
          if (user.role == UserRole.superAdmin) {
            // SuperAdmin: navigate based on participationRole
            homePage = user.participationRole == UserRole.manager
                ? const ManagerHome()
                : const UserHome();
          } else {
            switch (user.role) {
              case UserRole.manager:
                homePage = const ManagerHome();
                break;
              default:
                homePage = const UserHome();
            }
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
        title: const Text("Welcome to Meal Assistant"),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildButton(context, "Create new meal +", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateMess()))),
              const SizedBox(height: 30),
              _buildButton(context, "Join in a meal   +", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const Join()))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, String text, VoidCallback onPressed) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
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

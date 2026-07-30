import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/views/landing/landpage.dart';
import 'package:mess_management/views/auth/login.dart';
import 'package:mess_management/models/user_model.dart';
import 'package:mess_management/views/admin/admin_home.dart';
import 'package:mess_management/views/manager/manager_home.dart';
import 'package:mess_management/views/member/user_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mess Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                UserModel user = UserModel.fromMap(userSnapshot.data!.data() as Map<String, dynamic>);
                
                if (user.messId == null || user.messId!.isEmpty) {
                  return const Landpage();
                }
                
                switch (user.role) {
                  case UserRole.superAdmin:
                    return const AdminHome();
                  case UserRole.manager:
                    return const ManagerHome();
                  case UserRole.member:
                    return const UserHome();
                }
              }
              // If user document doesn't exist, we might be in the middle of registration
              return const Landpage();
            },
          );
        }
        
        return const Login();
      },
    );
  }
}

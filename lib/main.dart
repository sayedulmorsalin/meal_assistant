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
import 'package:provider/provider.dart';
import 'package:mess_management/core/theme_provider.dart';
import 'package:mess_management/core/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mess Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primary,
          titleTextStyle: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: const UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide.none,
          ),
          enabledBorder: UnderlineInputBorder(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: const UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
          labelStyle: const TextStyle(fontSize: 16),
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.6)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: const UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide.none,
          ),
          enabledBorder: UnderlineInputBorder(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: const UnderlineInputBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            borderSide: BorderSide(color: AppColors.error, width: 2),
          ),
          labelStyle: const TextStyle(fontSize: 16),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      ),
      themeMode: themeProvider.themeMode,
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
              
              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: AppColors.error),
                        const SizedBox(height: 16),
                        const Text("Error loading user profile"),
                        TextButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text("Sign Out"),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                UserModel user = UserModel.fromMap(userSnapshot.data!.data() as Map<String, dynamic>);
                
                if (user.messId == null || user.messId!.isEmpty) {
                  return const Landpage();
                }
                
                if (user.role == UserRole.superAdmin) {
                  // Super Admin follows their participation role for Home
                  if (user.participationRole == UserRole.manager) {
                    return const ManagerHome();
                  } else {
                    return const UserHome();
                  }
                }
                
                switch (user.role) {
                  case UserRole.superAdmin:
                    return const AdminHome(); // Fallback, though handled above
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

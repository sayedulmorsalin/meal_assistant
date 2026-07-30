import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get current user uid
  String? get currentUid => _auth.currentUser?.uid;

  // Sign Up
  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // Create user document in Firestore
        UserModel newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          role: UserRole.member,
          status: 'active',
        );
        await _db.collection('users').doc(user.uid).set(newUser.toMap());
      }
      return result;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Login
  Future<UserCredential?> login(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

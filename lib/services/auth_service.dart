import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mess_management/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get current user uid
  String? get currentUid => _auth.currentUser?.uid;

  // Sign Up
  Future<String?> signUp(String email, String password, String name) async {
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
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message ?? "An unknown error occurred during sign up.";
    } catch (e) {
      return e.toString();
    }
  }

  // Login
  Future<String?> login(String email, String password) async {
    try {
      print("AuthService: Attempting login for $email");
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      print("AuthService: Login success for $email");
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print("AuthService: FirebaseAuthException during login: ${e.code} - ${e.message}");
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'The email address is badly formatted.';
        case 'user-disabled':
          return 'This user has been disabled.';
        case 'invalid-credential':
          return 'Invalid email or password.';
        default:
          return e.message ?? "An error occurred during login.";
      }
    } catch (e) {
      print("AuthService: Unknown error during login: $e");
      return e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Delete Account
  Future<String?> deleteAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        String uid = user.uid;
        DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
        if (doc.exists) {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
          String? messId = data?['messId'];
          if (messId != null && messId.isNotEmpty) {
            var messDoc = await _db.collection('messes').doc(messId).get();
            if (messDoc.exists && messDoc.data()?['managerId'] == uid) {
              await _db.collection('messes').doc(messId).update({'managerId': null});
            }
          }
          await _db.collection('users').doc(uid).delete();
        }
        await user.delete();
        return null;
      }
      return "No user currently logged in.";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return "For security reasons, please log out and log back in before deleting your account.";
      }
      return e.message ?? "Failed to delete account.";
    } catch (e) {
      return e.toString();
    }
  }
}

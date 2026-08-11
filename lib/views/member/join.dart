import 'package:flutter/material.dart';
import 'package:mess_management/views/member/user_home.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Join extends StatefulWidget {
  const Join({super.key});

  @override
  State<Join> createState() => _JoinState();
}

class _JoinState extends State<Join> {
  final TextEditingController _joinKeyController = TextEditingController();
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  void _handleJoin() async {
    if (_joinKeyController.text.isEmpty) return;

    setState(() => _isLoading = true);
    String? uid = _auth.currentUid;
    if (uid != null) {
      // Get user name for the request
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String userName = userDoc.data()?['name'] ?? 'Unknown User';

      String? error = await _db.sendJoinRequest(uid, userName, _joinKeyController.text.trim());
      
      if (!mounted) return;
      if (error == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Request Sent"),
            content: const Text("Your request to join has been sent to the Super Admin. Please wait for approval."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Back to landing page
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Join Meal System"),
      ),
      body: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              TextField(
                controller: _joinKeyController,
                decoration: const InputDecoration(
                  labelText: "Join Key",
                  hintText: "Enter 6-digit key",
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
              const SizedBox(height: 50.0),
              Center(
                child: _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _handleJoin,
                  child: const Text(
                    "Send Request",
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

}

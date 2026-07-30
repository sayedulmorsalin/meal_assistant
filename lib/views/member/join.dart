import 'package:flutter/material.dart';
import 'package:mess_management/views/member/user_home.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';

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
      bool success = await _db.joinMess(_joinKeyController.text.trim(), uid);
      
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Successfully joined the mess!")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHome()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to join. Invalid key.")),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text(
          "Join Meal System",
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/join meal.jpeg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100,),
              const Text("  Join key",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 25.0,
                    fontWeight: FontWeight.bold
                ),),
              Container(
                padding: const EdgeInsets.only(left: 20.0),
                decoration: getTextFieldDecoration(),
                child: TextField(
                  controller: _joinKeyController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter 6-digit key",
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 50.0),
              Center(
                child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : ElevatedButton(
                    onPressed: _handleJoin,
                    child: Text("Join",
                      style: TextStyle(
                          color: Colors.purple[700],
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold),)
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration getTextFieldDecoration() {
    return BoxDecoration(
      color: Colors.black45,
      border: Border.all(
        width: 6,
        color: Colors.white,
      ),
      borderRadius: BorderRadius.circular(30),
    );
  }
}

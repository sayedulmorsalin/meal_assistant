import 'package:flutter/material.dart';
import 'package:mess_management/views/admin/admin_home.dart';
import 'package:mess_management/services/auth_service.dart';
import 'package:mess_management/services/database_service.dart';

class CreateMess extends StatefulWidget {
  const CreateMess({super.key});

  @override
  State<CreateMess> createState() => _CreateMessState();
}

class _CreateMessState extends State<CreateMess> {
  final TextEditingController _messNameController = TextEditingController();
  final AuthService _auth = AuthService();
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  void _handleCreate() async {
    if (_messNameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    String? uid = _auth.currentUid;
    if (uid != null) {
      String joinKey = await _db.createMess(_messNameController.text, uid);
      
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Mess Created Successfully!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Share this key with your members:"),
              const SizedBox(height: 10),
              SelectableText(
                joinKey,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminHome()),
                );
              },
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text(
          "Create New Meal System",
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
            image: AssetImage("assets/images/create meal.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),
              const Text(
                "  Meal Name",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.only(left: 20.0),
                decoration: getTextFieldDecoration(),
                child: TextField(
                  controller: _messNameController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter Mess Name",
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
                  onPressed: _handleCreate,
                  child: const Text(
                    "Create",
                    style: TextStyle(
                      color: Colors.black,
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

  BoxDecoration getTextFieldDecoration() {
    return BoxDecoration(
      color: Colors.black45,
      border: Border.all(
        width: 4,
        color: Colors.white,
      ),
      borderRadius: BorderRadius.circular(30),
    );
  }
}

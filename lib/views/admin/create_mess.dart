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
        title: const Text("Create New Meal System"),
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
                controller: _messNameController,
                decoration: const InputDecoration(
                  labelText: "Meal Name",
                  hintText: "Enter Mess Name",
                  prefixIcon: Icon(Icons.restaurant_menu),
                ),
              ),
              const SizedBox(height: 50.0),
              Center(
                child: _isLoading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                  onPressed: _handleCreate,
                  child: const Text(
                    "Create",
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

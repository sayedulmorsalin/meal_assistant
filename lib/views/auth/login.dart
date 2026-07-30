import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register.dart';
import '../member/user_home.dart';
import '../manager/manager_home.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);
    var result = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Failed. Please check your credentials.")),
      );
    }
    // AuthWrapper in main.dart will handle navigation automatically
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[100],
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Login Form",
              style: TextStyle(
                  color: Colors.blue,
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold),),
          ],),),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/login.jpeg"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 100,),
                const Text("  Email",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 25.0,
                      fontWeight: FontWeight.bold
                  ),),
                Container(
                  padding: const EdgeInsets.only(left: 20.0),
                  decoration: getTextFieldDecoration(),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter your email",
                    ),
                  ),
                ),
                const SizedBox(height: 30.0,),
                const Text("  Password",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 25.0,
                      fontWeight: FontWeight.bold
                  ),),
                Container(
                  padding: const EdgeInsets.only(left: 20.0),
                  decoration: getTextFieldDecoration(),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter your password",
                    ),
                  ),
                ),
                const SizedBox(height: 30.0),
                Center(
                  child: Column(
                    children: [
                      _isLoading 
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            ),
                            child: const Text("Submit",
                              style: TextStyle(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold),)
                        ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const Register()),
                          );
                        },
                        child: const Text("Don't have an account? Register",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration getTextFieldDecoration() {
    return BoxDecoration(
      color: Colors.white70,
      border: Border.all(
        width: 4,
        color: Colors.orange,
      ),
      borderRadius: BorderRadius.circular(30),
    );
  }
}

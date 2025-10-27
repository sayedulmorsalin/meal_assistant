import 'package:flutter/material.dart';
import 'package:mess_management/admin/admin_home.dart';

class CreateMess extends StatefulWidget {
  const CreateMess({super.key});

  @override
  State<CreateMess> createState() => _CreateMessState();
}

class _CreateMessState extends State<CreateMess> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(
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
            colorFilter: ColorFilter.matrix([
              1, 0, 0, 0, 0,
              0, 1, 0, 0, 0,
              0, 0, 1, 0, 0,
              0, 0, 0, 1, 0,
            ]),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 100),

            // Meal Name TextField (Shortened)
            Text(
              "  Create a join key",
              style: TextStyle(
                color: Colors.white,
                fontSize: 25.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              //width: 200.0, // Reduced width
              child: Container(
                padding: EdgeInsets.only(left: 20.0),
                decoration: getTextFieldDecoration(),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 12.0),
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w300, // Lighter text
                      fontSize: 12, // Smaller text
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 30.0),

            // Join Key TextField (Shortened)
            Text(
              "  Meal Name",
              style: TextStyle(
                color: Colors.white,
                fontSize: 25.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              //width: 200.0, // Reduced width
              child: Container(
                padding: EdgeInsets.only(left: 20.0),
                decoration: getTextFieldDecoration(),
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 12.0),
                      isDense: true,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w300, // Lighter text
                      fontSize: 12, // Smaller text
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 30.0),

            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 30.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminHome()),
                    );
                  },
                  child: Text(
                    "Create",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  BoxDecoration getTextFieldDecoration() {
    return BoxDecoration(
      color: Colors.transparent,
      border: Border.all(
        width: 4,
        color: Colors.white,
      ),
      borderRadius: BorderRadius.circular(30),
    );
  }
}
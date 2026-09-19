
import 'package:flutter/material.dart';

void main() {
runApp(const UICTApp());
}

class UICTApp extends StatelessWidget {
const UICTApp({super.key});

@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'UICT Login',
theme: ThemeData(
primarySwatch: Colors.blue,
),
home: const LoginPage(),
);
}
}

class LoginPage extends StatefulWidget {
const LoginPage({super.key});

@override
State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
final TextEditingController registrationController =
TextEditingController();

final TextEditingController passwordController =
TextEditingController();

bool hidePassword = true;

void login() {
String registration = registrationController.text.trim();
String password = passwordController.text;

// ERROR MESSAGE
if (registration.isEmpty || password.isEmpty) {
showMessage(
title: 'Login Error',
message: 'Please enter your registration number and password.',
icon: Icons.error_outline,
iconColor: Colors.red,
);
return;
}

// DEMO LOGIN
if (registration == 'UICT/2025/DSWE/DAY/2246' &&
password == 'password123') {

// SUCCESS MESSAGE
showMessage(
title: 'Login Successful',
message: 'Welcome to KAMCODER. You have logged in successfully.',
icon: Icons.check_circle_outline,
iconColor: Colors.green,
);
} else {

// WRONG LOGIN
showMessage(
title: 'Login Failed',
message: 'Invalid registration number or password.',
icon: Icons.cancel_outlined,
iconColor: Colors.red,
);
}
}

// ============================================================
// CENTER MESSAGE
// ============================================================

void showMessage({
required String title,
required String message,
required IconData icon,
required Color iconColor,
}) {
showDialog(
context: context,
barrierDismissible: true,

builder: (BuildContext context) {
return Dialog(
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(20),
),

child: Container(
width: 400,
padding: const EdgeInsets.all(30),

child: Column(
mainAxisSize: MainAxisSize.min,

children: [

// ICON
Icon(
icon,
color: iconColor,
size: 65,
),

const SizedBox(height: 20),

// TITLE
Text(
title,
textAlign: TextAlign.center,

style: TextStyle(
fontSize: 23,
fontWeight: FontWeight.bold,
color: iconColor,
),
),

const SizedBox(height: 12),

// MESSAGE
Text(
message,
textAlign: TextAlign.center,

style: const TextStyle(
fontSize: 15,
color: Colors.black87,
height: 1.5,
),
),

const SizedBox(height: 25),

// OK BUTTON
SizedBox(
width: double.infinity,
height: 48,

child: ElevatedButton(
onPressed: () {
Navigator.of(context).pop();
},

style: ElevatedButton.styleFrom(
backgroundColor: iconColor,
foregroundColor: Colors.white,

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
),

child: const Text(
'OK',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
),
);
},
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.blue.shade50,

body: Center(
child: SingleChildScrollView(
padding: const EdgeInsets.all(20),

child: Container(
width: 400,
padding: const EdgeInsets.all(30),

decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(20),

boxShadow: [
BoxShadow(
color: Colors.black.withOpacity(0.1),
blurRadius: 15,
offset: const Offset(0, 5),
),
],
),

child: Column(
crossAxisAlignment: CrossAxisAlignment.stretch,

children: [

// UICT
const Text(
'UICT',
textAlign: TextAlign.center,

style: TextStyle(
fontSize: 35,
fontWeight: FontWeight.bold,
color: Colors.blue,
),
),

const SizedBox(height: 10),

// WELCOME
const Text(
'Welcome to KAMCODER',
textAlign: TextAlign.center,

style: TextStyle(
fontSize: 25,
fontWeight: FontWeight.bold,
color: Colors.black87,
),
),

const SizedBox(height: 8),

const Text(
'Please login to continue',
textAlign: TextAlign.center,

style: TextStyle(
fontSize: 15,
color: Colors.grey,
),
),

const SizedBox(height: 35),

// REGISTRATION NUMBER
const Text(
'Registration Number',

style: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 15,
),
),

const SizedBox(height: 8),

TextField(
controller: registrationController,

decoration: InputDecoration(
hintText: 'Enter registration number',

prefixIcon: const Icon(
Icons.person,
color: Colors.blue,
),

border: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
),

focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),

borderSide: const BorderSide(
color: Colors.blue,
width: 2,
),
),
),
),

const SizedBox(height: 20),

// PASSWORD
const Text(
'Password',

style: TextStyle(
fontWeight: FontWeight.bold,
fontSize: 15,
),
),

const SizedBox(height: 8),

TextField(
controller: passwordController,

obscureText: hidePassword,

decoration: InputDecoration(
hintText: 'Enter password',

prefixIcon: const Icon(
Icons.lock,
color: Colors.blue,
),

suffixIcon: IconButton(
icon: Icon(
hidePassword
? Icons.visibility
    : Icons.visibility_off,

color: Colors.blue,
),

onPressed: () {
setState(() {
hidePassword = !hidePassword;
});
},
),

border: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
),

focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),

borderSide: const BorderSide(
color: Colors.blue,
width: 2,
),
),
),
),

const SizedBox(height: 30),

// LOGIN BUTTON
SizedBox(
height: 50,

child: ElevatedButton(
onPressed: login,

style: ElevatedButton.styleFrom(
backgroundColor: Colors.blue,
foregroundColor: Colors.white,

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10),
),
),

child: const Text(
'LOGIN',

style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
),
),
),
);
}
}
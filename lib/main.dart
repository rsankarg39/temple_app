import 'package:flutter/material.dart';
import 'screens/admin_dashboard.dart';
import 'screens/committee_dashboard.dart';
import 'screens/user_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Removed: import 'screens/login_screen.dart';  <-- not needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://rftkomfjwswquxbhxbdc.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJmdGtvbWZqd3N3cXV4Ymh4YmRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNjgxOTEsImV4cCI6MjA5MTc0NDE5MX0._JajTp474vS4FP2hPPHk7RayPAObL7QtjWzvD4gqnbo', // keep your actual anon key here
  );
  runApp(const TempleApp());
}

class TempleApp extends StatelessWidget {
  const TempleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Temple App',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: LoginScreen(), // ✅ no const
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); // ✅ no const

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();

  void _login() {
    final pin = _pinController.text;

    Widget nextScreen;

    if (pin == "1111") {
      nextScreen = AdminDashboard(); // ✅ no const
    } else if (pin == "2222") {
      nextScreen = CommitteeDashboard(); // ✅ no const
    } else {
      nextScreen = UserDashboard(); // ✅ no const
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Temple App Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Enter PIN to Login"),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "PIN"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}
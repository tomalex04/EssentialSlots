import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Give the auth provider time to check for stored session
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      if (authProvider.loggedInUser != null) {
        // User is logged in, navigate to appropriate home screen
        if (authProvider.userRole == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin-home');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        // No valid session, go to login screen
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 200,
              width: 200,
              child: Image.asset(
                'assets/images/SBICON.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Essential Slots',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lab Management System',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

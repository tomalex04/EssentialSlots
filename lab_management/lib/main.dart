import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/screens/login_screen.dart';
import 'package:lab_management/screens/admin_home_screen.dart';
import 'package:lab_management/screens/home_screen.dart';
import 'package:lab_management/screens/register_screen.dart';
import 'package:lab_management/providers/auth_provider.dart';
import 'package:lab_management/providers/auth_guard.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lab Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
      routes: {
        '/admin-home': (context) => AuthGuard(
          requiresAdmin: true,
          child: const AdminHomeScreen(),
        ),
        '/home': (context) => AuthGuard(
          child: const HomeScreen(),
        ),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}
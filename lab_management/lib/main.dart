import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/screens/login_screen.dart';
import 'package:lab_management/screens/admin_home_screen.dart';
import 'package:lab_management/screens/home_screen.dart';
import 'package:lab_management/screens/register_screen.dart';
import 'package:lab_management/screens/requests_screen.dart';
import 'package:lab_management/providers/auth_provider.dart';
import 'package:lab_management/providers/auth_guard.dart';
import 'package:lab_management/providers/settings_provider.dart';
import 'package:lab_management/widgets/scalable_app.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScalableApp(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Essential Slots',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white, // Set AppBar background color to white
            iconTheme: IconThemeData(color: Colors.black), // Set AppBar icons color to black
            titleTextStyle: TextStyle(color: Colors.black, fontSize: 20), // Set AppBar title color to black
          ),
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
          '/requests': (context) => AuthGuard(
            requiresAdmin: true,
            child: const RequestsScreen(),
          ),
        },
      ),
    );
  }
}
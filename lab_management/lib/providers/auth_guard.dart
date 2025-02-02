import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/auth_provider.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  final bool requiresAdmin;

  const AuthGuard({
    required this.child,
    this.requiresAdmin = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.loggedInUser == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/');
          });
          return const CircularProgressIndicator();
        }

        if (requiresAdmin && auth.userRole != 'admin') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, '/');
          });
          return const CircularProgressIndicator();
        }

        return child;
      },
    );
  }
}
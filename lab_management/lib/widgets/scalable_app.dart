import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/settings_provider.dart';

class ScalableApp extends StatelessWidget {
  final Widget child;

  const ScalableApp({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(settingsProvider.fontSize / 14.0),
      ),
      child: child,
    );
  }
}

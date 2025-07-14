import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lab_management/providers/settings_provider.dart';

class AppSettingsControls extends StatelessWidget {
  const AppSettingsControls({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Font Size Controls
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Font Size',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text('8'),
              Expanded(
                child: Slider(
                  value: settingsProvider.fontSize,
                  min: 8.0,
                  max: 24.0,
                  divisions: 16,
                  label: settingsProvider.fontSize.toStringAsFixed(1),
                  onChanged: (value) {
                    settingsProvider.setFontSize(value);
                  },
                ),
              ),
              const Text('24'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child:
              Text('Current: ${settingsProvider.fontSize.toStringAsFixed(1)}'),
        ),

        const SizedBox(height: 16),

        // Reset Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton(
            onPressed: () {
              settingsProvider.resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to defaults'),
                  duration: Duration(milliseconds: 500),
                ),
              );
            },
            child: const Text('Reset to Defaults'),
          ),
        ),
      ],
    );
  }
}

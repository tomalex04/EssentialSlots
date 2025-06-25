import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // Default values
  double _fontSize = 14.0;  // Default font size
  
  // Getters
  double get fontSize => _fontSize;
  
  // Initialize the provider by loading saved preferences
  Future<void> init() async {
    await loadPreferences();
  }
  
  // Load saved preferences from SharedPreferences
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load font size (default to 14.0 if not set)
    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    
    notifyListeners();
  }
  
  // Set font size and save to SharedPreferences
  Future<void> setFontSize(double size) async {
    if (size != _fontSize) {
      _fontSize = size;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('fontSize', _fontSize);
      notifyListeners();
    }
  }
  
  // Reset settings to defaults
  Future<void> resetToDefaults() async {
    _fontSize = 14.0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fontSize');
    
    notifyListeners();
  }
}

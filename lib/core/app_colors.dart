import 'package:flutter/material.dart';

class AppColors {
  // Primary brand color
  static const Color primary = Colors.blue;
  
  // Semantic colors
  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.purple;

  // Background/Surface related (Mostly for custom widgets)
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color darkBackground = Color(0xFF121212);
  
  // Utility for obtaining shades (like blue[100]) via theme
  static Color getPrimaryLight(BuildContext context) => 
      Theme.of(context).colorScheme.primaryContainer;
      
  static Color getSurface(BuildContext context) => 
      Theme.of(context).colorScheme.surface;
}

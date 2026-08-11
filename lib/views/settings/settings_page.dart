import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light Mode'),
            secondary: const Icon(Icons.light_mode),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) themeProvider.setThemeMode(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) themeProvider.setThemeMode(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            secondary: const Icon(Icons.settings_suggest),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (ThemeMode? value) {
              if (value != null) themeProvider.setThemeMode(value);
            },
          ),
          Divider(),
          // Add more settings here if needed
        ],
      ),
    );
  }
}

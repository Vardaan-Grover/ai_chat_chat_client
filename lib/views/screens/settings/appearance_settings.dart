// lib/pages/settings/appearance_settings.dart
import 'package:ai_chat_chat_client/services/theme/color_value_extension.dart';
import 'package:ai_chat_chat_client/viewmodels/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    theme.colorScheme.primary;
    final themeController = ref.watch(themeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tooh Chutiya Hai',
          style: TextStyle(color: theme.colorScheme.primary),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Theme Mode'),
            subtitle: Text(themeController.themeMode.name),
            onTap: () => _showThemeModeDialog(context, themeController),
          ),
          ListTile(
            title: const Text('Primary Color'),
            trailing: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color:
                    themeController.primaryColor ??
                    Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey),
              ),
            ),
            onTap: () => _showColorPickerDialog(context, themeController),
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(
    BuildContext context,
    ThemeController themeController,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Theme Mode'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('System'),
                  selected: themeController.themeMode == ThemeMode.system,
                  onTap: () {
                    themeController.setThemeMode(ThemeMode.system);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Light'),
                  selected: themeController.themeMode == ThemeMode.light,
                  onTap: () {
                    themeController.setThemeMode(ThemeMode.light);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: const Text('Dark'),
                  selected: themeController.themeMode == ThemeMode.dark,
                  onTap: () {
                    themeController.setThemeMode(ThemeMode.dark);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showColorPickerDialog(
    BuildContext context,
    ThemeController themeController,
  ) {
    // Here you would typically show a color picker
    // For simplicity, we'll just cycle through some predefined colors
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.orange,
      Colors.pink,
      null, // null means use system default
    ];

    final currentColor = themeController.primaryColor;
    final currentIndex =
        currentColor == null
            ? colors.length - 1
            : colors.indexWhere((c) => c?.hexValue == currentColor.hexValue);

    final nextIndex = (currentIndex + 1) % colors.length;
    themeController.setPrimaryColor(colors[nextIndex]);
  }
}

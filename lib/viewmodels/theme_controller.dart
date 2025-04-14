import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../services/theme/theme_providers.dart';

/// Controller for theme-related operations
///
/// This controller provides a clean API for UI components to interact with
/// the theme system. It abstracts away the details of state management and
/// provides simple methods for getting and setting theme preferences.
class ThemeController {
  final Logger logger = Logger('ThemeController');
  final Ref _ref;

  /// Creates a ThemeController with the provided Riverpod reference
  ThemeController(this._ref);

  /// Get the current theme mode (light, dark, or system)
  ThemeMode get themeMode => _ref.read(themeModeProvider);

  /// Get the current primary color, or null if using the system default
  Color? get primaryColor => _ref.read(primaryColorProvider);

  /// Set the theme mode
  ///
  /// Changes the app's theme mode and persists the preference.
  ///
  /// @param newThemeMode The theme mode to apply
  /// @throws Exception if the theme mode couldn't be set
  Future<void> setThemeMode(ThemeMode newThemeMode) async {
    try {
      await _ref.read(themeStateProvider.notifier).setThemeMode(newThemeMode);
    } catch (e) {
      logger.severe('Error setting theme mode: $e');
      rethrow; // Allow UI to handle or display error
    }
  }

  /// Set the primary color
  ///
  /// Changes the app's primary color and persists the preference.
  /// Pass null to use the system default color.
  ///
  /// @param newPrimaryColor The color to apply, or null to use system default
  /// @throws Exception if the color couldn't be set
  Future<void> setPrimaryColor(Color? newPrimaryColor) async {
    try {
      await _ref
          .read(themeStateProvider.notifier)
          .setPrimaryColor(newPrimaryColor);
    } catch (e) {
      logger.severe('Error setting primary color: $e');
      rethrow; // Allow UI to handle or display error
    }
  }
}

/// Provider for ThemeController
///
/// Creates and provides a ThemeController instance.
final themeControllerProvider = Provider<ThemeController>((ref) {
  return ThemeController(ref);
});

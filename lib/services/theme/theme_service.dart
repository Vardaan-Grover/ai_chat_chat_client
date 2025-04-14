import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './color_value_extension.dart';
import '../../models/theme/theme_state.dart';

/// Handles the persistence of theme preferences.
///
/// This service is responsible for loading and saving theme preferences
/// from/to the device storage using SharedPreferences. It persists:
/// - Theme mode (light, dark, system)
/// - Primary color
class ThemeService {
  final Logger logger = Logger("ThemeService");

  final SharedPreferences _store;
  final String themeModeKey;
  final String primaryColorKey;

  /// Creates a new ThemeService instance.
  ///
  /// @param store The SharedPreferences instance used for persistence
  /// @param themeModeKey The key used to store the theme mode preference (defaults to 'theme_mode')
  /// @param primaryColorKey The key used to store the primary color preference (defaults to 'primary_color')
  ThemeService({
    required SharedPreferences store,
    this.themeModeKey = 'theme_mode',
    this.primaryColorKey = 'primary_color',
  }) : _store = store;

  /// Loads the theme state from the SharedPreferences instance.
  ///
  /// Retrieves saved theme preferences and converts them to proper types.
  /// If preferences are not found, defaults are provided:
  /// - ThemeMode.system for theme mode
  /// - null for primary color (to use system default)
  ///
  /// @return A [ThemeState] object containing the loaded preferences
  Future<ThemeState> loadThemeState() async {
    try {
      final rawThemeMode = _store.getString(themeModeKey);
      final rawColor = _store.getInt(primaryColorKey);

      // Convert raw theme mode to ThemeMode enum
      final themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == rawThemeMode,
        orElse: () => ThemeMode.system,
      );

      // Convert raw color to Color object
      final primaryColor = rawColor != null ? Color(rawColor) : null;

      return ThemeState(themeMode: themeMode, primaryColor: primaryColor);
    } catch (e) {
      // If there's any error loading theme preferences, return defaults
      logger.severe('Error loading theme state: $e');
      return const ThemeState(themeMode: ThemeMode.system);
    }
  }

  /// Saves the theme mode to the SharedPreferences instance.
  ///
  /// @param themeMode The ThemeMode to save
  /// @throws Exception if the preference could not be saved
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    try {
      final success = await _store.setString(themeModeKey, themeMode.name);
      if (!success) {
        throw Exception('Failed to save theme mode');
      }
    } catch (e) {
      logger.severe('Error saving theme mode: $e');
      throw Exception('Could not save theme mode: $e');
    }
  }

  /// Saves the primary color to the SharedPreferences instance.
  /// If color is null, removes the saved preference to use system default.
  ///
  /// @param color The Color to save, or null to clear the preference
  /// @throws Exception if the preference could not be saved or removed
  Future<void> savePrimaryColor(Color? color) async {
    try {
      bool success;
      if (color != null) {
        success = await _store.setInt(primaryColorKey, color.hexValue);
      } else {
        success = await _store.remove(primaryColorKey);
      }

      if (!success) {
        throw Exception('Failed to save primary color');
      }
    } catch (e) {
      logger.severe('Error saving primary color: $e');
      throw Exception('Could not save primary color: $e');
    }
  }
}

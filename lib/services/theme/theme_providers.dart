import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/theme_service.dart';
import '../../models/theme/theme_state.dart';

/// Provider for ThemeService
final themeServiceProvider = Provider<ThemeService>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  return ThemeService(store: preferences);
});

/// StateNotifierProvider for managing theme state
/// 
/// This is the central provider for theme state management.
/// It handles loading and persisting theme preferences.
final themeStateProvider =
    StateNotifierProvider<ThemeStateNotifier, ThemeState>((ref) {
      final themeService = ref.watch(themeServiceProvider);
      return ThemeStateNotifier(themeService);
    });

/// Provider for current ThemeMode
/// 
/// A convenience provider that extracts just the ThemeMode from the theme state.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeStateProvider).themeMode;
});

/// Provider for current primary color
/// 
/// A convenience provider that extracts just the primary color from the theme state.
final primaryColorProvider = Provider<Color?>((ref) {
  return ref.watch(themeStateProvider).primaryColor;
});

/// StateNotifier for managing theme state
/// 
/// Handles theme state changes and persists them via ThemeService.
class ThemeStateNotifier extends StateNotifier<ThemeState> {
  final ThemeService _themeService;

  /// Creates a ThemeStateNotifier with the provided service and initial state.
  ///
  /// @param themeService The service used to persist theme changes
  /// @param initialState The initial theme state loaded from storage
  ThemeStateNotifier(this._themeService)
    : super(const ThemeState(themeMode: ThemeMode.system)) {
    _initTheme();
  }

  /// Initialize theme by loading saved preferences
  Future<void> _initTheme() async {
    final themeState = await _themeService.loadThemeState();
    state = themeState;
  }

  /// Set the theme mode and persist the change
  ///
  /// @param themeMode The new ThemeMode to apply
  /// @throws Exception if the theme mode couldn't be
  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _themeService.saveThemeMode(themeMode);
    state = state.copyWith(themeMode: themeMode);
  }

  /// Set the primary color and persist the change
  ///
  /// @param primaryColor The new primary color, or null to use system default
  /// @throws Exception if the primary color couldn't be saved
  Future<void> setPrimaryColor(Color? primaryColor) async {
    await _themeService.savePrimaryColor(primaryColor);
    state = state.copyWith(
      primaryColor: primaryColor,
      clearPrimaryColor: primaryColor == null,
    );
  }
}

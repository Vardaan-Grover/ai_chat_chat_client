import 'package:flutter/material.dart';

class ThemeState {
  final ThemeMode themeMode;
  final Color? primaryColor;

  const ThemeState({required this.themeMode, this.primaryColor});

  ThemeState copyWith({
    ThemeMode? themeMode,
    Color? primaryColor,
    bool clearPrimaryColor = false,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      primaryColor:
          clearPrimaryColor ? null : primaryColor ?? this.primaryColor,
    );
  }
}
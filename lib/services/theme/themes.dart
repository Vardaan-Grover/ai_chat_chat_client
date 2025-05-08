import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';

/// A utility class that provides theme-related constants, methods and configurations
/// for the AIChatChat application.
abstract class AIChatChatThemes {
  /// The standard width for content columns in the application
  static const double columnWidth = 380.0;

  /// The standard width for the navigation rail component
  static const double navRailWidth = 80.0;

  /// Standard animation duration used throughout the app
  static const Duration animationDuration = Duration(milliseconds: 250);

  /// Standard animation curve used throughout the app
  static const Curve animationCurve = Curves.easeInOut;

  /// Determines if the layout should use column mode based on a given width
  ///
  /// Returns true when the width can accommodate two columns plus the navigation rail
  static bool isColumnModeByWidth(double width) =>
      width > columnWidth * 3 + navRailWidth;

  /// Determines if the current screen size should use column mode
  ///
  /// @param context The BuildContext to get screen dimensions from
  /// @return True if the screen is wide enough for column layout
  static bool isColumnMode(BuildContext context) =>
      isColumnModeByWidth(MediaQuery.of(context).size.width);

  /// Determines if the current screen size should use three-column mode
  ///
  /// @param context The BuildContext to get screen dimensions from
  /// @return True if the screen is wide enough for three columns
  static bool isThreeColumnMode(BuildContext context) =>
      MediaQuery.of(context).size.width > columnWidth * 3.5;

  /// Creates a gradient for backgrounds with customizable alpha transparency
  ///
  /// @param context The BuildContext to get theme colors from
  /// @param alpha The alpha value (0-255) for the gradient colors
  /// @return A LinearGradient using theme colors with specified transparency
  static LinearGradient backgroundGradient(BuildContext context, int alpha) {
    final colorScheme = Theme.of(context).colorScheme;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter, // Added for clarity
      stops: const [0.0, 0.33, 0.66, 1.0], // Added for more precise control
      colors: [
        colorScheme.primaryContainer.withAlpha(alpha),
        colorScheme.secondaryContainer.withAlpha(alpha),
        colorScheme.tertiaryContainer.withAlpha(alpha),
        colorScheme.primaryContainer.withAlpha(alpha),
      ],
    );
  }

  /// Constructs a complete ThemeData object based on brightness and optional seed color
  ///
  /// @param context The BuildContext to determine layout properties
  /// @param brightness The desired brightness (light/dark) for the theme
  /// @param seed Optional seed color to generate the ColorScheme
  /// @return A fully configured ThemeData object
  static ThemeData buildTheme(
    BuildContext context,
    Brightness brightness, [
    Color? seed,
  ]) {
    // Generate color scheme from seed or default app colors
    final colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: seed ?? AppConfig.colorSchemeSeed ?? AppConfig.primaryColor,
    );

    // Determine the current layout mode
    final isColumnMode = AIChatChatThemes.isColumnMode(context);

    return ThemeData(
      fontFamily: 'SF Pro Rounded',
      visualDensity: VisualDensity.standard,
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // Configure divider color based on brightness
      dividerColor:
          brightness == Brightness.dark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainer,

      // Popup menu styling
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
      ),

      // Segmented button styling
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          iconColor: colorScheme.onSurface,
          disabledIconColor: colorScheme.onSurface,
        ),
      ),

      // Text selection styling
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: colorScheme.onSurface.withAlpha(128),
        selectionHandleColor: colorScheme.secondary,
      ),

      // Input field styling
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        ),
        contentPadding: const EdgeInsets.all(12),
        filled: false,
      ),

      // App bar configuration (adapts to layout mode)
      appBarTheme: AppBarTheme(
        toolbarHeight: isColumnMode ? 72 : 56,
        shadowColor:
            isColumnMode ? colorScheme.surfaceContainer.withAlpha(128) : null,
        surfaceTintColor: isColumnMode ? colorScheme.surface : null,
        backgroundColor: isColumnMode ? colorScheme.surface : null,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness.reversed,
          statusBarBrightness: brightness,
          systemNavigationBarIconBrightness: brightness.reversed,
          systemNavigationBarColor: colorScheme.surface,
        ),
      ),

      // Outlined button styling
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(width: 1, color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colorScheme.primary),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          ),
        ),
      ),

      // Snackbar styling (adapts to layout mode)
      snackBarTheme:
          isColumnMode
              ? const SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                width: columnWidth * 1.5, // Use class constant reference
              )
              : const SnackBarThemeData(behavior: SnackBarBehavior.floating),

      // Elevated button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          elevation: 0,
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

/// Extension to flip brightness values between light and dark
extension BrightnessExtension on Brightness {
  /// Returns the opposite brightness value
  Brightness get reversed =>
      this == Brightness.dark ? Brightness.light : Brightness.dark;
}

/// Extension to add chat bubble theming to ThemeData
extension BubbleColorTheme on ThemeData {
  /// Returns the appropriate primary bubble color based on current brightness
  Color get bubbleColor =>
      brightness == Brightness.light
          ? colorScheme.primary
          : colorScheme.primaryContainer;

  /// Returns the appropriate text color for the primary bubble
  Color get onBubbleColor =>
      brightness == Brightness.light
          ? colorScheme.onPrimary
          : colorScheme.onPrimaryContainer;

  /// Returns a desaturated tertiary color for secondary bubbles
  Color get secondaryBubbleColor {
    final baseColor =
        brightness == Brightness.light
            ? colorScheme.tertiary
            : colorScheme.tertiaryContainer;

    // Create a desaturated version of the base color
    return HSLColor.fromColor(baseColor).withSaturation(0.5).toColor();
  }
}

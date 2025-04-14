import 'package:ai_chat_chat_client/services/theme/theme_providers.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A widget that provides theme information to its child builder
///
/// ThemeBuilder watches theme state and provides the current theme mode and
/// primary color to its child builder function. It also integrates with
/// DynamicColor to allow for system color schemes when appropriate.
class ThemeBuilder extends ConsumerWidget {
  /// Builder function that receives theme data and returns a widget
  ///
  /// @param context The build context
  /// @param themeMode The current theme mode (light, dark, or system)
  /// @param primaryColor The current primary color, or null if using system default
  final Widget Function(
    BuildContext context,
    ThemeMode themeMode,
    Color? primaryColor,
  )
  builder;

  /// Creates a ThemeBuilder with the specified builder function
  const ThemeBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final primaryColor = ref.watch(primaryColorProvider);

    return DynamicColorBuilder(
      builder: (light, dark) {
        // Use provided primary color, or fall back to system color if available,
        // otherwise null (theme will use default Material primary color)
        final effectivePrimaryColor = primaryColor ?? light?.primary;

        return builder(context, themeMode, effectivePrimaryColor);
      },
    );
  }
}

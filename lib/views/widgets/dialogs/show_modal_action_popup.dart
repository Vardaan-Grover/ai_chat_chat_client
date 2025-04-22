import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart' show Logger;

/// A logger for the modal action popup.
final _logger = Logger('ShowModalActionPopup');

/// Shows a platform-adaptive modal popup with a list of actions.
/// 
/// On Android, Fuchsia, Windows, and Linux, this displays as a modal bottom sheet.
/// On iOS and macOS, this displays as a Cupertino action sheet.
/// 
/// Parameters:
/// - [context]: The build context.
/// - [actions]: List of actions to display in the popup.
/// - [title]: Optional title for the popup.
/// - [message]: Optional message/description for the popup.
/// - [cancelLabel]: Optional label for the cancel action.
/// - [useRootNavigator]: Whether to use the root navigator for showing the popup.
/// - [barrierDismissible]: Whether tapping outside the popup dismisses it (default: true).
/// 
/// Returns a Future that completes with the selected action's value, or null if dismissed.
Future<T?> showModalActionPopup<T>({
  required BuildContext context,
  required List<AdaptiveModalAction<T>> actions,
  String? title,
  String? message,
  String? cancelLabel,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
}) {
  _logger.fine('Showing modal action popup with ${actions.length} actions');
  
  if (context == null) {
    _logger.severe('Context cannot be null');
    throw ArgumentError('Context cannot be null');
  }
  
  if (actions.isEmpty) {
    _logger.warning('No actions provided to modal popup');
  }

  final theme = Theme.of(context);
  final mediaQuery = MediaQuery.of(context);

  // Use platform-specific implementation
  switch (theme.platform) {
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      _logger.fine('Using Material design bottom sheet');
      return _showMaterialModalPopup(
        context: context,
        actions: actions,
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        useRootNavigator: useRootNavigator,
        barrierDismissible: barrierDismissible,
        mediaQuery: mediaQuery,
        theme: theme,
      );
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      _logger.fine('Using Cupertino action sheet');
      return _showCupertinoModalPopup(
        context: context,
        actions: actions,
        title: title,
        message: message,
        cancelLabel: cancelLabel,
        useRootNavigator: useRootNavigator,
        barrierDismissible: barrierDismissible,
      );
  }
}

/// Shows a Material Design bottom sheet.
Future<T?> _showMaterialModalPopup<T>({
  required BuildContext context,
  required List<AdaptiveModalAction<T>> actions,
  required MediaQueryData mediaQuery,
  required ThemeData theme,
  String? title,
  String? message,
  String? cancelLabel,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
}) {
  // Calculate appropriate max height based on screen size
  final maxHeight = mediaQuery.size.height * 0.8;
  
  return showModalBottomSheet(
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    context: context,
    clipBehavior: Clip.hardEdge,
    isDismissible: barrierDismissible,
    enableDrag: true,
    constraints: BoxConstraints(
      maxWidth: 512,
      maxHeight: maxHeight,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          // Header section with title/message
          if (title != null || message != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ListTile(
                title: title == null
                    ? null
                    : Text(
                        title,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                subtitle: message == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          message,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
            const Divider(height: 1),
          ],
          
          // Action items
          ...actions.map(
            (action) => ListTile(
              leading: action.icon,
              title: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: action.isDestructive
                    ? TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: action.isDefaultAction
                            ? FontWeight.bold
                            : null,
                      )
                    : action.isDefaultAction
                        ? TextStyle(fontWeight: FontWeight.bold)
                        : null,
              ),
              onTap: () {
                _logger.fine('Action selected: ${action.label}');
                Navigator.of(context).pop<T>(action.value);
              },
            ),
          ),
          
          // Cancel button
          if (cancelLabel != null) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(
                cancelLabel,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.secondary),
              ),
              onTap: () {
                _logger.fine('Cancel button tapped');
                Navigator.of(context).pop(null);
              },
            ),
          ],
        ],
      ),
    ),
  );
}

/// Shows a Cupertino action sheet.
Future<T?> _showCupertinoModalPopup<T>({
  required BuildContext context,
  required List<AdaptiveModalAction<T>> actions,
  String? title,
  String? message,
  String? cancelLabel,
  bool useRootNavigator = true,
  bool barrierDismissible = true,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0), // Add blur effect
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: CupertinoActionSheet(
          title: title == null ? null : Text(title),
          message: message == null ? null : Text(message),
          cancelButton: cancelLabel == null
              ? null
              : CupertinoActionSheetAction(
                  onPressed: () {
                    _logger.fine('Cancel button tapped');
                    Navigator.of(context).pop(null);
                  },
                  child: Text(cancelLabel),
                ),
          actions: actions
              .map(
                (action) => CupertinoActionSheetAction(
                  isDestructiveAction: action.isDestructive,
                  isDefaultAction: action.isDefaultAction,
                  onPressed: () {
                    _logger.fine('Action selected: ${action.label}');
                    Navigator.of(context).pop<T>(action.value);
                  },
                  child: Text(action.label, maxLines: 1),
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
}

/// Represents an action in the modal popup.
class AdaptiveModalAction<T> {
  /// The text label of the action.
  final String label;
  
  /// The value to return when this action is selected.
  final T value;
  
  /// Optional icon to display alongside the label (only used in Material design).
  final Icon? icon;
  
  /// Whether this is the default action (will be highlighted).
  final bool isDefaultAction;
  
  /// Whether this is a destructive action (will be highlighted in red).
  final bool isDestructive;

  /// Creates an adaptive modal action.
  /// 
  /// [label] and [value] are required.
  /// [icon] is optional and only shown on Material platforms.
  /// [isDefaultAction] highlights the action as the default choice.
  /// [isDestructive] highlights the action in red to indicate destructive behavior.
  AdaptiveModalAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDefaultAction = false,
    this.isDestructive = false,
  });
}
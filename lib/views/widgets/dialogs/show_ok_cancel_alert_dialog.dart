import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'adaptive_dialog_action.dart';

enum OkCancelResult { ok, cancel }

Future<OkCancelResult?> showOkCancelAlertDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? okLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool useRootNavigator = true,
}) => showAdaptiveDialog<OkCancelResult>(
  context: context,
  useRootNavigator: useRootNavigator,
  builder:
      (context) => AlertDialog.adaptive(
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child: Text(title),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child:
              message == null
                  ? null
                  : SelectableLinkify(
                    text: message,
                    linkStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decorationColor: Theme.of(context).colorScheme.primary,
                    ),
                    options: const LinkifyOptions(humanize: false),
                    // TODO: implement the UrlLauncher class
                    onOpen: (url) => launchUrlString(url.url),
                  ),
        ),
        actions: [
          AdaptiveDialogAction(
            onPressed:
                () => Navigator.of(
                  context,
                ).pop<OkCancelResult>(OkCancelResult.cancel),
            child: Text(cancelLabel ?? 'Cancel'),
          ),
          AdaptiveDialogAction(
            onPressed:
                () => Navigator.of(
                  context,
                ).pop<OkCancelResult>(OkCancelResult.ok),
            autofocus: true,
            child: Text(
              okLabel ?? 'Ok',
              style:
                  isDestructive
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
            ),
          ),
        ],
      ),
);

Future<OkCancelResult?> showOkAlertDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? okLabel,
  bool useRootNavigator = true,
}) => showAdaptiveDialog<OkCancelResult>(
  context: context,
  useRootNavigator: useRootNavigator,
  builder:
      (context) => AlertDialog.adaptive(
        title: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child: Text(title),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 256),
          child:
              message == null
                  ? null
                  : SelectableLinkify(
                    text: message,
                    linkStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decorationColor: Theme.of(context).colorScheme.primary,
                    ),
                    options: const LinkifyOptions(humanize: false),
                    // TODO: implement the UrlLauncher class
                    onOpen: (url) => launchUrlString(url.url),
                  ),
        ),
        actions: [
          AdaptiveDialogAction(
            onPressed:
                () => Navigator.of(
                  context,
                ).pop<OkCancelResult>(OkCancelResult.ok),
            autofocus: true,
            child: Text(okLabel ?? 'Ok'),
          ),
        ],
      ),
);

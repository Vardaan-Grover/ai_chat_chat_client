import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/viewmodels/homeserver_picker_controller.dart';
import 'package:ai_chat_chat_client/views/layouts/login_scaffold.dart';
import 'package:ai_chat_chat_client/views/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeserverPickerView extends StatelessWidget {
  final HomeserverPickerController controller;

  const HomeserverPickerView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoginScaffold(
      enforceMobileMode:
          controller.ref.read(matrixServiceProvider).client.isLogged(),
      appBar: AppBar(
        title: Text(
          controller.widget.addMultiAccount ? 'Add account' : 'Login',
        ),
        actions: [
          PopupMenuButton(
            onSelected: controller.onMoreAction,
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: MoreLoginActions.importBackup,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.import_export_outlined),
                        const SizedBox(width: 12),
                        Text('Restore from backup file'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: MoreLoginActions.privacy,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.privacy_tip_outlined),
                        const SizedBox(width: 12),
                        Text('Privacy Policy'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Hero(
                        tag: 'info-logo',
                        child: Text('AI CHAT CHAT')
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SelectableLinkify(
                        text: 'AI CHAT CHAT lets you use all your social apps on this one platform. Learn more at https://matrix.org or just tap *Continue*.',
                        textAlign: TextAlign.center,
                        linkStyle: TextStyle(
                          color: theme.colorScheme.secondary,
                          decorationColor: theme.colorScheme.secondary,
                        ),
                        onOpen: (link) => launchUrlString(link.url),
                      )
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            onSubmitted:
                                (_) => controller.checkHomeserverAction(),
                            controller: controller.homeserverController,
                            autocorrect: false,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_outlined),
                              filled: false,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppConfig.borderRadius,
                                ),
                              ),
                              hintText: AppConfig.defaultHomeserver,
                              hintStyle: TextStyle(
                                color: theme.colorScheme.surfaceTint,
                              ),
                              labelText: 'Sign in with:',
                              errorText: controller.errorText,
                              errorMaxLines: 4,
                              suffixIcon: IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog.adaptive(
                                          title: Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: Text(
                                              'What is a Homeserver?',
                                            ),
                                          ),
                                          content: Linkify(
                                            textAlign: TextAlign.center,
                                            text:
                                                'All your data is stored on the homeserver, just like an email provider. You can choose which homeserver you want to use, while you can still communicate with everyone.',
                                          ),
                                          actions: [
                                            AdaptiveDialogAction(
                                              onPressed:
                                                  () => launchUrl(
                                                    Uri.https(
                                                      'servers.joinmatrix.org',
                                                    ),
                                                  ),
                                              child: Text(
                                                'Discover Homeservers',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w200,
                                                ),
                                              ),
                                            ),
                                            AdaptiveDialogAction(
                                              onPressed:
                                                  Navigator.of(context).pop,
                                              child: Text('Close'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                                icon: const Icon(Icons.info_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                            ),
                            onPressed:
                                controller.isLoading
                                    ? null
                                    : controller.checkHomeserverAction,
                            child:
                                controller.isLoading
                                    ? const LinearProgressIndicator()
                                    : Text('Continue'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.secondary,
                              textStyle: theme.textTheme.labelMedium,
                            ),
                            onPressed:
                                controller.isLoading
                                    ? null
                                    : () => controller.checkHomeserverAction(
                                      legacyPasswordLogin: true,
                                    ),
                            child: Text('Login with Matrix ID'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ),
          );
        },
      ),
    );
  }
}

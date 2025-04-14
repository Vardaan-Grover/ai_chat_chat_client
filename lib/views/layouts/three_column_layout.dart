import 'package:ai_chat_chat_client/services/theme/themes.dart';
import 'package:flutter/material.dart';

class ThreeColumnLayout extends StatelessWidget {
  final Widget leftSideView;
  final Widget mainView;
  final Widget rightSideView;

  const ThreeColumnLayout({
    required this.leftSideView,
    required this.mainView,
    required this.rightSideView,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaffoldMessenger(
      child: Scaffold(
        body: Row(
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(),
              width: AIChatChatThemes.columnWidth + AIChatChatThemes.navRailWidth,
              child: leftSideView, 
            ),
            Container(
              width: 1.0,
              color: theme.dividerColor,
            ),
            Expanded(
              child: ClipRRect(
                child: mainView,
              ),
            ),
            Container(
              width: 1.0,
              color: theme.dividerColor,
            ),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(),
              width: AIChatChatThemes.columnWidth,
              child: rightSideView,
            ),
          ],
        ),
      ),
    );
  }
}

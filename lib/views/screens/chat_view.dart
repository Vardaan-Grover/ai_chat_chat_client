import 'package:ai_chat_chat_client/services/extensions/stream_extension.dart';
import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/theme/themes.dart';
import 'package:ai_chat_chat_client/viewmodels/chat_page_controller.dart';
import 'package:ai_chat_chat_client/views/widgets/chat/chat_app_bar_list_tile.dart';
import 'package:ai_chat_chat_client/views/widgets/chat/chat_app_bar_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

class ChatView extends ConsumerWidget {
  final ChatPageController controller;

  const ChatView(this.controller, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final scrollUpBannerEventId = controller.scrollUpBannerEventId;

    return PopScope(
      canPop: controller.selectedEvents.isEmpty,
      onPopInvokedWithResult: (pop, _) async {
        if (controller.selectedEvents.isNotEmpty) {
          controller.clearSelectedEvents();
        }
      },
      child: StreamBuilder(
        stream: controller.room.client.onRoomState.stream
            .where((update) => update.roomId == controller.room.id)
            .rateLimit(const Duration(seconds: 1)),
        builder:
            (context, snapshot) => FutureBuilder(
              future: controller.loadTimelineFuture,
              builder: (context, snapshot) {
                var appbarBottomHeight = 0.0;
                if (controller.room.pinnedEventIds.isNotEmpty) {
                  appbarBottomHeight += ChatAppBarListTile.fixedHeight;
                }
                if (scrollUpBannerEventId != null) {
                  appbarBottomHeight += ChatAppBarListTile.fixedHeight;
                }

                return Scaffold(
                  appBar: AppBar(
                    actionsIconTheme: IconThemeData(
                      color:
                          controller.selectedEvents.isEmpty
                              ? null
                              : theme.colorScheme.tertiary,
                    ),
                    automaticallyImplyLeading: false,
                    leading:
                        controller.selectMode
                            ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: controller.clearSelectedEvents,
                              tooltip: 'Close',
                              color: theme.colorScheme.tertiary,
                            )
                            : null,
                    titleSpacing:
                        AIChatChatThemes.isColumnMode(context) ? 24 : 0,
                    title: ChatAppBarTitle(controller),
                    bottom: PreferredSize(
                      preferredSize: Size.fromHeight(appbarBottomHeight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          //? No Pinned Events widget added here
                          if (scrollUpBannerEventId != null)
                            ChatAppBarListTile(
                              leading: IconButton(
                                color: theme.colorScheme.onSurfaceVariant,
                                icon: const Icon(Icons.close),
                                tooltip: 'Close',
                                onPressed: () {
                                  controller.discardScrollUpBannerEventId();
                                  controller.setReadMarker();
                                },
                              ),
                              title: 'Jump to last unread message',
                              trailing: TextButton(
                                onPressed: () {
                                  controller.scrollToEventId(
                                    scrollUpBannerEventId,
                                  );
                                  controller.discardScrollUpBannerEventId();
                                },
                                child: Text('Jump'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  body: Container(color: Colors.white),
                );
              },
            ),
      ),
    );
  }
}

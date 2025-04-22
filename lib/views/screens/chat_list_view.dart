import 'package:ai_chat_chat_client/services/theme/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

import '../../viewmodels/chat_list_controller.dart';
import '../../services/matrix/matrix_providers.dart';
import '../../services/extensions/stream_extension.dart';

class ChatListView extends ConsumerWidget {
  final ChatListController controller;

  const ChatListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final Client client = ref.watch(clientProvider);

    return PopScope(
      canPop: !controller.isSearchMode && controller.activeSpaceId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (controller.activeSpaceId != null) {
          controller.clearActiveSpace();
          return;
        }
        if (controller.isSearchMode) {
          controller.cancelSearch();
          return;
        }
      },
      child: Row(
        children: [
          if (AIChatChatThemes.isColumnMode(context) && controller.widget.displayNavigationRail) ...[
            // TODO: Replace with actual navigation rail
            Container(
              color: theme.navigationRailTheme.backgroundColor,
              width: AIChatChatThemes.navRailWidth,
            ),
            Container(
              color: Theme.of(context).dividerColor,
              width: 1,
            )
          ],
          Expanded(
            child: GestureDetector(
              onTap: FocusManager.instance.primaryFocus?.unfocus,
              excludeFromSemantics: true,
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                body: ChatListViewBody(),
              ),
            ),
          ),
        ],
      ),
    );

    // return Scaffold(
    //   body: StreamBuilder(
    //     key: ValueKey(client.userID.toString()),
    //     stream: client.onSync.stream
    //         .where((s) => s.hasRoomUpdate)
    //         .rateLimit(const Duration(seconds: 1)),
    //     builder: (context, _) {
    //       final rooms = controller.filteredRooms;

    //       return SafeArea(
    //         child: CustomScrollView(
    //           controller: controller.scrollController,
    //           slivers: [
    //             SliverList.builder(
    //               itemCount: rooms.length,
    //               itemBuilder: (BuildContext context, int i) {
    //                 final room = rooms[i];
    //                 return ListTile(
    //                   title: Text(room.getLocalizedDisplayname()),
    //                   subtitle: Text(room.lastEvent?.body ?? 'N/A'),
    //                   onTap: () {
    //                     // Handle room tap
    //                     controller.onChatTap(room);
    //                   },
    //                 );
    //               },
    //             ),
    //           ],
    //         ),
    //       );
    //     },
    //   ),
    // );
  }
}

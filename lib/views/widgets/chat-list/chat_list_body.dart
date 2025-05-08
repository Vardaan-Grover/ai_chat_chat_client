import 'package:ai_chat_chat_client/services/extensions/stream_extension.dart';
import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/viewmodels/chat_list_controller.dart';
import 'package:ai_chat_chat_client/views/widgets/chat-list/chat_list_header.dart';
import 'package:ai_chat_chat_client/views/widgets/chat-list/chat_list_item.dart';
import 'package:ai_chat_chat_client/views/widgets/chat-list/dummy_chat_list_item.dart';
import 'package:ai_chat_chat_client/views/widgets/chat-list/search_category.dart';
import 'package:ai_chat_chat_client/views/widgets/chat-list/space_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

class ChatListBody extends ConsumerWidget {
  final ChatListController controller;

  const ChatListBody(this.controller, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final client = ref.watch(clientProvider);

    final activeSpace = controller.activeSpaceId;

    if (activeSpace != null) {
      return SpaceView(
        key: ValueKey(activeSpace),
        spaceId: activeSpace,
        onBack: controller.clearActiveSpace,
        toParentSpace: controller.setActiveSpace,
        onChatTap: (room) => controller.onChatTap(room),
        activeChat: controller.activeChat,
      );
    }

    final spaces = client.rooms.where((r) => r.isSpace);
    final spaceDelegateCandidates = <String, Room>{};
    for (final space in spaces) {
      for (final spaceChild in space.spaceChildren) {
        final roomId = spaceChild.roomId;
        if (roomId == null) continue;
        spaceDelegateCandidates[roomId] = space;
      }
    }

    final publicRooms =
        controller.roomSearchResult?.chunk
            .where((room) => room.roomType != 'm.space')
            .toList();
    final publicSpaces =
        controller.roomSearchResult?.chunk
            .where((room) => room.roomType == 'm.space')
            .toList();
    final userSearchResult = controller.userSearchResult;
    const dummyChatCount = 4;
    final filter = controller.searchController.text.toLowerCase();

    return StreamBuilder(
      stream: client.onSync.stream
          .where((s) => s.hasRoomUpdate)
          .rateLimit(const Duration(seconds: 1)),
      builder: (context, _) {
        final rooms = controller.filteredRooms;

        return SafeArea(
          bottom: false,
          // top: false,
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [
              ChatListHeader(controller: controller),
              SliverList(
                delegate: SliverChildListDelegate([
                  if (controller.isSearchMode) ...[
                    SearchCategory(title: 'Chats', icon: Icon(Icons.person)),

                    SearchCategory(
                      title: 'Messages',
                      icon: Icon(CupertinoIcons.chat_bubble),
                    ),
                    SearchCategory(
                      title: 'Media',
                      icon: Icon(CupertinoIcons.photo),
                    ),
                  ],

                  if (client.prevBatch != null &&
                      rooms.isEmpty &&
                      !controller.isSearchMode) ...[
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DummyChatListItem(opacity: 0.5, animate: false),
                                DummyChatListItem(opacity: 0.3, animate: false),
                              ],
                            ),
                            Icon(
                              CupertinoIcons.chat_bubble_text_fill,
                              size: 128,
                              color: theme.colorScheme.secondary,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            client.rooms.isEmpty
                                ? 'No chats found here...'
                                : 'No more chats found...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ]),
              ),

              if (client.prevBatch == null)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    childCount: dummyChatCount,
                    (context, i) => DummyChatListItem(
                      opacity: (dummyChatCount - i) / dummyChatCount,
                      animate: true,
                    ),
                  ),
                ),

              if (client.prevBatch != null)
                SliverList.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, i) {
                    final room = rooms[i];
                    final space = spaceDelegateCandidates[room.id];

                    return ChatListItem(
                      room,
                      space: space,
                      key: Key('chat_list_item_${room.id}'),
                      filter: filter,
                      onTap: () => controller.onChatTap(room),
                      onLongPress: (context) => {},
                      activeChat: controller.activeChat == room.id,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

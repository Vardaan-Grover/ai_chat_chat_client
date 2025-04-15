import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/extensions/stream_extension.dart';
import 'package:ai_chat_chat_client/viewmodels/chat_list_controller.dart';
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

    final spaces = client.rooms.where((room) => room.isSpace).toList();
    final spaceDelegateCandidate = <String, Room>{};

    for (final space in spaces) {
      for (final spaceChild in space.spaceChildren) {
        final roomId = spaceChild.roomId;
        if (roomId == null) continue;
        spaceDelegateCandidate[roomId] = space;
      }
    }

    final dummyChatCount = 4;

    return StreamBuilder(
      stream: client.onSync.stream
          .where((s) => s.hasRoomUpdate)
          .rateLimit(const Duration(seconds: 1)),
      builder: (context, _) {
        final rooms = controller.filteredRooms;

        return SafeArea(
          child: CustomScrollView(
            controller: controller.scrollController,
            slivers: [],
          ),
        );
      },
    );
  }
}

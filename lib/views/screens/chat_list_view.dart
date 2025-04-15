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
    final Client client = ref.watch(clientProvider);

    return Scaffold(
      body: StreamBuilder(
        key: ValueKey(client.userID.toString()),
        stream: client.onSync.stream
            .where((s) => s.hasRoomUpdate)
            .rateLimit(const Duration(seconds: 1)),
        builder: (context, _) {
          final rooms = controller.filteredRooms;
      
          return SafeArea(
            child: CustomScrollView(
              controller: controller.scrollController,
              slivers: [
                SliverList.builder(
                  itemCount: rooms.length,
                  itemBuilder: (BuildContext context, int i) {
                    final room = rooms[i];
                    return ListTile(
                      title: Text(room.getLocalizedDisplayname()),
                      subtitle: Text(room.lastEvent?.body ?? 'N/A'),
                      onTap: () {
                        // Handle room tap
                        controller.onChatTap(room);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

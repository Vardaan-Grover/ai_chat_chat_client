import 'package:flutter/material.dart';

import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/sharing_service.dart';
import 'package:ai_chat_chat_client/views/utils/qr_code_viewer.dart';
import 'package:ai_chat_chat_client/views/widgets/avatar.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/future_loading_dialog.dart';

class PublicRoomBottomSheet extends ConsumerWidget {
  final String? roomAlias;
  final BuildContext outerContext;
  final PublicRoomsChunk? chunk;
  final List<String>? via;

  PublicRoomBottomSheet({
    this.roomAlias,
    required this.outerContext,
    this.chunk,
    this.via,
    super.key,
  }) {
    assert(roomAlias != null || chunk != null);
  }

  void _joinRoom(BuildContext context, WidgetRef ref) async {
    final client = ref.read(clientProvider);
    final chunk = this.chunk;
    final knock = chunk?.joinRule == 'knock';
    final result = await showFutureLoadingDialog<String>(
      context: context,
      future: () async {
        if (chunk != null && client.getRoomById(chunk.roomId) != null) {
          return chunk.roomId;
        }
        final roomId =
            chunk != null && knock
                ? await client.knockRoom(chunk.roomId, serverName: via)
                : await client.joinRoom(
                  roomAlias ?? chunk!.roomId,
                  serverName: via,
                );

        if (!knock && client.getRoomById(roomId) == null) {
          await client.waitForRoomInSync(roomId);
        }
        return roomId;
      },
    );
    if (knock) {
      return;
    }
    if (result.error == null) {
      Navigator.of(context).pop<bool>(true);
      // don't open the room if the joined room is a space
      if (chunk?.roomType != 'm.space' &&
          !client.getRoomById(result.result!)!.isSpace) {
        outerContext.go('/rooms/${result.result!}');
      }
      return;
    }
  }

  bool _testRoom(PublicRoomsChunk r) => r.canonicalAlias == roomAlias;

  Future<PublicRoomsChunk> _search(WidgetRef ref) async {
    final client = ref.read(clientProvider);
    final chunk = this.chunk;
    if (chunk != null) return chunk;
    final query = await client.queryPublicRooms(
      server: roomAlias!.domain,
      filter: PublicRoomQueryFilter(genericSearchTerm: roomAlias),
    );
    if (!query.chunk.any(_testRoom)) {
      throw ('No room found with alias $roomAlias');
    }
    return query.chunk.firstWhere(_testRoom);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider);
    final roomAlias = this.roomAlias ?? chunk?.canonicalAlias;
    final roomLink = roomAlias ?? chunk?.roomId;
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            chunk?.name ?? roomAlias ?? chunk?.roomId ?? 'Unknown',
            overflow: TextOverflow.fade,
          ),
          leading: Center(
            child: CloseButton(
              onPressed: Navigator.of(context, rootNavigator: false).pop,
            ),
          ),
          actions:
              roomAlias == null
                  ? null
                  : [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_rounded),
                        onPressed: () => showQrCodeViewer(context, roomAlias),
                      ),
                    ),
                  ],
        ),
        body: FutureBuilder<PublicRoomsChunk>(
          future: _search(ref),
          builder: (context, snapshot) {
            final theme = Theme.of(context);

            final profile = snapshot.data;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child:
                          profile == null
                              ? const Center(
                                child: CircularProgressIndicator.adaptive(),
                              )
                              : Avatar(
                                client: client,
                                mxContent: profile.avatarUrl,
                                name: profile.name ?? roomAlias,
                                size: Avatar.defaultSize * 3,
                              ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed:
                                roomLink != null
                                    ? () => SharingService.share(
                                      roomLink,
                                      context,
                                      copyOnly: true,
                                    )
                                    : null,
                            icon: const Icon(Icons.copy_outlined, size: 14),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface,
                              iconColor: theme.colorScheme.onSurface,
                            ),
                            label: Text(
                              roomLink ?? '...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.groups_3_outlined, size: 14),
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface,
                              iconColor: theme.colorScheme.onSurface,
                            ),
                            label: Text(
                              '${profile?.numJoinedMembers ?? 0} participants',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _joinRoom(context, ref),
                    label: Text(
                      chunk?.joinRule == 'knock' &&
                              client.getRoomById(chunk!.roomId) ==
                                  null
                          ? 'Knock'
                          : chunk?.roomType == 'm.space'
                          ? 'Join Space'
                          : 'Join Room',
                    ),
                    icon: const Icon(Icons.navigate_next),
                  ),
                ),
                const SizedBox(height: 16),
                if (profile?.topic?.isNotEmpty ?? false)
                  ListTile(
                    subtitle: SelectableLinkify(
                      text: profile!.topic!,
                      linkStyle: TextStyle(
                        color: theme.colorScheme.primary,
                        decorationColor: theme.colorScheme.primary,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium!.color,
                      ),
                      options: const LinkifyOptions(humanize: false),
                      onOpen:
                          (url) => launchUrlString(url.url),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

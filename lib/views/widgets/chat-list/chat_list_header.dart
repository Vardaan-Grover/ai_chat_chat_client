import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/theme/themes.dart';
import 'package:ai_chat_chat_client/viewmodels/chat_list_controller.dart';
import 'package:ai_chat_chat_client/views/utils/localized_exception_context.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matrix/matrix.dart';

class ChatListHeader extends ConsumerWidget implements PreferredSizeWidget {
  final ChatListController controller;
  final bool globalSearch;

  const ChatListHeader({
    required this.controller,
    this.globalSearch = true,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final client = ref.watch(clientProvider);

    return SliverAppBar(
      floating: true,
      toolbarHeight: 72,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      pinned: AIChatChatThemes.isColumnMode(context),
      automaticallyImplyLeading: false,
      title: StreamBuilder(
        stream: client.onSyncStatus.stream,
        builder: (context, snapshot) {
          final status =
              client.onSyncStatus.value ??
              const SyncStatusUpdate(SyncStatus.waitingForResponse);
          final hide =
              client.onSync.value != null &&
              status.status != SyncStatus.error &&
              client.prevBatch != null;
          return TextField(
            controller: controller.searchController,
            focusNode: controller.searchFocusNode,
            textInputAction: TextInputAction.search,
            onChanged:
                (text) =>
                    controller.onSearchEnter(text, globalSearch: globalSearch),
            style: TextStyle(fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.secondaryContainer,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(99),
              ),
              contentPadding: EdgeInsets.zero,
              hintText:
                  hide ? 'Search for chats' : status.toLocalizedString(context),
              hintStyle: TextStyle(
                color:
                    status.error != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon:
                  hide
                      ? controller.isSearchMode
                          ? IconButton(
                            tooltip: 'Cancel',
                            icon: const Icon(Icons.close_outlined),
                            onPressed: controller.cancelSearch,
                            color: theme.colorScheme.onPrimaryContainer,
                          )
                          : IconButton(
                            onPressed: controller.startSearch,
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.search_outlined,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                      : Container(
                        margin: const EdgeInsets.all(12),
                        width: 8,
                        height: 8,
                        child: Center(
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                            value: status.progress,
                            valueColor:
                                status.error != null
                                    ? AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.error,
                                    )
                                    : null,
                          ),
                        ),
                      ),
            ),
          );
        },
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

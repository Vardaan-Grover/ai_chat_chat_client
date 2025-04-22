import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:ai_chat_chat_client/services/extensions/stream_extension.dart';
import 'package:ai_chat_chat_client/services/theme/themes.dart';
import 'package:ai_chat_chat_client/views/widgets/avatar.dart';
import 'package:ai_chat_chat_client/views/widgets/chat-list/chat_list_item.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/future_loading_dialog.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/show_modal_action_popup.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/show_text_input_dialog.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart' as sdk;

import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/views/widgets/chat-list/public_room_bottom_sheet.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/adaptive_bottom_sheet.dart';
import 'package:matrix/matrix_api_lite.dart';

enum AddRoomType { chat, subspace }

class SpaceView extends ConsumerStatefulWidget {
  final String spaceId;
  final void Function() onBack;
  final void Function(String spaceId) toParentSpace;
  final void Function(sdk.Room room) onChatTab;
  final void Function(sdk.Room room, BuildContext context) onChatContext;
  final String? activeChat;

  const SpaceView({
    required this.spaceId,
    required this.onBack,
    required this.toParentSpace,
    required this.onChatTab,
    required this.onChatContext,
    required this.activeChat,
    super.key,
  });

  @override
  ConsumerState<SpaceView> createState() => _SpaceViewState();
}

class _SpaceViewState extends ConsumerState<SpaceView> {
  final Logger logger = Logger('SpaceView');

  final List<SpaceRoomsChunk> _discoveredChildren = [];
  final TextEditingController _filterController = TextEditingController();
  String? _nextBatch;
  bool _noMoreRooms = false;
  bool _isLoading = false;

  @override
  initState() {
    _loadHierarchy();
    super.initState();
  }

  /// Loads the space hierarchy for the current space.
  ///
  /// This asynchronously fetches child rooms from the space hierarchy API,
  /// updates the UI state accordingly, and handles pagination via [_nextBatch].
  /// Errors are logged and displayed to the user.
  Future<void> _loadHierarchy() async {
    final client = ref.read(clientProvider);
    final room = client.getRoomById(widget.spaceId);

    if (room == null) {
      logger.warning(
        'Attempted to load hierarchy for non-existent space: ${widget.spaceId}',
      );
      return;
    }

    // Prevent multiple simultaneous loading requests
    if (_isLoading) {
      logger.fine('Hierarchy loading already in progress, skipping request');
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    logger.info(
      'Loading space hierarchy for: ${widget.spaceId}${_nextBatch != null ? ' (pagination)' : ''}',
    );

    try {
      // Request the space hierarchy from the server
      final hierarchy = await room.client.getSpaceHierarchy(
        widget.spaceId,
        suggestedOnly: false, // Include all rooms, not just suggested ones
        maxDepth: 2, // Limit nesting depth to 2 levels
        from: _nextBatch, // Support pagination using the next batch token
      );

      // Handle case where widget is disposed during async operation
      if (!mounted) {
        logger.fine(
          'Widget unmounted during hierarchy loading, discarding results',
        );
        return;
      }

      // Process the results and update state
      setState(() {
        _nextBatch = hierarchy.nextBatch;
        _noMoreRooms = hierarchy.nextBatch == null;

        // Only add rooms that aren't already joined locally
        final newRooms = hierarchy.rooms.where(
          (c) => room.client.getRoomById(c.roomId) == null,
        );

        _discoveredChildren.addAll(newRooms);
      });

      logger.fine(
        'Loaded ${hierarchy.rooms.length} rooms from hierarchy, ${_discoveredChildren.length} total',
      );
    } catch (e, s) {
      logger.severe('Failed to load space hierarchy', e, s);

      if (mounted) {
        // Display error to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading space hierarchy: $e',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    } finally {
      // Always reset loading state if the widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Joins a child room from the space hierarchy.
  ///
  /// This function handles the flow of:
  /// 1. Showing a bottom sheet with room details
  /// 2. Handling the join operation result
  /// 3. Updating UI state on successful join
  ///
  /// @param item The room chunk containing details about the room to join
  /// @returns A Future that completes when the join operation is finished
  Future<void> _joinChildRoom(sdk.SpaceRoomsChunk item) async {
    logger.info('Attempting to join child room: ${item.roomId} (${item.name})');

    final client = ref.read(clientProvider);
    final space = client.getRoomById(widget.spaceId);

    // Find the room in the space children to get "via" servers
    // These help with federation when joining rooms from other homeservers
    final viaServers =
        space?.spaceChildren
            .firstWhereOrNull((child) => child.roomId == item.roomId)
            ?.via;

    logger.fine(
      'Opening join bottom sheet for room ${item.roomId} with via servers: $viaServers',
    );

    try {
      // Show the bottom sheet and await user action
      final joined = await showAdaptiveBottomSheet<bool>(
        context: context,
        builder:
            (_) => PublicRoomBottomSheet(
              outerContext: context,
              chunk: item,
              via: viaServers,
            ),
      );

      // Handle the join result
      if (mounted) {
        if (joined == true) {
          logger.info('Successfully joined room: ${item.roomId}');

          // Remove the room from discovered list since it's now joined
          setState(() {
            _discoveredChildren.remove(item);
          });
        } else {
          logger.fine('User cancelled joining room: ${item.roomId}');
        }
      }
    } catch (e, s) {
      logger.warning('Error during room join process', e, s);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join room: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Navigates to the space settings screen for the current space.
  ///
  /// This function:
  /// 1. Retrieves the space object from the client
  /// 2. Ensures space data is fully loaded before navigation
  /// 3. Navigates to the details page for space configuration
  ///
  /// If the space cannot be found, displays an error message.
  void _onSpaceSettingsAction() async {
    logger.info('Opening settings for space: ${widget.spaceId}');

    final client = ref.read(clientProvider);
    final space = client.getRoomById(widget.spaceId);

    // Check if space exists
    if (space == null) {
      logger.warning(
        'Attempted to open settings for non-existent space: ${widget.spaceId}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Space not found'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      // Ensure space data is fully loaded before navigation
      logger.fine('Loading space data before navigation');
      await space.postLoad();

      if (mounted) {
        logger.info('Navigating to space details page');
        context.push('/rooms/${widget.spaceId}/details');
      } else {
        logger.fine('Navigation cancelled - widget unmounted');
      }
    } catch (e, s) {
      logger.severe('Failed to load space data for settings view', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open space settings: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Creates a new chat or subspace within the current space.
  ///
  /// This function manages the complete flow for creating new rooms in a space:
  /// 1. Shows a dialog for user to select room type (chat or subspace)
  /// 2. Gets room name from the user via text input dialog
  /// 3. Creates the room with appropriate settings
  /// 4. Adds the new room as a child of the current space
  ///
  /// Errors are properly handled and logged at each step.
  Future<void> _addChatOrSubspace() async {
    logger.info(
      'Opening dialog to create new room in space: ${widget.spaceId}',
    );

    // Step 1: Let user choose room type
    final roomType = await showModalActionPopup(
      context: context,
      actions: [
        AdaptiveModalAction(label: 'New Space', value: AddRoomType.subspace),
        AdaptiveModalAction(label: 'New Chat', value: AddRoomType.chat),
      ],
    );

    // Handle user cancellation
    if (roomType == null) {
      logger.fine('User cancelled room type selection');
      return;
    }

    final roomTypeStr = roomType == AddRoomType.subspace ? 'space' : 'chat';
    logger.info('User selected to create new $roomTypeStr');

    // Step 2: Get the name for the new room
    final name = await showTextInputDialog(
      context: context,
      title: roomType == AddRoomType.subspace ? 'New Space' : 'New Chat',
      hintText:
          roomType == AddRoomType.subspace
              ? 'Enter space name'
              : 'Enter chat name',
      minLines: 1,
      maxLines: 1,
      maxLength: 64,
      validator: (text) {
        if (text.isEmpty) {
          return 'Please choose a name';
        }
        return null;
      },
      okLabel: 'Create',
      cancelLabel: 'Cancel',
    );

    // Handle user cancellation
    if (name == null) {
      logger.fine('User cancelled room name input');
      return;
    }

    logger.info('Creating new $roomTypeStr with name: $name');

    // Step 3 & 4: Create room and add to space
    final client = ref.read(clientProvider);
    final result = await showFutureLoadingDialog(
      context: context,
      future: () async {
        try {
          // Get the current space and ensure it's fully loaded
          final activeSpace = client.getRoomById(widget.spaceId);
          if (activeSpace == null) {
            throw Exception('Current space not found');
          }

          // Load space data to ensure we have current state
          logger.fine('Loading space data before modification');
          await activeSpace.postLoad();

          // Create the appropriate room type
          late final String roomId;
          if (roomType == AddRoomType.subspace) {
            logger.info('Creating new subspace named "$name"');
            roomId = await client.createSpace(
              name: name,
              visibility: sdk.Visibility.private,
              // Additional space creation options could be added here
            );
          } else {
            logger.info('Creating new chat named "$name"');
            roomId = await client.createGroupChat(
              groupName: name,
              preset: CreateRoomPreset.privateChat,
              visibility: sdk.Visibility.private,
              // Additional room creation options could be added here
            );
          }

          logger.info('Successfully created room with ID: $roomId');

          // Add the new room as a child of the space
          logger.info('Adding new room as child of space ${widget.spaceId}');
          await activeSpace.setSpaceChild(roomId);
          logger.info('Room successfully added to space');

          return roomId; // Return the room ID for potential further use
        } catch (e, s) {
          logger.severe('Error creating $roomTypeStr', e, s);
          throw Exception('Failed to create $roomTypeStr: ${e.toString()}');
        }
      },
    );

    // Handle room creation result
    if (mounted) {
      if (result.error != null) {
        logger.severe('Room creation failed: ${result.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create $roomTypeStr: ${result.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        logger.info('$roomTypeStr creation successful');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New $roomTypeStr created successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(clientProvider);
    final theme = Theme.of(context);
    final room = client.getRoomById(widget.spaceId);
    final displayName = room?.getLocalizedDisplayname() ?? 'Nothing Found';

    return Scaffold(
      appBar: AppBar(
        leading:
            AIChatChatThemes.isColumnMode(context)
                ? null
                : Center(child: CloseButton(onPressed: widget.onBack)),
        automaticallyImplyLeading: false,
        titleSpacing: AIChatChatThemes.isColumnMode(context) ? null : 0,
        title: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Avatar(
            mxContent: room?.avatar,
            name: displayName,
            border: BorderSide(width: 1, color: theme.dividerColor),
            borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
          ),
          title: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle:
              room == null
                  ? null
                  : Text(
                    '${room.spaceChildren.length} ${room.spaceChildren.length == 1 ? 'chat' : 'chats'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
        ),
      ),
      body:
          room == null
              ? Center(child: Icon(Icons.search_outlined, size: 80))
              : StreamBuilder(
                stream: room.client.onSync.stream
                    .where((s) => s.hasRoomUpdate)
                    .rateLimit(const Duration(seconds: 1)),
                builder: (context, snapshot) {
                  final childrenIds =
                      room.spaceChildren
                          .map((c) => c.roomId)
                          .whereType<String>()
                          .toSet();

                  final joinedRooms =
                      room.client.rooms
                          .where((room) => childrenIds.remove(room.id))
                          .toList();
                  final joinedParents =
                      room.spaceParents
                          .map((parent) {
                            final roomId = parent.roomId;
                            if (roomId == null) return null;
                            return room.client.getRoomById(roomId);
                          })
                          .whereType<sdk.Room>()
                          .toList();

                  final filter = _filterController.text.trim().toLowerCase();

                  return CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        floating: true,
                        toolbarHeight: 72,
                        scrolledUnderElevation: 16,
                        backgroundColor: Colors.transparent,
                        automaticallyImplyLeading: false,
                        title: TextField(
                          controller: _filterController,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: theme.colorScheme.secondaryContainer,
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Search chats',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.normal,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            prefixIcon: IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.search_outlined,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: joinedParents.length,
                        itemBuilder: (context, i) {
                          final displayName =
                              joinedParents[i].getLocalizedDisplayname();

                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            child: Material(
                              borderRadius: BorderRadius.circular(
                                AppConfig.borderRadius,
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: ListTile(
                                minVerticalPadding: 0,
                                leading: Icon(
                                  Icons.adaptive.arrow_back_outlined,
                                  size: 16,
                                ),
                                title: Row(
                                  children: [
                                    Avatar(
                                      mxContent: joinedParents[i].avatar,
                                      name: displayName,
                                      size: Avatar.defaultSize / 2,
                                      borderRadius: BorderRadius.circular(
                                        AppConfig.borderRadius / 4,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(displayName)),
                                  ],
                                ),
                                onTap:
                                    () => widget.toParentSpace(
                                      joinedParents[i].id,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                      SliverList.builder(
                        itemCount: joinedRooms.length,
                        itemBuilder: (context, i) {
                          final joinedRoom = joinedRooms[i];
                          return ChatListItem();
                        },
                      ),
                    ],
                  );
                },
              ),
    );
  }
}

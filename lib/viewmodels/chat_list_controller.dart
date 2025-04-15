import 'dart:async';

import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:ai_chat_chat_client/views/screens/chat_list_view.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/show_scaffold_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class ChatList extends ConsumerStatefulWidget {
  final String? activeChat;
  final bool displayNavigationRail;

  const ChatList({
    required this.activeChat,
    this.displayNavigationRail = false,
    super.key,
  });

  @override
  ConsumerState<ChatList> createState() => ChatListController();
}

enum ActiveFilter { all, unread, dms, groups }

class ChatListController extends ConsumerState<ChatList> {
  final Logger logger = Logger('ChatListController');

  final ScrollController scrollController = ScrollController();
  final ValueNotifier<bool> scrolledToTop = ValueNotifier(false);

  final StreamController<Client> _clientStream = StreamController.broadcast();
  StreamSubscription? _intentDataStreamSubscription;
  StreamSubscription? _intentFilStreamSubscription;
  StreamSubscription? _intentUriStreamSubscription;

  bool isSearching = false;
  bool isSearchMode = false;
  Timer? _coolDownTimer;
  SearchResults? userSearchResult;
  QueryPublicRoomsResponse? roomSearchResult;
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  String? _activeSpaceId;
  ActiveFilter activeFilter = ActiveFilter.all;
  bool waitForFirstSync = false;

  String? get activeSpaceId => _activeSpaceId;
  Stream<Client> get clientStream => _clientStream.stream;
  List<Room> get filteredRooms {
    final rooms = ref.read(clientProvider).rooms;
    return rooms.where(getFilteredRoomsByActiveFilter(activeFilter)).toList();
  }

  List<Room> get spaces =>
      ref.read(clientProvider).rooms.where((r) => r.isSpace).toList();
  String? get activeChat => widget.activeChat;

  bool get displayBundles {
    final matrix = ref.read(matrixServiceProvider);
    return matrix.hasComplexBundles && matrix.accountBundles.keys.length > 1;
  }

  String? get secureActiveBundle {
    final matrix = ref.read(matrixServiceProvider);
    if (matrix.activeBundle == null ||
        !matrix.accountBundles.keys.contains(matrix.activeBundle)) {
      return matrix.accountBundles.keys.first;
    }
    return matrix.activeBundle;
  }

  bool Function(Room) getFilteredRoomsByActiveFilter(ActiveFilter filter) {
    switch (filter) {
      case ActiveFilter.all:
        return (room) => true;
      case ActiveFilter.unread:
        return (room) => room.isUnreadOrInvited;
      case ActiveFilter.dms:
        return (room) => !room.isSpace && room.isDirectChat;
      case ActiveFilter.groups:
        return (room) => !room.isSpace && !room.isDirectChat;
    }
  }

  // TODO: implement later

  // void _processIncomingSharedMedia(List<SharedMediaFile> files) {
  //   if (files.isEmpty) return;

  //   showScaffoldDialog(context: context, builder: (context) => )
  // }

  // void _initReceiveSharingIntent() {
  //   if (!PlatformInfos.isMobile) return;

  //   _intentFilStreamSubscription = ReceiveSharingIntent.instance
  //       .getMediaStream()
  //       .listen(_processIncomingSharedMedia, onError: print);
  // }

  void _onScroll() {
    final newScrolledToTop = scrollController.position.pixels <= 0;
    if (newScrolledToTop != scrolledToTop.value) {
      scrolledToTop.value = newScrolledToTop;
    }
  }

  /// Waits for the first sync to complete and handles encryption-related notifications.
  ///
  /// This function ensures the client has loaded rooms, account data, and device keys
  /// before proceeding. It also checks for unverified devices and shows appropriate
  /// notifications to the user.
  Future<void> _waitForFirstSync() async {
    logger.info('Starting first sync process');
    final client = ref.read(clientProvider);

    try {
      // Wait for essential data to be loaded from the Matrix server
      logger.fine('Waiting for rooms to load');
      await client.roomsLoading;
      logger.fine('Waiting for account data to load');
      await client.accountDataLoading;
      logger.fine('Waiting for device keys to load');
      await client.userDeviceKeysLoading;

      // If no previous batch exists, we need to wait for the first sync
      if (client.prevBatch == null) {
        logger.info('No previous batch found, waiting for first sync');
        await client.onSync.stream.first;
        logger.info('First sync completed');

        // Handle encryption key loading if encryption is enabled
        if (client.encryption?.keyManager.enabled == true) {
          final keysAreCached =
              await client.encryption?.keyManager.isCached() ?? true;
          final crossSigningIsCached =
              await client.encryption?.crossSigning.isCached() ?? true;

          if (!keysAreCached ||
              !crossSigningIsCached ||
              client.isUnknownSession) {
            logger.warning('Encryption keys not cached or unknown session');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Encryption keys need to be loaded. Please wait...',
                  ),
                  duration: Duration(seconds: 5),
                  action: SnackBarAction(label: 'OK', onPressed: () {}),
                ),
              );
            }
          }
        }
      }

      // Stop processing if the widget is no longer mounted
      if (!mounted) {
        logger.fine('Widget no longer mounted, aborting sync process');
        return;
      }

      // Update state to indicate first sync is complete
      setState(() {
        waitForFirstSync = true;
        logger.info('First sync completed, updated state');
      });

      // Check for unverified devices and notify the user if any are found
      final hasUnverifiedDevices =
          client.userDeviceKeys[client.userID]?.deviceKeys.values.any(
            (device) => !device.verified && !device.blocked,
          ) ??
          false;

      if (hasUnverifiedDevices) {
        logger.warning('Unverified devices detected for user');
        final theme = Theme.of(context);

        // Show a warning snackbar with option to verify devices
        late final ScaffoldFeatureController controller;
        controller = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 15),
            showCloseIcon: true,
            backgroundColor: theme.colorScheme.errorContainer,
            closeIconColor: theme.colorScheme.onErrorContainer,
            content: Text(
              "You have unverified devices. Please verify them.",
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            action: SnackBarAction(
              onPressed: () {
                logger.info('User requested device verification');
                controller.close();
                // TODO: reroute to device verification screen
              },
              textColor: theme.colorScheme.onErrorContainer,
              label: "Verify",
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      logger.severe('Error during first sync', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void setActiveSpace(String spaceId) async {
    final client = ref.read(clientProvider);
    final space = client.getRoomById(spaceId);
    if (space == null) {
      logger.warning('Space not found: $spaceId');
      return;
    }
    logger.fine('Setting active space to: $spaceId');
    if (space.isSpace) {
      logger.fine('Loading space: $spaceId');
      await space.postLoad();
    } else {
      logger.warning('Room is not a space: $spaceId');
      return;
    }
    setState(() {
      _activeSpaceId = spaceId;
    });
  }

  void clearActiveSpace() {
    logger.fine('Clearing active space, setting it to null');
    setState(() => _activeSpaceId = null);
  }

  void setActiveFilter(ActiveFilter filter) {
    logger.fine('Setting active filter to: $filter');
    setState(() {
      activeFilter = filter;
    });
  }

  void setActiveClient(Client client) {
    // TODO: route to rooms
    final matrix = ref.read(matrixServiceProvider);
    setState(() {
      activeFilter = ActiveFilter.all;
    });
    matrix.setActiveClient(client);
    _clientStream.add(client);
  }

  void setActiveBundle(String bundle) {
    // TODO: route to rooms

    final client = ref.read(clientProvider);
    final matrix = ref.read(matrixServiceProvider);

    setState(() {
      _activeSpaceId = null;
      matrix.activeBundle = bundle;
      if (matrix.currentBundle!.any((c) => c == client)) {
        matrix.setActiveClient(matrix.currentBundle!.first);
      }
    });
  }

  void onChatTap(Room room) async {
    if (room.membership == Membership.invite) {}

    if (room.membership == Membership.ban) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "You have been banned from this room.",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
      return;
    }

    if (room.membership == Membership.leave) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "You have left this room.",
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
      return;
    }

    if (room.isSpace) {
      setActiveSpace(room.id);
      return;
    }

    // TODO: route to chat screen
  }

  /// Performs a search operation using the current text in the searchController.
  ///
  /// Searches for both public rooms and room events that match the search query.
  /// Updates the UI state throughout the search process to provide visual feedback.
  /// Handles edge cases like Matrix room aliases and potential errors.
  Future<void> _search() async {
    final client = ref.read(clientProvider);
    final searchQuery = searchController.text.trim();

    logger.info('Starting search for query: "$searchQuery"');

    // Update UI to show search is in progress
    if (!isSearching) {
      setState(() {
        isSearching = true;
      });
    }

    try {
      // Search for public rooms matching the query
      logger.fine('Querying public rooms with filter: $searchQuery');
      final roomSearchResult = await client.queryPublicRooms(
        filter: PublicRoomQueryFilter(genericSearchTerm: searchQuery),
        limit: 25,
        includeAllNetworks: true,
      );
      logger.fine(
        'Found ${roomSearchResult.chunk.length} public rooms matching query',
      );

      // Handle special case for Matrix room aliases
      // If the search is a valid room alias but wasn't found in the initial search results,
      // try to resolve it directly
      if (searchQuery.isValidMatrixId &&
          searchQuery.sigil == '#' &&
          !roomSearchResult.chunk.any(
            (room) => room.canonicalAlias == searchQuery,
          )) {
        logger.fine(
          'Search query appears to be a room alias, attempting to resolve: $searchQuery',
        );
        try {
          final response = await client.getRoomIdByAlias(searchQuery);
          final roomId = response.roomId;
          if (roomId != null) {
            logger.fine('Successfully resolved room alias to ID: $roomId');
            roomSearchResult.chunk.add(
              PublicRoomsChunk(
                name: searchQuery,
                guestCanJoin: false,
                numJoinedMembers: 0,
                roomId: roomId,
                worldReadable: false,
                canonicalAlias: searchQuery,
              ),
            );
          }
        } catch (e) {
          logger.warning('Failed to resolve room alias: $searchQuery', e);
          // We continue the search even if alias resolution fails
        }
      }

      // Search for room events/messages matching the query
      logger.fine('Searching for room events matching query: $searchQuery');
      final userSearchResult = await client.search(
        Categories(
          roomEvents: RoomEventsCriteria(
            searchTerm: searchQuery,
            orderBy: SearchOrder.recent,
            groupings: Groupings(groupBy: [Group(key: GroupKey.roomId)]),
            filter: SearchFilter(limit: 25),
          ),
        ),
      );
      logger.fine('Room event search completed');

      // Only update the state if we're still in search mode and the widget is mounted
      if (mounted && isSearchMode) {
        setState(() {
          isSearching = false;
          this.roomSearchResult = roomSearchResult;
          this.userSearchResult = userSearchResult;
        });
        logger.info('Search completed successfully, updated UI with results');
      } else {
        logger.fine(
          'Search completed but UI update skipped (widget not mounted or search mode exited)',
        );
      }
    } catch (e, stackTrace) {
      logger.severe('Error during search operation', e, stackTrace);

      // Only show error if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Reset search state
      if (mounted && isSearchMode) {
        setState(() {
          isSearching = false;
        });
      }
    }
  }

  void onSearchEnter(String text, {bool globalSearch = true}) {
    setState(() {
      isSearchMode = true;
    });
    _coolDownTimer?.cancel();
    if (globalSearch) {
      _coolDownTimer = Timer(const Duration(milliseconds: 500), _search);
    }
  }

  void startSearch() {
    if (!isSearchMode) {
      setState(() {
        isSearchMode = true;
      });
    }
    searchFocusNode.requestFocus();
    _coolDownTimer?.cancel();
    _coolDownTimer = Timer(const Duration(milliseconds: 500), _search);
  }

  void cancelSearch({bool unfocus = true}) {
    setState(() {
      searchController.clear();
      isSearchMode = false;
      roomSearchResult = userSearchResult = null;
      isSearching = false;
    });
    if (unfocus) searchFocusNode.unfocus();
  }

  void resetActiveBundle() {
    WidgetsBinding.instance.addPostFrameCallback((timestamp) {
      final matrix = ref.read(matrixServiceProvider);
      matrix.activeBundle = null;
    });
  }

  Future<void> dehydrate() {
    final matrix = ref.read(matrixServiceProvider);
    return matrix.dehydrateAction(context);
  }

  @override
  void initState() {
    scrollController.addListener(_onScroll);
    _waitForFirstSync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // TODO: setup background push notifications

      SystemChrome.setSystemUIOverlayStyle(
        Theme.of(context).appBarTheme.systemOverlayStyle!,
      );
    });

    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    _clientStream.close();

    _intentDataStreamSubscription?.cancel();
    _intentFilStreamSubscription?.cancel();
    _intentUriStreamSubscription?.cancel();

    searchController.dispose();
    searchFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatListView(this);
}

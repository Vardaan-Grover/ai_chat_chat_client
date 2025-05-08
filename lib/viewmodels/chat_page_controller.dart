import 'dart:async';
import 'dart:io';

import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:ai_chat_chat_client/config/setting_keys.dart';
import 'package:ai_chat_chat_client/services/matrix/account_bundle.dart';
import 'package:ai_chat_chat_client/services/matrix/event_extension.dart';
import 'package:ai_chat_chat_client/services/matrix/filtered_timeline_extension.dart';
import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:ai_chat_chat_client/services/providers.dart';
import 'package:ai_chat_chat_client/services/theme/themes.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/future_loading_dialog.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:record/record.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends ConsumerStatefulWidget {
  final Room room;
  final String? eventId;

  const ChatPage({required this.room, this.eventId, super.key});

  @override
  ConsumerState<ChatPage> createState() => ChatPageController();
}

class ChatPageController extends ConsumerState<ChatPage>
    with WidgetsBindingObserver {
  final Logger logger = Logger('ChatPageController');

  Room get room => sendingClient.getRoomById(roomId) ?? widget.room;

  late Client sendingClient;

  Timeline? timeline;

  late final String readMarkerEventId;

  String get roomId => widget.room.id;

  final AutoScrollController scrollController = AutoScrollController();

  late final FocusNode inputFocus;

  Timer? typingCoolDown;
  Timer? typingTimeout;
  bool currentlyTyping = false;
  bool dragging = false;

  void onDragEntered(_) => setState(() => dragging = true);
  void onDragExited(_) => setState(() => dragging = false);

  // TODO: Implement drag and drop functionality
  void onDragDone(DropDoneDetails details) async {
    setState(() => dragging = false);
    if (details.files.isEmpty) return;

    await showAdaptiveDialog(context: context, builder: (c) => Placeholder());
  }

  bool get canSaveSelectedEvent =>
      selectedEvents.length == 1 &&
      {
        MessageTypes.Video,
        MessageTypes.Image,
        MessageTypes.Sticker,
        MessageTypes.Audio,
        MessageTypes.File,
      }.contains(selectedEvents.single.messageType);

  void saveSelectedEvent(context) => selectedEvents.single.saveFile(context);

  List<Event> selectedEvents = [];

  final Set<String> unfolded = {};

  Event? replyEvent;
  Event? editEvent;

  bool _scrolledUp = false;

  bool get showScrollDownButton =>
      _scrolledUp || timeline?.allowNewEvent == false;

  bool get selectMode => selectedEvents.isNotEmpty;

  final int _loadHistoryCount = 50;

  String pendingText = '';

  void recreateChat() async {
    final room = this.room;
    final userId = room.directChatMatrixID;

    if (userId == null) {
      logger.severe(
        'Try to recreate a room with is not a DM room. This should not be possible from the UI!',
      );
      throw Exception(
        'Try to recreate a room with is not a DM room. This should not be possible from the UI!',
      );
    }

    await showFutureLoadingDialog(
      context: context,
      future: () => room.invite(userId),
    );
  }

  void requestChatHistory([_]) async {
    logger.info('Requesting chat history');
    await timeline?.requestHistory(historyCount: _loadHistoryCount);
  }

  void requestChatFuture() async {
    final timeline = this.timeline;
    if (timeline == null) {
      logger.warning('Timeline is null, cannot request chat future');
      return;
    }
    logger.info('Requesting chat future');
    final mostRecentEventId = timeline.events.first.eventId;
    await timeline.requestFuture(historyCount: _loadHistoryCount);
    setReadMarker(eventId: mostRecentEventId);
  }

  void _updateScrollController() {
    if (!mounted) return;

    if (!scrollController.hasClients) return;
    if (timeline?.allowNewEvent == false ||
        scrollController.position.pixels > 0 && _scrolledUp == false) {
      setState(() => _scrolledUp = true);
    } else if (scrollController.position.pixels <= 0 && _scrolledUp == true) {
      setState(() => _scrolledUp = false);
      setReadMarker();
    }

    if (scrollController.position.pixels == 0 ||
        scrollController.position.pixels == 64) {
      requestChatFuture();
    }
  }

  // TODO: Implement share items functionality
  void _shareItems([_]) {}

  void _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('draft_$roomId');
    if (draft != null && draft.isNotEmpty) {
      sendController.text = draft;
    }
  }

  KeyEventResult _shiftEnterKeyHandling(FocusNode node, KeyEvent evt) {
    if (evt is KeyDownEvent && evt.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        sendController.text += '\n';
        return KeyEventResult.handled;
      } else {
        sendMessage();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void initState() {
    inputFocus = FocusNode(
      onKeyEvent:
          (AppConfig.sendOnEnter ?? !PlatformInfos.isMobile)
              ? _shiftEnterKeyHandling
              : null,
    );

    scrollController.addListener(_updateScrollController);

    _loadDraft();
    WidgetsBinding.instance.addPostFrameCallback(_shareItems);

    _displayChatDetailsColumn = ValueNotifier(
      AppSettings.displayChatDetailsColumn.getItem(
        ref.read(sharedPreferencesProvider),
      ),
    );

    sendingClient = ref.read(clientProvider);
    readMarkerEventId = room.hasNewMessages ? room.fullyRead : '';
    WidgetsBinding.instance.addObserver(this);
    _tryLoadTimeline();

    super.initState();
  }

  void _tryLoadTimeline() async {
    final initialEventId = widget.eventId;
    loadTimelineFuture = _getTimeline();

    try {
      await loadTimelineFuture;
      if (initialEventId != null) scrollToEventId(initialEventId);

      var readMarkerEventIndex =
          readMarkerEventId.isEmpty
              ? -1
              : timeline!.events
                  .filterByVisibleInGui(exceptionEventId: readMarkerEventId)
                  .indexWhere((e) => e.eventId == readMarkerEventId);

      if (readMarkerEventId.isNotEmpty && readMarkerEventIndex == -1) {
        await timeline?.requestHistory(historyCount: _loadHistoryCount);
        readMarkerEventIndex = timeline!.events
            .filterByVisibleInGui(exceptionEventId: readMarkerEventId)
            .indexWhere((e) => e.eventId == readMarkerEventId);
      }

      if (readMarkerEventIndex > 1) {
        logger.info('Scrolling to visible event: $readMarkerEventId');
        scrollToEventId(readMarkerEventId, highlightEvent: false);
        return;
      } else if (readMarkerEventId.isNotEmpty && readMarkerEventIndex == -1) {
        logger.warning('Read marker event not found: $readMarkerEventId');
        _showScrollUpMaterialBanner(readMarkerEventId);
      }

      setReadMarker();
    } catch (e, s) {
      logger.severe('Unable to load timeline', e, s);
      rethrow;
    }
  }

  String? scrollUpBannerEventId;

  void discardsScrollUpBannerEventId() =>
      setState(() => scrollUpBannerEventId = null);
  void _showScrollUpMaterialBanner(String eventId) =>
      setState(() => scrollUpBannerEventId = eventId);

  void updateView() {
    if (!mounted) return;
    setReadMarker();
    setState(() {});
  }

  Future<void>? loadTimelineFuture;

  int? animateInEventIndex;

  void onInsert(int i) {
    animateInEventIndex = i;
  }

  Future<void> _getTimeline({String? eventContextId}) async {
    final client = ref.read(clientProvider);

    await client.roomsLoading;
    await client.accountDataLoading;

    if (eventContextId != null &&
        (!eventContextId.isValidMatrixId || eventContextId.sigil != '\$')) {
      eventContextId = null;
    }

    try {
      timeline?.cancelSubscriptions();
      timeline = await room.getTimeline(
        onUpdate: updateView,
        eventContextId: eventContextId,
        onInsert: onInsert,
      );
    } catch (e, s) {
      logger.severe(
        'Unable to load timeline on event ID: $eventContextId',
        e,
        s,
      );
      if (!mounted) return;
      timeline = await room.getTimeline(
        onUpdate: updateView,
        onInsert: onInsert,
      );
      if (!mounted) return;
      if (e is TimeoutException || e is IOException) {
        _showScrollUpMaterialBanner(eventContextId!);
      }
    }
    timeline?.requestKeys(onlineKeyBackupOnly: false);
    if (room.markedUnread) room.markUnread(false);
  }

  String? scrollToEventIdMarker;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    setReadMarker();
  }

  Future<void>? _setReadMarkerFuture;

  void setReadMarker({String? eventId}) {
    if (_setReadMarkerFuture != null) return;
    if (_scrolledUp) return;
    if (scrollUpBannerEventId != null) return;

    if (eventId == null &&
        !room.hasNewMessages &&
        room.notificationCount == 0) {
      return;
    }

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final timeline = this.timeline;
    if (timeline == null || timeline.events.isEmpty) return;

    logger.info('Set read marker: $eventId');

    _setReadMarkerFuture = timeline
        .setReadMarker(
          eventId: eventId,
          public: AppConfig.sendPublicReadReceipts,
        )
        .then((_) {
          _setReadMarkerFuture = null;
        });

    if (eventId == null || eventId == timeline.room.lastEvent?.eventId) {
      // TODO: Implement cancel notification background task
    }
  }

  @override
  void dispose() {
    timeline?.cancelSubscriptions();
    timeline = null;
    inputFocus.dispose();
    sendController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  TextEditingController sendController = TextEditingController();

  void setSendingClient(Client c) {
    // first cancel typing with the old sending client
    if (currentlyTyping) {
      // no need to have the setting typing to false be blocking
      typingCoolDown?.cancel();
      typingCoolDown = null;
      room.setTyping(false);
      currentlyTyping = false;
    }
    // then cancel the old timeline
    // fixes bug with read reciepts and quick switching
    loadTimelineFuture = _getTimeline(
      eventContextId: room.fullyRead,
    ).onError((e, s) => logger.severe('Unable to load timeline', e));

    // then set the new sending client
    setState(() => sendingClient = c);
  }

  void setActiveClient(Client c) {
    ref.read(matrixServiceProvider).setActiveClient(c);
  }

  Future<void> sendMessage() async {
    if (sendController.text.trim().isEmpty) return;
    _storeInputTimeoutTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('draft_$roomId');

    room.sendTextEvent(
      sendController.text,
      inReplyTo: replyEvent,
      editEventId: editEvent?.eventId,
    );

    sendController.value = TextEditingValue(
      text: pendingText,
      selection: const TextSelection.collapsed(offset: 0),
    );

    setState(() {
      sendController.text = pendingText;
      _inputTextIsEmpty = pendingText.isEmpty;
      replyEvent = null;
      editEvent = null;
      pendingText = '';
    });
  }

  void sendFileAction() {}
  void sendImageFromClipboard() {}

  void openCameraAction() async {
    FocusScope.of(context).requestFocus(FocusNode());
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null) return;

    // TODO: Implement send file action
  }

  void openVideoCameraAction() async {
    FocusScope.of(context).requestFocus(FocusNode());
    final file = await ImagePicker().pickVideo(source: ImageSource.camera);

    if (file == null) return;

    // TODO: Implement send file action
  }

  void voiceMessageAction() async {
    // final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (PlatformInfos.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < 19) {
        if (mounted) {
          await showOkAlertDialog(
            context: context,
            title: 'Unsupported Android version',
            message: 'This feature requires a newer Android version.',
            okLabel: 'Close',
          );
          return;
        }
      }
    }

    if (await AudioRecorder().hasPermission() == false) return;
    // TODO: Implement voice message action
  }

  // TODO: Implement send location action
  void sendLocationAction() async {}

  String _getSelectedEventString() {
    var copyString = '';
    if (selectedEvents.length == 1) {
      return selectedEvents.first
          .getDisplayEvent(timeline!)
          .calcUnlocalizedBody();
    }

    for (final event in selectedEvents) {
      if (copyString.isNotEmpty) copyString += '\n\n';
      copyString += event.getDisplayEvent(timeline!).calcUnlocalizedBody();
    }

    return copyString;
  }

  void copyEventsAction() async {
    Clipboard.setData(ClipboardData(text: _getSelectedEventString()));
    setState(() => selectedEvents.clear());
  }

  List<Client?> get currentRoomBundle {
    final clients = ref.read(matrixServiceProvider).currentBundle!;
    clients.removeWhere((c) => c!.getRoomById(roomId) == null);
    return clients;
  }

  // TODO: Implement forward events action
  void forwardEventsAction() async {}

  void sendAgainAction() {
    final event = selectedEvents.first;
    if (event.status.isError) {
      event.sendAgain();
    }
    final allEditEvents = event
        .aggregatedEvents(timeline!, RelationshipTypes.edit)
        .where((e) => e.status.isError);
    for (final e in allEditEvents) {
      e.sendAgain();
    }
    setState(() => selectedEvents.clear());
  }

  void replyAction({Event? replyTo}) {
    setState(() {
      replyEvent = replyTo ?? selectedEvents.first;
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  void scrollToEventId(String eventId, {bool highlightEvent = true}) async {
    final foundEvent = timeline!.events.firstWhereOrNull(
      (event) => event.eventId == eventId,
    );

    final eventIndex =
        foundEvent == null
            ? -1
            : timeline!.events
                .filterByVisibleInGui(exceptionEventId: eventId)
                .indexOf(foundEvent);

    if (eventIndex == -1) {
      setState(() {
        timeline = null;
        _scrolledUp = false;
        loadTimelineFuture = _getTimeline(
          eventContextId: eventId,
        ).onError((e, s) => logger.severe('Unable to load timeline', e));
      });
      await loadTimelineFuture;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        scrollToEventId(eventId);
      });
      return;
    }
    if (highlightEvent) {
      setState(() {
        scrollToEventIdMarker = eventId;
      });
    }
    await scrollController.scrollToIndex(
      eventIndex + 1,
      duration: AIChatChatThemes.animationDuration,
      preferPosition: AutoScrollPosition.middle,
    );
    _updateScrollController();
  }

  void scrollDown() async {
    if (!timeline!.allowNewEvent) {
      setState(() {
        timeline = null;
        _scrolledUp = false;
        loadTimelineFuture = _getTimeline().onError(
          (e, s) => logger.severe('Unable to load timeline', e),
        );
      });
      await loadTimelineFuture;
    }
    scrollController.jumpTo(0);
  }

  // TODO: Implement emoji functionality
  void onEmojiSelected() {}
  void sendEmojiReaction() {}
  void typeEmoji() {}
  void emojiPickerBackspace() {}
  void pickEmojiReactionAction() {}
  void sendEmojiAction() {}

  void clearSelectedEvents() {
    setState(() {
      selectedEvents.clear();
    });
  }

  void clearSingleSelectedEvent() {
    if (selectedEvents.length <= 1) {
      clearSelectedEvents();
    }
  }

  void editSelectedEventAction() {
    final client = currentRoomBundle.firstWhere(
      (cl) => selectedEvents.first.senderId == cl!.userID,
      orElse: () => null,
    );
    if (client == null) {
      return;
    }
    setSendingClient(client);
    setState(() {
      pendingText = sendController.text;
      editEvent = selectedEvents.first;
      sendController.text = editEvent!
          .getDisplayEvent(timeline!)
          .calcUnlocalizedBody(hideReply: true);
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  void goToNewRoomAction() async {
    final result = await showFutureLoadingDialog(
      context: context,
      future:
          () => room.client.joinRoomById(
            room
                .getState(EventTypes.RoomTombstone)!
                .parsedTombstoneContent
                .replacementRoom,
          ),
    );
    if (result.error != null) return;
    if (!mounted) return;
    context.go('/rooms/${result.result!}');

    await showFutureLoadingDialog(context: context, future: room.leave);
  }

  void onSelectMessage(Event event) {
    if (!event.redacted) {
      if (selectedEvents.contains(event)) {
        setState(() => selectedEvents.remove(event));
      } else {
        setState(() => selectedEvents.add(event));
      }
      selectedEvents.sort(
        (a, b) => a.originServerTs.compareTo(b.originServerTs),
      );
    }
  }

  int? findChildIndexCallback(Key key, Map<String, int> thisEventsKeyMap) {
    // this method is called very often. As such, it has to be optimized for speed.
    if (key is! ValueKey) {
      return null;
    }
    final eventId = key.value;
    if (eventId is! String) {
      return null;
    }
    // first fetch the last index the event was at
    final index = thisEventsKeyMap[eventId];
    if (index == null) {
      return null;
    }
    // we need to +1 as 0 is the typing thing at the bottom
    return index + 1;
  }

  void onInputBarSubmitted(_) {
    sendMessage();
    FocusScope.of(context).requestFocus(inputFocus);
  }

  void onAddPopupMenuButtonSelected(String choice) {
    if (choice == 'file') {
      sendFileAction();
    }
    if (choice == 'image') {
      // sendFileAction(type: FileSelectorType.images);
    }
    if (choice == 'video') {
      // sendFileAction(type: FileSelectorType.videos);
    }
    if (choice == 'camera') {
      openCameraAction();
    }
    if (choice == 'camera-video') {
      openVideoCameraAction();
    }
    if (choice == 'location') {
      sendLocationAction();
    }
  }

  void pinEvent() {
    final pinnedEventIds = room.pinnedEventIds;
    final selectedEventIds = selectedEvents.map((e) => e.eventId).toSet();
    final unpin =
        selectedEventIds.length == 1 &&
        pinnedEventIds.contains(selectedEventIds.single);
    if (unpin) {
      pinnedEventIds.removeWhere(selectedEventIds.contains);
    } else {
      pinnedEventIds.addAll(selectedEventIds);
    }
    showFutureLoadingDialog(
      context: context,
      future: () => room.setPinnedEvents(pinnedEventIds),
    );
  }

  unpinEvent(String eventId) async {
    final response = await showOkCancelAlertDialog(
      context: context,
      title: 'Unpin event',
      message: 'Are you sure you want to unpin this event?',
      okLabel: 'Unpin',
      cancelLabel: 'Cancel',
    );
    if (response == OkCancelResult.ok) {
      final events =
          room.pinnedEventIds..removeWhere((oldEvent) => oldEvent == eventId);
      if (mounted) {
        showFutureLoadingDialog(
          context: context,
          future: () => room.setPinnedEvents(events),
        );
      }
    }
  }

  Timer? _storeInputTimeoutTimer;
  static const Duration _storeInputTimeout = Duration(milliseconds: 500);

  void onInputBarChanged(String text) {
    if (_inputTextIsEmpty != text.isEmpty) {
      setState(() {
        _inputTextIsEmpty = text.isEmpty;
      });
    }

    _storeInputTimeoutTimer?.cancel();
    _storeInputTimeoutTimer = Timer(_storeInputTimeout, () async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('draft_$roomId', text);
    });

    if (text.endsWith(' ') &&
        ref.read(matrixServiceProvider).hasComplexBundles) {
      final clients = currentRoomBundle;
      for (final client in clients) {
        final prefix = client!.sendPrefix;
        if ((prefix.isNotEmpty) &&
            text.toLowerCase() == '${prefix.toLowerCase()} ') {
          setSendingClient(client);
          setState(() {
            sendController.clear();
          });
          return;
        }
      }
    }

    if (AppConfig.sendTypingNotifications) {
      typingCoolDown?.cancel();
      typingCoolDown = Timer(const Duration(seconds: 2), () {
        typingCoolDown = null;
        currentlyTyping = false;
        room.setTyping(false);
      });
      typingTimeout ??= Timer(const Duration(seconds: 30), () {
        typingTimeout = null;
        currentlyTyping = false;
      });

      if (!currentlyTyping) {
        currentlyTyping = true;
        room.setTyping(
          true,
          timeout: const Duration(seconds: 30).inMilliseconds,
        );
      }
    }
  }

  bool _inputTextIsEmpty = true;

  bool get isArchived =>
      {Membership.leave, Membership.ban}.contains(room.membership);

  void cancelReplyEventAction() => setState(() {
    if (editEvent != null) {
      sendController.text = pendingText;
      pendingText = '';
    }
    replyEvent = null;
    editEvent = null;
  });

  late final ValueNotifier<bool> _displayChatDetailsColumn;

  void toggleDisplayChatDetailsColumn() async {
    await AppSettings.displayChatDetailsColumn.setItem(
      ref.read(sharedPreferencesProvider),
      !_displayChatDetailsColumn.value,
    );
    _displayChatDetailsColumn.value = !_displayChatDetailsColumn.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Expanded(child: ChatView(this)),
        // AnimatedSize(
        //   duration: AIChatChatThemes.animationDuration,
        //   curve: AIChatChatThemes.animationCurve,
        //   child: ValueListenableBuilder(
        //     valueListenable: _displayChatDetailsColumn,
        //     builder: (context, displayChatDetailsColumn, _) {
        //       if (!AIChatChatThemes.isThreeColumnMode(context) ||
        //           room.membership != Membership.join ||
        //           !displayChatDetailsColumn) {
        //         return const SizedBox(height: double.infinity, width: 0);
        //       }
        //       return Container(
        //         width: AIChatChatThemes.columnWidth,
        //         clipBehavior: Clip.hardEdge,
        //         decoration: BoxDecoration(
        //           border: Border(
        //             left: BorderSide(width: 1, color: theme.dividerColor),
        //           ),
        //         ),
        //         child: ChatDetails(
        //           roomId: roomId,
        //           embeddedCloseButton: IconButton(
        //             icon: const Icon(Icons.close),
        //             onPressed: toggleDisplayChatDetailsColumn,
        //           ),
        //         ),
        //       );
        //     },
        //   ),
        // ),
      ],
    );
  }
}

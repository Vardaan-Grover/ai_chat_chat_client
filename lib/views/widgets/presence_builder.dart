import 'dart:async';

import 'package:ai_chat_chat_client/services/matrix/matrix_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

/// A widget that builds UI based on Matrix user presence state.
///
/// This widget fetches and subscribes to presence updates for a specific Matrix user,
/// then rebuilds the UI whenever that user's presence changes.
class PresenceBuilder extends ConsumerStatefulWidget {
  /// Builder function that constructs the widget tree based on the current presence.
  final Widget Function(BuildContext context, CachedPresence? presence) builder;
  
  /// The Matrix user ID to track presence for.
  final String? userId;
  
  /// Optional Matrix client instance. If not provided, the default client from
  /// the provider will be used.
  final Client? client;

  const PresenceBuilder({
    required this.builder,
    this.userId,
    this.client,
    super.key,
  });

  @override
  ConsumerState<PresenceBuilder> createState() => _PresenceBuilderState();
}

class _PresenceBuilderState extends ConsumerState<PresenceBuilder> {
  // Logger for this widget
  static final _logger = Logger('PresenceBuilder');
  
  // Current presence state
  CachedPresence? _presence;
  
  // Subscription to presence updates
  StreamSubscription<CachedPresence>? _sub;

  /// Updates the presence state and triggers a rebuild.
  void _updatePresence(CachedPresence? presence) {
    _logger.fine('Presence updated for ${presence?.userid}: ${presence?.presence}');
    
    if (!mounted) return;
    
    setState(() {
      _presence = presence;
    });
  }

  @override
  void initState() {
    super.initState();
    _setupPresenceTracking();
  }
  
  /// Sets up the initial presence fetch and ongoing tracking.
  void _setupPresenceTracking() {
    final userId = widget.userId;
    if (userId == null) {
      _logger.warning('No userId provided, presence tracking disabled');
      return;
    }
    
    final Client client = widget.client ?? ref.read(clientProvider);
    
    _logger.info('Starting presence tracking for user: $userId');
    
    // Initial presence fetch
    client.fetchCurrentPresence(userId).then(_updatePresence).catchError((error) {
      _logger.warning('Error fetching initial presence for $userId: $error');
    });
    
    // Subscribe to presence updates
    _sub = client.onPresenceChanged.stream
        .where((presence) => presence.userid == userId)
        .listen(
          _updatePresence,
          onError: (error) => _logger.severe('Error in presence stream for $userId: $error'),
        );
  }

  @override
  void didUpdateWidget(PresenceBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the userId changed, we need to reset our tracking
    if (oldWidget.userId != widget.userId || oldWidget.client != widget.client) {
      _logger.info('UserId or client changed, resetting presence tracking');
      _sub?.cancel();
      _presence = null;
      _setupPresenceTracking();
    }
  }

  @override
  void dispose() {
    // Clean up subscription to avoid memory leaks
    if (_sub != null) {
      _logger.fine('Cancelling presence subscription for ${widget.userId}');
      _sub!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _presence);
}

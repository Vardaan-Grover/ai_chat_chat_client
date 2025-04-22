import 'package:ai_chat_chat_client/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

extension RoomStatusExtension on Room {
  /// Generates a user-friendly text indicating who is typing in the room.
  /// 
  /// This function formats typing indicators based on:
  /// - The number of users typing
  /// - Whether user names should be hidden (based on AppConfig)
  /// - Direct chat status
  /// 
  /// @param context The BuildContext for localization (if needed)
  /// @return A formatted string describing who is typing
  String getTypingText(BuildContext context) {
    // Get typing users and remove the current client user
    final typingUsers = this.typingUsers.toList();
    typingUsers.removeWhere((User u) => u.id == client.userID);
    
    // If no one is typing, return empty string
    if (typingUsers.isEmpty) {
      return '';
    }
    
    String typingText;
    
    // Handle different cases based on AppConfig and number of typing users
    if (AppConfig.hideTypingUsernames) {
      // When usernames are hidden for privacy
      typingText = typingUsers.length == 1 && typingUsers.first.id == directChatMatrixID
          ? 'is typing...'
          : '${typingUsers.length} people are typing...';
    } else {
      // When usernames can be displayed
      if (typingUsers.length == 1) {
        // Single user typing
        typingText = typingUsers.first.id == directChatMatrixID
            ? 'is typing...'
            : '${typingUsers.first.calcDisplayname()} is typing...';
      } else if (typingUsers.length == 2) {
        // Two users typing
        typingText = '${typingUsers.first.calcDisplayname()} and '
                     '${typingUsers[1].calcDisplayname()} are typing...';
      } else {
        // More than two users typing
        typingText = '${typingUsers.first.calcDisplayname()} and '
                     '${(typingUsers.length - 1)} others are typing...';
      }
    }

    return typingText;
  }

  /// Gets a list of users who have seen a specific event in the timeline.
  ///
  /// This function retrieves all users who have read receipts for events up to
  /// and including the specified event. If no specific [eventId] is provided,
  /// it defaults to the first event in the timeline.
  ///
  /// Parameters:
  ///   [timeline] - The timeline containing events and read receipts
  ///   [eventId] - Optional. The ID of the event to check receipts up to.
  ///               Defaults to the first event in the timeline if not specified.
  ///
  /// Returns:
  ///   A list of [User] objects who have seen the event, excluding the current user
  ///   and the sender of the first event in the timeline.
  ///
  /// Note: The function iterates through timeline events until it finds the specified event
  /// and collects all receipt users along the way.
  List<User> getSeenByUsers(Timeline timeline, {String? eventId}) {
    if (timeline.events.isEmpty) return [];
    eventId ??= timeline.events.first.eventId;

    final lastReceipts = <User>{};

    // now we iterate the timeline events until we hit the first rendered event
    for (final event in timeline.events) {
      lastReceipts.addAll(event.receipts.map((r) => r.user));
      if (event.eventId == eventId) {
        break;
      }
    }

    lastReceipts.removeWhere(
      (user) =>
          user.id == client.userID || user.id == timeline.events.first.senderId,
    );

    return lastReceipts.toList();
  }
}

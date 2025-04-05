import 'dart:convert';

import 'package:ai_chat_chat_client/models/matrix/matrix_event_entity.dart';
import 'package:ai_chat_chat_client/models/matrix/matrix_session_entity.dart';
import 'package:ai_chat_chat_client/models/matrix/matrix_room_entity.dart';
import 'package:ai_chat_chat_client/objectbox.g.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

class ObjectBoxService implements DatabaseApi {
  static final Logger logger = Logger('ObjectBoxService');
  late Store store;

  late final Box<MatrixSessionData> matrixSessionBox;
  late final Box<MatrixEventEntity> matrixEventBox;
  late final Box<MatrixRoomEntity> matrixRoomBox;

  ObjectBoxService(String dbName) {
    store = Store(getObjectBoxModel(), directory: dbName);
    matrixSessionBox = store.box<MatrixSessionData>();
    matrixEventBox = store.box<MatrixEventEntity>();
    matrixRoomBox = store.box<MatrixRoomEntity>();
  }

  Future<void> open() async {
    logger.info("ObjectBox Database opened");
  }

  @override
  Future<void> close() async {
    store.close();
    logger.info("ObjectBox Database closed");
  }

  @override
  Future<void> clearCache() async {
    logger.info("Clearing ObjectBox Database (Rooms & Events)");

    final numDeletedEvents = matrixEventBox.removeAll();
    final numDeletedRooms = matrixRoomBox.removeAll();

    logger.info("Deleted $numDeletedEvents events and $numDeletedRooms rooms");
  }

  @override
  Future<void> clear() async {
    logger.info("Clearing ObjectBox Database");

    final numDeletedSessions = matrixSessionBox.removeAll();
    final numDeletedEvents = matrixEventBox.removeAll();
    final numDeletedRooms = matrixRoomBox.removeAll();

    logger.info(
      "Deleted $numDeletedSessions sessions, $numDeletedEvents events and $numDeletedRooms rooms",
    );
  }

  @override
  Future<Map<String, dynamic>?> getClient(String name) async {
    final query =
        matrixSessionBox
            .query(MatrixSessionData_.clientName.equals(name))
            .build();
    final sessions = query.find();
    query.close();

    final result = sessions.map((session) => session.toJson()).toList();

    logger.fine('Retrieved ${result.length} sessions for client: $name');

    if (result.isNotEmpty) {
      return result.first;
    } else {
      logger.warning('No session found for client: $name');
      return null;
    }
  }

  @override
  Future<void> updateClient(
    String homeserverUrl,
    String token,
    DateTime? tokenExpiresAt,
    String? refreshToken,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  ) async {
    logger.fine('Updating client: $userId');

    try {
      // First, check if client exists
      final query =
          matrixSessionBox
              .query(MatrixSessionData_.userId.equals(userId))
              .build();
      final clients = query.find();
      query.close();

      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (clients.isEmpty) {
        // Create new client record if it doesn't exist
        if (deviceId == null || deviceName == null) {
          throw Exception('Cannot create new client without full credentials');
        }

        final newClient = MatrixSessionData(
          userId: userId,
          homeserverUrl: homeserverUrl,
          deviceId: deviceId,
          deviceName: deviceName,
          lastUpdate: currentTime,
          token: token,
          refreshToken: refreshToken,
          prevBatch: prevBatch?.toString(),
          olmAccount: olmAccount,
        );

        matrixSessionBox.put(newClient);
      } else {
        // Update existing client
        final client = clients.first;

        // Update only provided fields
        client.userId = userId;
        client.homeserverUrl = homeserverUrl;
        client.token = token;
        if (deviceId != null) client.deviceId = deviceId;
        if (deviceName != null) client.deviceName = deviceName;
        if (refreshToken != null) client.refreshToken = refreshToken;
        if (prevBatch != null) client.prevBatch = prevBatch.toString();
        if (olmAccount != null) client.olmAccount = olmAccount;

        // Always update timestamp
        client.lastUpdate = currentTime;

        matrixSessionBox.put(client);

        logger.fine('Updated client: $userId, lastUpdate: $currentTime');
      }
    } catch (e) {
      logger.severe('Error updating client:', e);
    }
  }

  @override
  Future<int> insertClient(
    String name,
    String homeserverUrl,
    String token,
    DateTime? tokenExpiresAt,
    String? refreshToken,
    String userId,
    String? deviceId,
    String? deviceName,
    String? prevBatch,
    String? olmAccount,
  ) async {
    logger.fine('Inserting new client: $name ($userId)');

    try {
      // Check if we already have this client
      final query =
          matrixSessionBox
              .query(MatrixSessionData_.userId.equals(userId))
              .build();
      final existingSessions = query.find();
      query.close();

      if (existingSessions.isNotEmpty) {
        logger.info('Client already exists, updating instead user id: $userId');
        // Update the existing client data
        await updateClient(
          homeserverUrl,
          token,
          tokenExpiresAt,
          refreshToken,
          userId,
          deviceId,
          deviceName,
          prevBatch,
          olmAccount,
        );
        return existingSessions.first.id;
      }

      // Create a new client entry
      if (deviceId == null || deviceName == null) {
        throw Exception('Cannot insert client without device ID and name');
      }

      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // Create the session entity
      final session = MatrixSessionData(
        userId: userId,
        homeserverUrl: homeserverUrl,
        deviceId: deviceId,
        deviceName: deviceName,
        lastUpdate: currentTime,
        token: token,
        tokenExpiresAt: tokenExpiresAt?.millisecondsSinceEpoch,
        refreshToken: refreshToken,
        prevBatch: prevBatch,
        olmAccount: olmAccount,
      );

      // Store in the database
      final id = matrixSessionBox.put(session);
      logger.info('Inserted new client: $name ($userId) with ID: $id');

      return id;
    } catch (e, stackTrace) {
      logger.severe('Failed to insert client: $name', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<Room>> getRoomList(Client client) async {
    logger.fine('Getting room list from ObjectBox database');

    try {
      // Create a container for our results
      final rooms = <String, Room>{};

      // 1. First, query all rooms from ObjectBox
      final roomEntities = matrixRoomBox.getAll();

      // 2. Convert room entities to Room objects
      for (final roomEntity in roomEntities) {
        // Create basic room object from our stored data
        final roomInfo = {
          'id': roomEntity.roomId,
          'name': roomEntity.name,
          'avatar_url': roomEntity.avatarUrl,
          'direct': roomEntity.isDirect,
          'last_message_timestamp': roomEntity.lastMessageTimestamp,
        };

        // Create a Room instance using Matrix SDK's fromJson constructor
        final room = Room.fromJson(roomInfo, client);
        rooms[roomEntity.roomId] = room;

        logger.finer('Loaded room: ${roomEntity.roomId} (${roomEntity.name})');
      }

      // 3. Now get the room states (important for membership, permissions, etc.)
      // For simplicity, we'll get the last message for each room
      for (final roomId in rooms.keys) {
        final query =
            matrixEventBox
                .query(MatrixEventEntity_.roomId.equals(roomId))
                .order(
                  MatrixEventEntity_.originServerTs,
                  flags: Order.descending,
                )
                .build();
        query.limit = 20; // Get last 20 messages to find state events
        final events = query.find();
        query.close();

        for (final eventEntity in events) {
          try {
            // Convert stored content string to Map
            final content = jsonDecode(eventEntity.content);

            // Create event object
            final eventJson = {
              'event_id': eventEntity.eventId,
              'sender': eventEntity.senderId,
              'origin_server_ts': eventEntity.originServerTs,
              'type': eventEntity.type,
              'content': content,
              'room_id': roomId,
            };

            // If it's a state event, apply it to the room
            if (_isStateEvent(eventEntity.type)) {
              final stateEvent = Event.fromJson(eventJson, rooms[roomId]!);
              rooms[roomId]!.setState(stateEvent);
            }

            // If we find a room name or avatar event, update room properties
            if (eventEntity.type == EventTypes.RoomName) {
              rooms[roomId]!.setName(content['name'])
            } else if (eventEntity.type == EventTypes.RoomAvatar) {
              rooms[roomId]!.avatarUrl = content['url'];
            }
          } catch (e) {
            logger.warning('Error processing event in room $roomId: $e');
            continue;
          }
        }

        // 4. Get room members (most important ones)
        // In a full implementation, you would have a separate MatrixRoomMemberEntity
        // For now we're using the events to get member info
        final memberQuery =
            matrixEventBox
                .query(
                  MatrixEventEntity_.roomId.equals(roomId) &
                      MatrixEventEntity_.type.equals(EventTypes.RoomMember),
                )
                .build();
        final memberEvents = memberQuery.find();
        memberQuery.close();

        for (final memberEvent in memberEvents) {
          try {
            final content = jsonDecode(memberEvent.content);
            final memberEventJson = {
              'event_id': memberEvent.eventId,
              'sender': memberEvent.senderId,
              'origin_server_ts': memberEvent.originServerTs,
              'type': memberEvent.type,
              'content': content,
              'room_id': roomId,
              'state_key': content['state_key'] ?? memberEvent.senderId,
            };

            final event = Event.fromJson(memberEventJson, rooms[roomId]!);
            rooms[roomId]!.setState(event);
          } catch (e) {
            logger.warning('Error processing member event: $e');
            continue;
          }
        }

        // 5. Get room account data (like read markers, tags)
        // This would require an additional entity type in a full implementation
        // Skipping for this basic version
      }

      logger.info('Loaded ${rooms.length} rooms from database');
      return rooms.values.toList();
    } catch (e, stackTrace) {
      logger.severe('Error retrieving room list', e, stackTrace);
      // Return empty list instead of throwing to prevent UI crashes
      return [];
    }
  }

  // Helper method to identify state events
  bool _isStateEvent(String eventType) {
    final stateEventTypes = [
      EventTypes.RoomName,
      EventTypes.RoomTopic,
      EventTypes.RoomAvatar,
      EventTypes.RoomMember,
      EventTypes.RoomPowerLevels,
      EventTypes.RoomCanonicalAlias,
      EventTypes.RoomCreate,
      EventTypes.RoomJoinRules,
      EventTypes.RoomGuestAccess,
      EventTypes.RoomHistoryVisibility,
      EventTypes.Encryption,
      // Add other state event types as needed
    ];

    return stateEventTypes.contains(eventType);
  }
}

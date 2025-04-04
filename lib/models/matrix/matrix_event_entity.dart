import 'package:objectbox/objectbox.dart';

@Entity()
class MatrixEventEntity {
  @Id()
  int id = 0;

  @Unique()
  String eventId; // Unique event identifier

  @Index()
  String roomId; // Foreign key to RoomEntity

  String senderId;
  String type; // "m.room.message", "m.reaction", etc.
  String content;
  int originServerTs;

  bool isLocal; // Mark unsynced messages for retry

  MatrixEventEntity({
    required this.eventId,
    required this.roomId,
    required this.senderId,
    required this.type,
    required this.content,
    required this.originServerTs,
    this.isLocal = false,
  });
}
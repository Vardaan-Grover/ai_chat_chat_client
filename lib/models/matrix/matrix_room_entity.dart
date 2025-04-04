import 'package:objectbox/objectbox.dart';

@Entity()
class MatrixRoomEntity {
  @Id()
  int id = 0;

  @Unique()
  String roomId;

  String name; // Room name
  String avatarUrl; // Room avatar
  bool isDirect; // DM vs. Group chat
  int lastMessageTimestamp; // Helps sort rooms
  int unreadCount; // Cache unread count

  MatrixRoomEntity({
    required this.roomId,
    required this.name,
    required this.avatarUrl,
    required this.isDirect,
    required this.lastMessageTimestamp,
    this.unreadCount = 0,
  });
}
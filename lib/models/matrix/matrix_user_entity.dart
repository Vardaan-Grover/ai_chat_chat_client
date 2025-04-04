import 'package:objectbox/objectbox.dart';

@Entity()
class MatrixUserEntity {
  @Id()
  int id = 0;

  @Unique()
  String userId;

  String displayName;
  String avatarUrl;
  bool isOnline; // Presence status

  MatrixUserEntity({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.isOnline,
  });
}
import 'package:objectbox/objectbox.dart';

@Entity()
class MatrixSessionData {
  @Id()
  int id = 0;

  @Unique()
  String userId;

  String homeserver;
  String deviceId;
  String deviceName;

  MatrixSessionData({
    required this.userId,
    required this.homeserver,
    required this.deviceId,
    required this.deviceName,
  });
}

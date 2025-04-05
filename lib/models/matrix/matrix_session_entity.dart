import 'package:objectbox/objectbox.dart';


@Entity()
class MatrixSessionData {
  @Id()
  int id = 0;

  @Unique()
  String userId;

  String homeserverUrl;
  String deviceId;
  String deviceName;
  int lastUpdate;
  String? token;
  int? tokenExpiresAt;
  String? refreshToken;
  String? prevBatch;
  String? olmAccount;

  MatrixSessionData({
    required this.userId,
    required this.homeserverUrl,
    required this.deviceId,
    required this.deviceName,
    required this.lastUpdate,
    this.token,
    this.tokenExpiresAt,
    this.refreshToken,
    this.prevBatch,
    this.olmAccount,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'homeserverUrl': homeserverUrl,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'lastUpdate': lastUpdate,
      'token': token,
      'tokenExpiresAt': tokenExpiresAt,
      'refreshToken': refreshToken,
      'prevBatch': prevBatch,
      'olmAccount': olmAccount,
    };
  }
}

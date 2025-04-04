import 'package:ai_chat_chat_client/models/matrix/matrix_event_entity.dart';
import 'package:ai_chat_chat_client/models/matrix/matrix_session_data.dart';
import 'package:ai_chat_chat_client/models/matrix/matrix_room_entity.dart';
import 'package:ai_chat_chat_client/objectbox.g.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';

class ObjectBoxService implements DatabaseApi {
  static final Logger logger = Logger('ObjectBoxService');
  late Store store;

  late final Box<MatrixSessionData> matrixSessionBox;
  late final Box<MatrixEventEntity> matrixEventBox;
  late final Box<MatrixRoomEntity> roomEntityBox;

  ObjectBoxService(String dbName) {
    store = Store(getObjectBoxModel(), directory: dbName);
    matrixSessionBox = Box<MatrixSessionData>(store);
    matrixEventBox = Box<MatrixEventEntity>(store);
    roomEntityBox = Box<MatrixRoomEntity>(store);
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
    logger.info("Clearing ObjectBox Database");

    final eventQuery
  }
}

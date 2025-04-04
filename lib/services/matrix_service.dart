import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MatrixService {
  static final Logger log = Logger('MatrixService');
  static Client client = Client(
    "ai-chat-chat",
    // databaseBuilder: (_) async {
    //   final db = ObjectBoxService("ai-chat-chat-db");
    //   await db.open();
    //   return db;
    // },
  );

  static Future<void> init() async {
    try {} catch (e) {}
  }
}

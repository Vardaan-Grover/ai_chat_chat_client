import 'package:ai_chat_chat_client/config/matrix_constants.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class MatrixClientService {
  static final Logger log = Logger('MatrixService');
  static Client client = Client(
    "ai-chat-chat",
    databaseBuilder: (_) async {
      final dir = await getApplicationSupportDirectory();
      final database = await openDatabase('${dir.toString()}/database.sqlite');

      final db = MatrixSdkDatabase('ai-chat-chat', database: database);

      await db.open();
      return db;
    },
  );

  static Future<void> init() async {
    try {
      const homeServerUrl = MatrixConstants.homeServerUrl;
      await client.checkHomeserver(Uri.parse(homeServerUrl));

      if (client.isLogged() == false) {
        await client.init();
      }
    } catch (e) {
      log.severe("Error initializing Matrix client", e);
    }
  }

  static Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    if (client.isLogged() == false) {
      await init();
    }

    return await client.login(
      LoginType.mLoginPassword,
      password: password,
      identifier: AuthenticationUserIdentifier(user: username),
    );
  }

  static Future<Room> joinRoom(String roomId, [String username = '']) async {
    if (roomId.isEmpty) {
      final rid = await createRoom(username);
      Room room = Room(id: rid, client: client);
      return room;
    }

    Room room = Room(id: roomId, client: client);
    return room;
  }

  static Future<String> createRoom(String username) async {
    final roomId = await client.createRoom(
      invite: [username],
      isDirect: true,
      visibility: Visibility.private,
    );
    return roomId;
  }

  static Future<CachedProfileInformation> fetchUserProfile(
    String username,
  ) async {
    try {
      return await client.getUserProfile(username);
    } catch (e) {
      log.severe("Error fetching user profile", e);
      rethrow;
    }
  }
}

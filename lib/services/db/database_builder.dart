import 'dart:io';

import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:package_info_plus/package_info_plus.dart' show PackageInfo;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'cipher.dart';
import 'sqlcipher_stub.dart'
    if (dart.library.io) 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

final _logger = Logger('DatabaseBuilder');

Future<DatabaseApi> matrixSdkDatabaseBuilder(Client client) async {
  MatrixSdkDatabase? database;
  try {
    database = await _constructDatabase(client);
    await database.open();
    return database;
  } catch (e, s) {
    _logger.severe('Unable to construct database!', e, s);

    // Try to delete database so that it can be created again on next init:
    database?.delete().catchError(
      (e, s) => _logger.severe(
        'Unable to delete database after failed construction',
        e,
        s,
      ),
    );

    // Delete database file:
    if (database == null && !PlatformInfos.isWeb) {
      final dbFile = File(await _getDatabasePath(client.clientName));
      if (await dbFile.exists()) await dbFile.delete();
    }

    rethrow;
  }
}

/// Constructs and configures a Matrix SDK database for the given client.
///
/// This function:
/// 1. Gets or creates an encryption key if supported on the platform
/// 2. Sets up file storage for media/attachments
/// 3. Configures and opens the database with encryption if available
/// 4. Applies performance optimizations
///
/// Returns:
///   A configured MatrixSdkDatabase ready for use
/// Throws:
///   Exception if the database cannot be opened or configured properly
Future<MatrixSdkDatabase> _constructDatabase(Client client) async {
  Database? database;
  Directory? fileStorageLocation;
  String? path;

  try {
    // Get encryption key if available
    final cipher = await SqfLiteEncryptionHelper.getDatabaseCipher();
    _logger.info(
      'Database encryption ${cipher == null ? 'not available' : 'enabled'}',
    );

    // Setup file storage for attachments
    try {
      fileStorageLocation = await getApplicationCacheDirectory();
    } catch (e) {
      _logger.warning(
        "Could not access preferred cache directory, falling back to temp",
        e,
      );
      try {
        fileStorageLocation = await getTemporaryDirectory();
      } catch (e) {
        _logger.severe("No file storage location available", e);
        // Continue without file storage - text-only mode
      }
    }

    // Get database path
    path = await _getDatabasePath(client.clientName);
    _logger.fine('Using database path: $path');

    // Fix for old Android versions
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

    // Create database factory with FFI initialization
    final factory = createDatabaseFactoryFfi(
      ffiInit: SqfLiteEncryptionHelper.ffiInit,
    );

    // Setup encryption helper if encryption is available
    final helper =
        (cipher == null)
            ? null
            : SqfLiteEncryptionHelper(
              factory: factory,
              path: path,
              cipher: cipher,
            );

    // Ensure database is encrypted if we have a key
    if (helper != null) {
      await helper.ensureDatabaseFileEncrypted();
    }

    // Open the database with encryption if available
    database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          // Apply encryption if available
          if (helper != null) {
            await helper.applyPragmaKey(db);
          }

          // Performance optimizations
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.execute('PRAGMA temp_store = MEMORY');
          await db.execute('PRAGMA cache_size = 1000');
        },
      ),
    );

    // Verify database is working by running a simple query
    await database.rawQuery('SELECT 1');
    _logger.info('Database opened successfully');

    // Create and return the Matrix SDK database
    return MatrixSdkDatabase(
      client.clientName,
      database: database,
      maxFileSize: 10 * 1000 * 1000, // 10MB max file size
      fileStorageLocation: fileStorageLocation?.uri,
      deleteFilesAfterDuration: const Duration(
        days: 30,
      ), // More conservative cleanup
    );
  } catch (e, stack) {
    _logger.severe('Failed to construct database', e, stack);

    // Clean up resources if initialization failed
    if (database != null) {
      try {
        await database.close();
      } catch (closeError) {
        _logger.warning('Error closing database during cleanup', closeError);
      }
    }

    // Provide helpful error message based on what went wrong
    String errorDetails = 'Unknown error';

    if (e.toString().contains('file is not a database')) {
      errorDetails = 'The database file is corrupted or has invalid encryption';

      // Attempt recovery by deleting corrupted database
      if (path != null) {
        try {
          final dbFile = File(path);
          if (await dbFile.exists()) {
            final backupPath =
                '$path.corrupted.${DateTime.now().millisecondsSinceEpoch}';
            await dbFile.rename(backupPath);
            _logger.info('Moved corrupted database to $backupPath');
            // Try one more time with fresh database
            return _constructDatabase(client);
          }
        } catch (recoveryError) {
          _logger.warning(
            'Failed to recover from database corruption',
            recoveryError,
          );
        }
      }
    } else if (e.toString().contains('permission denied')) {
      errorDetails = 'No permission to access the database location';
    }

    throw Exception(
      'Failed to initialize Matrix database: $errorDetails\nOriginal error: $e',
    );
  }
}

/// Gets the path where the database should be stored.
///
/// On iOS and macOS, the database is stored in the Library directory.
/// On other platforms, it is stored in the Application Support directory.
///
/// [clientName] The name of the client, used to name the database file.
///
/// Returns the full path to the database file as a [String].
Future<String> _getDatabasePath(String clientName) async {
  final databaseDirectory =
      Platform.isIOS || Platform.isMacOS
          ? await getLibraryDirectory()
          : await getApplicationSupportDirectory();

  return join(databaseDirectory.path, '$clientName.sqlite');
}

/// Gets the standard path for database storage across platforms.
///
/// Delegates to the platform-specific implementation of the SQFlite package.
/// This ensures maximum compatibility with various Android versions and
/// storage configurations.
///
/// Returns:
///   A path to a directory where databases can safely be stored on the current platform.
Future<String> getDatabasesPath() async {
  try {
    // Use SQFlite's built-in path determination
    return await databaseFactory.getDatabasesPath();
  } catch (e) {
    _logger.warning(
      'Failed to get standard database path, falling back to application directory',
      e,
    );

    // Fallback if the default method fails
    if (Platform.isAndroid) {
      try {
        // Try application-specific directory first
        return (await getApplicationSupportDirectory()).path;
      } catch (e2) {
        // Last resort - use package info approach
        final packageInfo = await PackageInfo.fromPlatform();
        return '/data/data/${packageInfo.packageName}/databases';
      }
    } else {
      return (await getApplicationSupportDirectory()).path;
    }
  }
}

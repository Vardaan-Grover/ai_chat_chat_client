import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

class SqfLiteEncryptionHelper {
  final String path;
  final Future<Database> Function(String path, {OpenDatabaseOptions? options})
  _open;
  final Uint8List? cipher;

  static final Logger logger = Logger('SqfLiteEncyptionHelper');
  static const _secureStorageKey = 'matrix_sql_cipher_key';

  SqfLiteEncryptionHelper({
    required DatabaseFactory factory,
    required this.path,
    required this.cipher,
  }) : _open = factory.openDatabase;

  /// Generates a secure random encryption key.
  ///
  /// Creates a cryptographically secure 32-byte (256-bit) random key using
  /// [Random.secure()] as the random number generator. This key is suitable
  /// for use in symmetric encryption algorithms like AES-256.
  ///
  /// Returns:
  ///   [Uint8List] containing 32 random bytes.
  static Uint8List generateRandomKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (i) => random.nextInt(256)),
    );
  }

  /// Retrieves the encryption key for the SQLite database.
  ///
  /// This method attempts to fetch the encryption key from secure storage.
  /// If the key does not exist, it generates a new key and stores it securely.
  /// On platforms where secure storage is unavailable (e.g., Linux), it logs
  /// an error and falls back to using an unencrypted database.
  ///
  /// Returns:
  /// - A `Uint8List` containing the encryption key if successful.
  /// - `null` if secure storage is unavailable, key validation fails, or any error occurs.
  static Future<Uint8List?> getDatabaseCipher() async {
    // TODO: Implement key rotation logic
    try {
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

      // Check if key exists
      final containsEncryptionKey = await secureStorage.containsKey(
        key: _secureStorageKey,
      );

      if (!containsEncryptionKey) {
        // Generate new key for new installations
        if (Platform.isLinux) {
          logger.warning(
            "Secure storage is not fully supported on Linux. Using unencrypted database.",
          );
          return null;
        }

        logger.info("Generating new database encryption key");
        final key = generateRandomKey();

        if (key.isEmpty) {
          throw Exception("Failed to generate secure random key");
        }

        await secureStorage.write(
          key: _secureStorageKey,
          value: base64Encode(key),
        );

        // Verify write was successful
        if (!await secureStorage.containsKey(key: _secureStorageKey)) {
          throw Exception("Failed to store encryption key");
        }
      }

      final rawEncryptionKey = await secureStorage.read(key: _secureStorageKey);
      if (rawEncryptionKey == null || rawEncryptionKey.isEmpty) {
        throw Exception("Failed to read encryption key from secure storage");
      }

      // Validate the Base64 format of the key before decoding
      if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(rawEncryptionKey)) {
        logger.severe("Stored encryption key is not in a valid Base64 format");

        // Consider key rotation here - generate a new valid key
        // For now, we'll fall back to unencrypted
        return null;
      }

      final key = base64Decode(rawEncryptionKey);
      if (key.length != 32) {
        logger.warning(
          "Encryption key has unexpected length: ${key.length} bytes (expected 32)",
        );
      }

      return key;
    } catch (e, stackTrace) {
      // If we can't use secure storage, we'll use unencrypted database
      logger.severe(
        "Unable to use encrypted database on ${Platform.operatingSystem} (${Platform.version}): $e",
        e,
        stackTrace,
      );
      return null;
    }
  }

  /// Initializes the FFI (Foreign Function Interface) for SQLite.
  ///
  /// This is necessary to enable SQLite functionality on platforms like desktop
  // (Windows, macOS, Linux) where the sqflite_common_ffi package is used.
  ///
  /// It should be called before any database operations to ensure proper setup.
  static void ffiInit() {
    sqfliteFfiInit();
  }

  /// Applies the encryption key to an open database connection.
  ///
  /// This function sets the SQLCipher encryption key using the PRAGMA statement.
  /// After setting the key, it verifies that the key was applied correctly by
  /// attempting to query the database. If the key is incorrect or missing when
  /// required, an exception will be thrown.
  ///
  /// Parameters:
  /// - `db`: An open SQLite database connection
  ///
  /// Throws:
  /// - `Exception` if the key application fails or if the key appears to be incorrect
  Future<void> applyPragmaKey(Database db) async {
    try {
      if (cipher != null && cipher!.isNotEmpty) {
        logger.fine(
          'Applying encryption key to database: ${path.split('/').last}',
        );
        await db.rawQuery('PRAGMA key = "${_toHex(cipher!)}"');

        // Check if the key was applied successfully
        try {
          await db.query('sqlite_master', limit: 1);
        } catch (e) {
          throw Exception("Database encryption key may be incorrect: $e");
        }
      } else {
        logger.warning(
          "No encryption key provided, using unencrypted database",
        );
      }
    } catch (e) {
      logger.severe("Failed to apply encryption key", e);
      throw Exception("Failed to apply encryption key: $e");
    }
  }

  /// Determines if an existing database file is encrypted with SQLCipher.
  ///
  /// This method attempts to open the database without an encryption key.
  /// If the open operation succeeds, the database is not encrypted.
  /// If it fails with a specific error message, it's likely encrypted.
  ///
  /// Returns:
  /// - `true` if the database file exists and appears to be encrypted
  /// - `false` if the file doesn't exist or is not encrypted
  ///
  /// Note: This method may produce false positives if the database file
  /// is corrupted rather than encrypted.
  Future<bool> isDatabaseFileEncrypted() async {
    final file = File(path);

    if (!file.existsSync()) {
      logger.fine('Database file does not exist: $path');
      return false;
    }

    try {
      logger.fine('Checking if database is encrypted: ${path.split('/').last}');

      // Try to open the database without a key
      final db = await _open(path);

      // If we get here, the database opened successfully without a key
      try {
        // Make sure we can actually read data (additional validation)
        await db.query('sqlite_master', limit: 1);
        logger.fine('Database is not encrypted: ${path.split('/').last}');

        // Important: Close the connection we just opened for testing
        await db.close();
        return false;
      } catch (e) {
        await db.close();
        logger.warning('Database is corrupted');
        throw Exception('Database file is corrupted: $e');
      }
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      final isEncrypted =
          errorMessage.contains('not a database') ||
          errorMessage.contains('file is encrypted');

      logger.fine(
        'Database ${isEncrypted ? "is" : "might be"} encrypted: ${path.split('/').last}',
      );
      return isEncrypted;
    }
  }

  /// Encrypts an unencrypted database in place.
  ///
  /// This method checks if the database file exists and is not already encrypted.
  /// If it needs encryption, it:
  /// 1. Creates a temporary encrypted database
  /// 2. Copies all tables, indexes, triggers and data
  /// 3. Replaces the original file with the encrypted version
  ///
  /// This operation can fail if there's insufficient disk space or if
  /// the database is currently in use by another connection.
  Future<void> ensureDatabaseFileEncrypted() async {
    try {
      if (!await isDatabaseFileEncrypted() && File(path).existsSync()) {
        logger.info(
          'Database exists but is not encrypted. Starting encryption process.',
        );

        final tempPath = '$path.encrypted';
        Database? plainDb, encryptedDb;

        try {
          // Clean up any existing temporary file
          final tempFile = File(tempPath);
          if (tempFile.existsSync()) {
            await tempFile.delete();
          }

          // Open both databases
          plainDb = await _open(path);
          encryptedDb = await _open(
            tempPath,
            options: OpenDatabaseOptions(
              version: 1,
              onConfigure: applyPragmaKey,
            ),
          );

          // Start transaction in encrypted DB for atomicity
          await encryptedDb.execute('BEGIN TRANSACTION');

          // 1. Copy all tables and data
          final tables = await plainDb.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite%'",
          );

          logger.finest("Found ${tables.length} tables to migrate");

          for (final table in tables) {
            final tableName = table['name'] as String;
            final tableSql = table['sql'] as String?;

            if (tableSql == null || tableSql.isEmpty) {
              logger.warning(
                'Could not determine schema for table: $tableName',
              );
              continue;
            }

            logger.fine('Migrating table: $tableName');

            // Create table in encrypted database
            await encryptedDb.execute(tableSql);

            // Copy data using batched approach for efficiency
            final count =
                Sqflite.firstIntValue(
                  await plainDb.rawQuery('SELECT COUNT(*) FROM "$tableName"'),
                ) ??
                0;

            // Use batch processing for large tables
            const batchSize = 500;
            for (int offset = 0; offset < count; offset += batchSize) {
              final batch = encryptedDb.batch();

              final rows = await plainDb.rawQuery(
                'SELECT * FROM "$tableName" LIMIT $batchSize OFFSET $offset',
              );

              for (final row in rows) {
                // Use parameterized query to avoid SQL injection
                final columns = row.keys.join(', ');
                final placeholders = List.filled(
                  row.keys.length,
                  '?',
                ).join(', ');

                batch.rawInsert(
                  'INSERT INTO "$tableName" ($columns) VALUES ($placeholders)',
                  row.values.map((v) => v).toList(),
                );
              }

              await batch.commit(noResult: true);
              logger.fine(
                'Migrated ${offset + rows.length}/$count rows in $tableName',
              );
            }
          }

          // 2. Copy indexes
          final indexes = await plainDb.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%'",
          );

          for (final index in indexes) {
            final indexSql = index['sql'] as String?;
            if (indexSql != null && indexSql.isNotEmpty) {
              await encryptedDb.execute(indexSql);
            }
          }

          // 3. Copy triggers
          final triggers = await plainDb.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE type='trigger' AND name NOT LIKE 'sqlite_%'",
          );

          for (final trigger in triggers) {
            final triggerSql = trigger['sql'] as String?;
            if (triggerSql != null && triggerSql.isNotEmpty) {
              await encryptedDb.execute(triggerSql);
            }
          }

          // 4. Copy views
          final views = await plainDb.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE type='view' AND name NOT LIKE 'sqlite_%'",
          );

          for (final view in views) {
            final viewSql = view['sql'] as String?;
            if (viewSql != null && viewSql.isNotEmpty) {
              await encryptedDb.execute(viewSql);
            }
          }

          // Commit the transaction
          await encryptedDb.execute('COMMIT');

          // Close both databases
          await plainDb.close();
          await encryptedDb.close();
          plainDb = null;
          encryptedDb = null;

          // Replace original with encrypted version
          await File(path).delete();
          await File(tempPath).rename(path);

          logger.info('Database encryption completed successfully');
        } catch (e, stackTrace) {
          logger.severe('Error during database encryption', e, stackTrace);

          // Try to rollback if we're in the middle of a transaction
          if (encryptedDb != null) {
            try {
              await encryptedDb.execute('ROLLBACK');
            } catch (rollbackError) {
              logger.warning('Failed to rollback transaction: $rollbackError');
            }
          }

          // Try to clean up the temp file if it exists
          try {
            final tempFile = File(tempPath);
            if (tempFile.existsSync()) {
              await tempFile.delete();
            }
          } catch (cleanupError) {
            logger.warning('Failed to clean up temporary file: $cleanupError');
          }

          rethrow; // Re-throw the original exception
        } finally {
          // Ensure connections are closed
          if (plainDb != null) {
            try {
              await plainDb.close();
            } catch (e) {
              logger.warning('Error closing plain database: $e');
            }
          }

          if (encryptedDb != null) {
            try {
              await encryptedDb.close();
            } catch (e) {
              logger.warning('Error closing encrypted database: $e');
            }
          }
        }
      } else {
        logger.fine(
          'Database is already encrypted or does not exist. No action needed.',
        );
      }
    } catch(e) {
      if (e is DatabaseException && e.toString().contains('corrupted')) {
        logger.warning(
          'Detected corrupted database file, deleting and creating new encrypted one',
        );

        // Delete corrupted file
        final file = File(path);
        if (file.existsSync()) {
          final backupPath =
              '$path.corrupted.${DateTime.now().millisecondsSinceEpoch}';
          await file.rename(backupPath);
          logger.info('Moved corrupted database to $backupPath');
        }

        // Create new empty encrypted database
        final db = await _open(
          path,
          options: OpenDatabaseOptions(version: 1, onConfigure: applyPragmaKey),
        );
        await db.close();
      } else {
        rethrow;
      }
    }
  }

  /// Convert Uint8List to hex string
  String _toHex(Uint8List data) {
    return data.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}

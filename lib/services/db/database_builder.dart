// import 'dart:io';

// import 'package:flutter/foundation.dart';
// import 'package:logging/logging.dart';
// import 'package:matrix/matrix.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// import 'cipher.dart';
// import 'sqlcipher_stub.dart'
//     if (dart.library.io) 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

// final _logger = Logger('DatabaseBuilder');

// Future<DatabaseApi> matrixSdkDatabaseBuilder(Client client) async {
//   MatrixSdkDatabase? database;
//   try {
//     database = await 
//   } catch(e, stack) {

//   }
// }

// Future<MatrixSdkDatabase> _constructDatabase(Client client) async {
//   final cipher = await SqfLiteEncryptionHelper.getDatabaseCipher();

//   Directory? fileStorageLocation;

//   try {
//     fileStorageLocation = await getTemporaryDirectory();
//   } catch(e) {
//     _logger.severe("No temporary directory for file cache available", e);
//   }

//   final path = await _getDatabasePath(client.clientName);
// }
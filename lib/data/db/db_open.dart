import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Temporary: open an unencrypted SQLite database to keep development moving.
/// We will reintroduce encryption later with a stable, unified approach.
Future<QueryExecutor> openEncryptedExecutor({String dbFileName = 'app.db'}) async {
  final dir = await _appDbDir();
  final dbPath = p.join(dir.path, dbFileName);
  return NativeDatabase(File(dbPath));
}

Future<Directory> _appDbDir() async {
  // Use documents directory cross-platform
  final dir = await getApplicationDocumentsDirectory();
  return dir;
}

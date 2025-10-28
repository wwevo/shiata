import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/db_handle.dart';
import 'db/raw_db.dart';
import 'repo/entries_repository.dart';

/// Provides an [AppDb] instance when the low-level [QueryExecutor] is available.
final appDbProvider = Provider<AppDb?>((ref) {
  final execAsync = ref.watch(dbHandleProvider);
  return execAsync.maybeWhen(
    data: (exec) {
      if (exec == null) return null;
      final db = AppDb(exec);
      // Ensure schema is initialized once; ignore errors here, surface in repo calls
      // to avoid rebuild loops.
      // Use microtask to avoid synchronous setState during build.
      scheduleMicrotask(() async {
        try {
          await db.ensureInitialized();
        } catch (_) {
          // Ignored here; repository operations will surface errors.
        }
      });
      return db;
    },
    orElse: () => null,
  );
});

final entriesRepositoryProvider = Provider<EntriesRepository?>((ref) {
  final db = ref.watch(appDbProvider);
  if (db == null) return null;
  final repo = EntriesRepository(db: db);
  return repo;
});

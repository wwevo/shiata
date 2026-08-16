import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db_open.dart';

/// Holds the lifecycle of the encrypted DB executor.
class DbHandle extends AsyncNotifier<QueryExecutor?> {
  QueryExecutor? _executor;

  @override
  FutureOr<QueryExecutor?> build() async {
    // Do not auto-open; lifecycle widget will open on resumed.
    return _executor;
  }

  Future<void> openDb() async {
    if (_executor != null || state.isLoading) return;
    state = const AsyncLoading();
    try {
      final exec = await openEncryptedExecutor();
      _executor = exec;
      state = AsyncData(exec);
      debugPrint('[DB] Opened database');
    } catch (e, st) {
      state = AsyncError(e, st);
      debugPrint('[DB][ERROR] Failed to open encrypted database: $e');
      rethrow;
    }
  }

  Future<void> closeDb() async {
    final exec = _executor;
    if (exec == null) return;
    try {
      if (exec is QueryExecutorUser) {
        await exec.close();
      } else {
        try {
          await exec.close();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DB][WARN] Error while closing DB: $e');
    } finally {
      _executor = null;
      state = const AsyncData(null);
      debugPrint('[DB] Closed encrypted database');
    }
  }

  Future<void> wipeDb({String dbFileName = 'app.db'}) async {
    debugPrint('[DB][WIPE] Requested wipe');
    await closeDb();
    try {
      final path = await appDbPath(dbFileName: dbFileName);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[DB][WIPE] Deleted DB file at $path');
      } else {
        debugPrint('[DB][WIPE] DB file not found at $path');
      }
    } catch (e) {
      debugPrint('[DB][WIPE][ERROR] $e');
      rethrow;
    }
    await openDb();
  }
}

final dbHandleProvider = AsyncNotifierProvider<DbHandle, QueryExecutor?>(
  DbHandle.new,
);

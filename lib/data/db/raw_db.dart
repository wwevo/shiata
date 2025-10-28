import 'dart:async';

import 'package:drift/drift.dart';

/// Minimal Drift database without generated tables.
/// We use customStatement/customSelect and manage schema manually for now.
class AppDb extends GeneratedDatabase {
  AppDb(QueryExecutor executor) : super(executor);

  /// Bump when schema changes (for future migrations).
  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  /// Create tables if they don't exist.
  Future<void> ensureInitialized() async {
    // entries table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entries (
        id TEXT PRIMARY KEY,
        widget_kind TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        target_at INTEGER NOT NULL,
        show_in_calendar INTEGER NOT NULL DEFAULT 1,
        payload_json TEXT NOT NULL,
        schema_version INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        source_event_id TEXT NULL,
        source_entry_id TEXT NULL,
        source_widget_kind TEXT NULL
      );
    ''');

    // Indexes for performance
    await _safeCreateIndex(
      'CREATE INDEX IF NOT EXISTS idx_entries_target_at ON entries(target_at);',
    );
    await _safeCreateIndex(
      'CREATE INDEX IF NOT EXISTS idx_entries_widget_kind_target_at ON entries(widget_kind, target_at);',
    );
    await _safeCreateIndex(
      'CREATE INDEX IF NOT EXISTS idx_entries_show_calendar_target_at ON entries(show_in_calendar, target_at);',
    );
  }

  Future<void> _safeCreateIndex(String sql) async {
    await customStatement(sql);
  }
}

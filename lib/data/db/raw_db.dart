import 'dart:async';

import 'package:drift/drift.dart';

/// Minimal Drift database without generated tables.
/// We use customStatement/customSelect and manage schema manually for now.
class AppDb extends GeneratedDatabase {
  AppDb(super.executor);

  /// Keep at 1 because we manage schema with manual SQL in [ensureInitialized].
  /// Drift's migration system is not used for table generation here.
  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Create all objects
          await ensureInitialized();
        },
        onUpgrade: (m, from, to) async {
          // Apply lightweight migrations inside ensureInitialized
          await ensureInitialized();
        },
        beforeOpen: (details) async {
          // Ensure indexes and seeds exist
          await ensureInitialized();
        },
      );

  /// Create tables if they don't exist and apply lightweight migrations.
  Future<void> ensureInitialized() async {
    // entries table (base)
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

    // Lightweight column additions for 0.3.0 — check columns and add if missing
    final cols = await customSelect('PRAGMA table_info(entries);').get();
    final colNames = cols.map((r) => (r.data['name'] as String).toLowerCase()).toSet();
    if (!colNames.contains('product_id')) {
      await customStatement('ALTER TABLE entries ADD COLUMN product_id TEXT NULL;');
    }
    if (!colNames.contains('product_grams')) {
      await customStatement('ALTER TABLE entries ADD COLUMN product_grams INTEGER NULL;');
    }
    if (!colNames.contains('is_static')) {
      await customStatement('ALTER TABLE entries ADD COLUMN is_static INTEGER NOT NULL DEFAULT 0;');
    }

    // kinds table (0.4.0)
    await customStatement('''
      CREATE TABLE IF NOT EXISTS kinds (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        color INTEGER NULL,
        icon TEXT NULL,
        min INTEGER NOT NULL,
        max INTEGER NOT NULL,
        default_show_in_calendar INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // products table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        icon TEXT NULL,
        color INTEGER NULL
      );
    ''');

    // product_components table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS product_components (
        product_id TEXT NOT NULL,
        kind_id TEXT NOT NULL,
        amount_per_gram REAL NOT NULL,
        PRIMARY KEY (product_id, kind_id)
      );
    ''');

    // recipes table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS recipes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        icon TEXT NULL,
        color INTEGER NULL
      );
    ''');

    // recipe_components table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS recipe_components (
        recipe_id TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('kind','product')),
        comp_id TEXT NOT NULL,
        amount REAL NULL, -- for kind components
        grams INTEGER NULL, -- for product components
        PRIMARY KEY (recipe_id, type, comp_id)
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
    await _safeCreateIndex(
      'CREATE INDEX IF NOT EXISTS idx_entries_product_id ON entries(product_id);',
    );
  }

  Future<void> _safeCreateIndex(String sql) async {
    await customStatement(sql);
  }
}

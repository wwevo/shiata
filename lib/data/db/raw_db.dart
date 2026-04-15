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
    // 1. Create all tables if they don't exist (base structure)
    // entries table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS entries (
        id TEXT PRIMARY KEY,
        widget_kind TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        target_at INTEGER NOT NULL,
        show_in_calendar INTEGER NOT NULL DEFAULT 1,
        payload_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        source_entry_id TEXT NULL,
        source_widget_kind TEXT NULL,
        product_id TEXT NULL,
        product_grams INTEGER NULL,
        is_static INTEGER NOT NULL DEFAULT 0,
        recipe_id TEXT NULL
      );
    ''');

    // kinds table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS kinds (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        color INTEGER NULL,
        icon TEXT NULL,
        min INTEGER NOT NULL,
        max INTEGER NOT NULL,
        default_show_in_calendar INTEGER NOT NULL DEFAULT 0,
        is_protected INTEGER NOT NULL DEFAULT 0
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
        color INTEGER NULL,
        is_protected INTEGER NOT NULL DEFAULT 0
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
        color INTEGER NULL,
        is_protected INTEGER NOT NULL DEFAULT 0
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

    // units table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS units (
        id TEXT PRIMARY KEY NOT NULL,
        label TEXT NOT NULL
      );
    ''');

    // 2. Pre-populate data
    // units
    await customStatement("INSERT OR IGNORE INTO units (id, label) VALUES ('g', 'g');");
    await customStatement("INSERT OR IGNORE INTO units (id, label) VALUES ('mg', 'mg');");
    await customStatement("INSERT OR IGNORE INTO units (id, label) VALUES ('ug', 'µg');");
    await customStatement("INSERT OR IGNORE INTO units (id, label) VALUES ('mL', 'mL');");

    // 3. Apply migrations for existing tables (if missing columns)
    // entries migrations
    final entriesCols = await customSelect('PRAGMA table_info(entries);').get();
    final entriesColNames = entriesCols
        .map((r) => (r.data['name'] as String).toLowerCase())
        .toSet();
    if (!entriesColNames.contains('product_id')) {
      await customStatement('ALTER TABLE entries ADD COLUMN product_id TEXT NULL;');
    }
    if (!entriesColNames.contains('product_grams')) {
      await customStatement('ALTER TABLE entries ADD COLUMN product_grams INTEGER NULL;');
    }
    if (!entriesColNames.contains('is_static')) {
      await customStatement('ALTER TABLE entries ADD COLUMN is_static INTEGER NOT NULL DEFAULT 0;');
    }
    if (!entriesColNames.contains('recipe_id')) {
      await customStatement('ALTER TABLE entries ADD COLUMN recipe_id TEXT NULL;');
    }

    // 0.8.9 migrations
    if (entriesColNames.contains('source_event_id')) {
      await customStatement('ALTER TABLE entries DROP COLUMN source_event_id;');
    }
    if (entriesColNames.contains('schema_version')) {
      await customStatement('ALTER TABLE entries DROP COLUMN schema_version;');
    }

    // v0.9.1 migrations: is_protected for kinds, products, recipes
    // kinds
    final kindCols = await customSelect('PRAGMA table_info(kinds);').get();
    final kindColNames = kindCols.map((r) => (r.data['name'] as String).toLowerCase()).toSet();
    if (!kindColNames.contains('is_protected')) {
      await customStatement('ALTER TABLE kinds ADD COLUMN is_protected INTEGER NOT NULL DEFAULT 0;');
    }

    // products
    final productCols = await customSelect('PRAGMA table_info(products);').get();
    final productColNames = productCols.map((r) => (r.data['name'] as String).toLowerCase()).toSet();
    if (!productColNames.contains('icon')) {
      await customStatement('ALTER TABLE products ADD COLUMN icon TEXT NULL;');
    }
    if (!productColNames.contains('color')) {
      await customStatement('ALTER TABLE products ADD COLUMN color INTEGER NULL;');
    }
    if (!productColNames.contains('is_protected')) {
      await customStatement('ALTER TABLE products ADD COLUMN is_protected INTEGER NOT NULL DEFAULT 0;');
    }

    // recipes
    final recipeCols = await customSelect('PRAGMA table_info(recipes);').get();
    final recipeColNames = recipeCols.map((r) => (r.data['name'] as String).toLowerCase()).toSet();
    if (!recipeColNames.contains('icon')) {
      await customStatement('ALTER TABLE recipes ADD COLUMN icon TEXT NULL;');
    }
    if (!recipeColNames.contains('color')) {
      await customStatement('ALTER TABLE recipes ADD COLUMN color INTEGER NULL;');
    }
    if (!recipeColNames.contains('is_protected')) {
      await customStatement('ALTER TABLE recipes ADD COLUMN is_protected INTEGER NOT NULL DEFAULT 0;');
    }

    // 4. Indexes for performance
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
    await _safeCreateIndex(
      'CREATE INDEX IF NOT EXISTS idx_entries_recipe_id ON entries(recipe_id);',
    );
  }

  Future<void> _safeCreateIndex(String sql) async {
    await customStatement(sql);
  }
}

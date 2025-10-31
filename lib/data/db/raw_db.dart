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
        amount_per_gram INTEGER NOT NULL,
        PRIMARY KEY (product_id, kind_id)
      );
    ''');

    // Seed initial products and components (per 100g integers stored in amount_per_gram)
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await customStatement("INSERT OR IGNORE INTO products (id, name, created_at, updated_at, is_active) VALUES ('egg', 'Egg', ?, ?, 1);", [now, now]);
    await customStatement("INSERT OR IGNORE INTO products (id, name, created_at, updated_at, is_active) VALUES ('beef', 'Beef', ?, ?, 1);", [now, now]);
    await customStatement("INSERT OR IGNORE INTO products (id, name, created_at, updated_at, is_active) VALUES ('milk', 'Milk', ?, ?, 1);", [now, now]);
    await customStatement("INSERT OR IGNORE INTO products (id, name, created_at, updated_at, is_active) VALUES ('oatmeal', 'Oatmeal', ?, ?, 1);", [now, now]);
    await customStatement("INSERT OR IGNORE INTO products (id, name, created_at, updated_at, is_active) VALUES ('greek_yogurt', 'Greek Yogurt', ?, ?, 1);", [now, now]);

    // Helper to seed components: amount_per_gram interpreted as per 100g integer
    Future<void> comp(String pid, String kid, int per100) async {
      await customStatement('INSERT OR IGNORE INTO product_components (product_id, kind_id, amount_per_gram) VALUES (?, ?, ?);', [pid, kid, per100]);
    }
    // Egg (per 100g): macros + key vitamins/minerals (integers only)
    await comp('egg', 'protein', 13);
    await comp('egg', 'fat', 10);
    await comp('egg', 'carbohydrate', 1);
    await comp('egg', 'vitamin_a', 160); // ug RAE
    await comp('egg', 'vitamin_b12', 1); // ug
    await comp('egg', 'vitamin_d', 2); // ug
    await comp('egg', 'iron', 1); // mg
    await comp('egg', 'phosphorus', 198); // mg
    await comp('egg', 'calcium', 50); // mg
    await comp('egg', 'potassium', 126); // mg
    await comp('egg', 'sodium', 142); // mg
    // Beef (lean, per 100g): macros + hallmark minerals/vitamins
    await comp('beef', 'protein', 26);
    await comp('beef', 'fat', 15);
    await comp('beef', 'carbohydrate', 0);
    await comp('beef', 'iron', 2);
    await comp('beef', 'zinc', 4);
    await comp('beef', 'vitamin_b12', 2); // ug
    await comp('beef', 'phosphorus', 180); // mg
    await comp('beef', 'potassium', 318); // mg
    await comp('beef', 'sodium', 72); // mg
    // Milk (per 100g)
    await comp('milk', 'protein', 3);
    await comp('milk', 'fat', 3);
    await comp('milk', 'carbohydrate', 5);
    await comp('milk', 'calcium', 120); // mg
    await comp('milk', 'vitamin_d', 1); // ug
    await comp('milk', 'vitamin_a', 47); // ug
    await comp('milk', 'phosphorus', 95); // mg
    await comp('milk', 'potassium', 150); // mg
    await comp('milk', 'sodium', 44); // mg
    // Oatmeal (dry, per 100g)
    await comp('oatmeal', 'protein', 16);
    await comp('oatmeal', 'fat', 7);
    await comp('oatmeal', 'carbohydrate', 66);
    await comp('oatmeal', 'magnesium', 177); // mg
    await comp('oatmeal', 'iron', 4); // mg
    await comp('oatmeal', 'zinc', 4); // mg
    await comp('oatmeal', 'phosphorus', 410); // mg
    await comp('oatmeal', 'potassium', 429); // mg
    await comp('oatmeal', 'sodium', 2); // mg
    // Greek Yogurt (plain, per 100g)
    await comp('greek_yogurt', 'protein', 10);
    await comp('greek_yogurt', 'fat', 0);
    await comp('greek_yogurt', 'carbohydrate', 4);
    await comp('greek_yogurt', 'calcium', 110); // mg
    await comp('greek_yogurt', 'phosphorus', 135); // mg
    await comp('greek_yogurt', 'potassium', 141); // mg
    await comp('greek_yogurt', 'sodium', 36); // mg

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

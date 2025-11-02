import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../db/raw_db.dart';
import '../db/db_open.dart';
import '../providers.dart';
import 'kinds_repository.dart';
import 'products_repository.dart';
import 'entries_repository.dart';

class ImportResult {
  ImportResult({
    required this.kindsUpserted,
    required this.productsUpserted,
    required this.componentsWritten,
    required this.warnings,
  });
  final int kindsUpserted;
  final int productsUpserted;
  final int componentsWritten;
  final List<String> warnings;
}

class ImportExportService {
  ImportExportService({required this.db, required this.kinds, required this.products, required this.entries});
  final AppDb db;
  final KindsRepository kinds;
  final ProductsRepository products;
  final EntriesRepository entries;

  /// Export full bundle including entries.
  Future<Map<String, Object?>> exportBundle() async {
    final kindsList = await kinds.dumpKinds();
    final productsList = await products.dumpProductsWithComponents();
    final entriesList = await entries.dumpEntries();
    return <String, Object?>{
      'version': 1,
      'kinds': kindsList,
      'products': productsList,
      'entries': entriesList,
    };
  }

  /// Destructive import: wipes all data then imports the bundle as-is.
  Future<ImportResult> importBundle(dynamic jsonLike) async {
    final Map<String, dynamic> root;
    if (jsonLike is String) {
      root = jsonDecode(jsonLike) as Map<String, dynamic>;
    } else if (jsonLike is Map<String, dynamic>) {
      root = jsonLike;
    } else {
      throw ArgumentError('Unsupported import payload');
    }

    final version = root['version'];
    if (version != 1) {
      throw StateError('Unsupported version: $version');
    }

    int kindsUpserted = 0;
    int productsUpserted = 0;
    int componentsWritten = 0;

    // Wipe existing data first (entries → components → products → kinds)
    await db.transaction(() async {
      await db.customStatement('DELETE FROM entries;');
      await db.customStatement('DELETE FROM product_components;');
      await db.customStatement('DELETE FROM products;');
      await db.customStatement('DELETE FROM kinds;');
    });

    // Import kinds first (no extra validation here; assume bundle is correct)
    final kindsArr = (root['kinds'] as List?) ?? const [];
    for (final item in kindsArr) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString().trim();
      final name = (item['name'] ?? '').toString().trim();
      final unit = (item['unit'] ?? '').toString().trim();
      final colorVal = item['color'];
      final color = colorVal is int
          ? colorVal
          : (colorVal is String && int.tryParse(colorVal) != null)
              ? int.parse(colorVal)
              : null;
      final icon = (item['icon'] as String?)?.trim();
      final min = _asInt(item['min']) ?? 0;
      final max = _asInt(item['max']) ?? 0;
      final defaultShow = item['defaultShowInCalendar'] == true || item['defaultShowInCalendar'] == 1;
      await kinds.upsertKind(KindDef(
        id: id,
        name: name,
        unit: unit,
        color: color,
        icon: (icon == null || icon.isEmpty) ? null : icon,
        min: min,
        max: max,
        defaultShowInCalendar: defaultShow,
      ));
      kindsUpserted++;
    }

    // Products + components
    final prodsArr = (root['products'] as List?) ?? const [];
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final item in prodsArr) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString().trim();
      final name = (item['name'] ?? '').toString().trim();
      await products.upsertProduct(ProductDef(
        id: id,
        name: name,
        createdAt: now,
        updatedAt: now,
      ));
      productsUpserted++;

      final comps = <ProductComponent>[];
      final compsArr = (item['components'] as List?) ?? const [];
      for (final c in compsArr) {
        if (c is! Map) continue;
        final kindId = (c['kindId'] ?? '').toString().trim();
        final per100Raw = c['per100'];
        final per100 = (per100Raw is num) ? per100Raw.toDouble() : double.tryParse(per100Raw?.toString() ?? '0') ?? 0.0;
        comps.add(ProductComponent(productId: id, kindId: kindId, amountPerGram: per100));
      }
      await products.setComponents(id, comps);
      componentsWritten += comps.length;
    }

    // Entries last (full rows)
    final entriesArr = (root['entries'] as List?) ?? const [];
    if (entriesArr.isNotEmpty) {
      final records = <EntryRecord>[];
      for (final item in entriesArr) {
        if (item is! Map) continue;
        records.add(_entryFromMap(item));
      }
      await entries.insertRawEntries(records);
    }

    return ImportResult(
      kindsUpserted: kindsUpserted,
      productsUpserted: productsUpserted,
      componentsWritten: componentsWritten,
      warnings: const <String>[],
    );
  }

  /// One-tap backup to single-slot file (JSON bundle). Returns the path.
  Future<String> backupToFile({String fileName = 'backup.json'}) async {
    final bundle = await exportBundle();
    final encoder = const JsonEncoder.withIndent('  ');
    final text = encoder.convert(bundle);
    final dirPath = await _appDocsDirPath();
    final path = p.join(dirPath, fileName);
    final file = File(path);
    await file.writeAsString(text);
    return path;
  }

  /// Restore from the single-slot backup file (destructive). Returns the path used.
  Future<String> restoreFromFile({String fileName = 'backup.json'}) async {
    final dirPath = await _appDocsDirPath();
    final path = p.join(dirPath, fileName);
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Backup file not found at $path');
    }
    final text = await file.readAsString();
    await importBundle(text); // destructive
    return path;
  }

  Future<String> _appDocsDirPath() async {
    final dbPath = await appDbPath();
    return p.dirname(dbPath);
  }

  EntryRecord _entryFromMap(Map raw) {
    int asInt(Object? v) => _asInt(v) ?? 0;
    bool asBool(Object? v) => (v is bool) ? v : (v is num) ? v != 0 : v == '1' || v == 'true';
    return EntryRecord(
      id: (raw['id'] ?? '').toString(),
      widgetKind: (raw['widget_kind'] ?? '').toString(),
      createdAt: asInt(raw['created_at']),
      targetAt: asInt(raw['target_at']),
      showInCalendar: asBool(raw['show_in_calendar']),
      payloadJson: (raw['payload_json'] ?? '{}').toString(),
      schemaVersion: asInt(raw['schema_version']),
      updatedAt: asInt(raw['updated_at']),
      sourceEventId: (raw['source_event_id'] as String?) ?? (raw['sourceEventId'] as String?),
      sourceEntryId: (raw['source_entry_id'] as String?) ?? (raw['sourceEntryId'] as String?),
      sourceWidgetKind: (raw['source_widget_kind'] as String?) ?? (raw['sourceWidgetKind'] as String?),
      productId: (raw['product_id'] as String?) ?? (raw['productId'] as String?),
      productGrams: _asInt(raw['product_grams']),
      isStatic: asBool(raw['is_static']),
    );
  }

  int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

final importExportServiceProvider = Provider<ImportExportService?>((ref) {
  final db = ref.watch(appDbProvider);
  final kr = ref.watch(kindsRepositoryProvider);
  final pr = ref.watch(productsRepositoryProvider);
  final er = ref.watch(entriesRepositoryProvider);
  if (db == null || kr == null || pr == null || er == null) return null;
  return ImportExportService(db: db, kinds: kr, products: pr, entries: er);
});

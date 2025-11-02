import 'dart:async';

import 'package:drift/drift.dart';

import '../db/raw_db.dart';

class KindDef {
  KindDef({
    required this.id,
    required this.name,
    required this.unit,
    this.color,
    this.icon,
    required this.min,
    required this.max,
    this.defaultShowInCalendar = false,
  });

  final String id;
  final String name;
  final String unit; // canonical unit string, e.g., 'g', 'mg', 'ug', 'mL'
  final int? color; // ARGB int or null
  final String? icon; // Material icon name string or null
  final int min; // inclusive min
  final int max; // inclusive max
  final bool defaultShowInCalendar;
}

class KindsRepository {
  KindsRepository({required this.db}) : _ready = db.ensureInitialized();

  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Dump kinds for export (ordered by name).
  Future<List<Map<String, Object?>>> dumpKinds() async {
    final list = await listKinds();
    return list
        .map((k) => {
              'id': k.id,
              'name': k.name,
              'unit': k.unit,
              'color': k.color,
              'icon': k.icon,
              'min': k.min,
              'max': k.max,
              'defaultShowInCalendar': k.defaultShowInCalendar,
            })
        .toList();
  }

  Future<void> upsertKind(KindDef k) async {
    await _ready;
    await db.customStatement(
      'INSERT INTO kinds (id, name, unit, color, icon, min, max, default_show_in_calendar) VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET name=excluded.name, unit=excluded.unit, color=excluded.color, icon=excluded.icon, min=excluded.min, max=excluded.max, default_show_in_calendar=excluded.default_show_in_calendar;',
      [
        k.id,
        k.name,
        k.unit,
        k.color,
        k.icon,
        k.min,
        k.max,
        k.defaultShowInCalendar ? 1 : 0,
      ],
    );
    _notify();
  }

  Future<void> deleteKind(String id) async {
    await _ready;
    // Consider FK in product_components; for now, allow cascade-like cleanup manually.
    await db.transaction(() async {
      await db.customStatement('DELETE FROM product_components WHERE kind_id = ?;', [id]);
      await db.customStatement('DELETE FROM kinds WHERE id = ?;', [id]);
    });
    _notify();
  }

  Future<KindDef?> getKind(String id) async {
    await _ready;
    final rows = await db.customSelect(
      'SELECT * FROM kinds WHERE id = ? LIMIT 1;',
      variables: [Variable.withString(id)],
      readsFrom: const {},
    ).get();
    if (rows.isEmpty) return null;
    final d = rows.first.data;
    return KindDef(
      id: d['id'] as String,
      name: d['name'] as String,
      unit: d['unit'] as String,
      color: d['color'] as int?,
      icon: d['icon'] as String?,
      min: d['min'] as int,
      max: d['max'] as int,
      defaultShowInCalendar: (d['default_show_in_calendar'] as int) != 0,
    );
  }

  Future<List<KindDef>> listKinds() async {
    await _ready;
    final rows = await db.customSelect(
      'SELECT * FROM kinds ORDER BY name ASC;',
      readsFrom: const {},
    ).get();
    return rows.map((r) {
      final d = r.data;
      return KindDef(
        id: d['id'] as String,
        name: d['name'] as String,
        unit: d['unit'] as String,
        color: d['color'] as int?,
        icon: d['icon'] as String?,
        min: d['min'] as int,
        max: d['max'] as int,
        defaultShowInCalendar: (d['default_show_in_calendar'] as int) != 0,
      );
    }).toList();
  }

  Stream<List<KindDef>> watchKinds() async* {
    yield await listKinds();
    await for (final _ in _changes.stream) {
      yield await listKinds();
    }
  }

  void dispose() {
    _changes.close();
  }
}

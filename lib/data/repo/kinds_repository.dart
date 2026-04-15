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
    this.isProtected = false,
  });

  final String id;
  final String name;
  final String unit; // canonical unit string, e.g., 'g', 'mg', 'ug', 'mL'
  final int? color; // ARGB int or null
  final String? icon; // Material icon name string or null
  final int min; // inclusive min
  final int max; // inclusive max
  final bool defaultShowInCalendar;
  final bool isProtected;
}

class KindsRepository {
  KindsRepository({required this.db}) : _ready = db.ensureInitialized();

  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Stream<void> watchChanges() => _changes.stream;

  /// Dump kinds for export (ordered by name).
  Future<List<Map<String, Object?>>> dumpKinds() async {
    final list = await listKinds();
    return list
        .map(
          (k) => {
            'id': k.id,
            'name': k.name,
            'unit': k.unit,
            'color': k.color,
            'icon': k.icon,
            'min': k.min,
            'max': k.max,
            'defaultShowInCalendar': k.defaultShowInCalendar,
            'isProtected': k.isProtected,
          },
        )
        .toList();
  }

  Future<void> upsertKind(KindDef k, {String? oldId}) async {
    await _ready;
    // Validate inputs
    if (k.name.trim().isEmpty) {
      throw ArgumentError('Kind name cannot be empty');
    }
    if (k.unit.trim().isEmpty) {
      throw ArgumentError('Kind unit cannot be empty');
    }
    if (k.min > k.max) {
      throw ArgumentError('Kind min (${k.min}) must be <= max (${k.max})');
    }

    await db.transaction(() async {
      if (oldId != null && oldId != k.id) {
        // Handle ID rename cascade
        // 1. Check if new ID already exists
        final existing = await getKind(k.id);
        if (existing != null) {
          throw StateError('Cannot rename kind to "${k.id}": ID already exists');
        }

        // 2. Perform cascade updates
        await db.customStatement('UPDATE product_components SET kind_id = ? WHERE kind_id = ?;', [k.id, oldId]);
        await db.customStatement("UPDATE recipe_components SET comp_id = ? WHERE comp_id = ? AND type = 'kind';", [k.id, oldId]);
        await db.customStatement('UPDATE entries SET widget_kind = ? WHERE widget_kind = ?;', [k.id, oldId]);
        await db.customStatement('UPDATE entries SET source_widget_kind = ? WHERE source_widget_kind = ?;', [k.id, oldId]);

        // 3. Update the kind itself (ID change)
        await db.customStatement('UPDATE kinds SET id = ? WHERE id = ?;', [k.id, oldId]);
      }

      // 4. Upsert the data (handles both new kind and existing kind after ID update)
      await db.customStatement(
        'INSERT INTO kinds (id, name, unit, color, icon, min, max, default_show_in_calendar, is_protected) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(id) DO UPDATE SET name=excluded.name, unit=excluded.unit, color=excluded.color, icon=excluded.icon, min=excluded.min, max=excluded.max, default_show_in_calendar=excluded.default_show_in_calendar, is_protected=excluded.is_protected;',
        [
          k.id,
          k.name,
          k.unit,
          k.color,
          k.icon,
          k.min,
          k.max,
          k.defaultShowInCalendar ? 1 : 0,
          k.isProtected ? 1 : 0,
        ],
      );
    });
    _notify();
  }

  Future<void> deleteKind(String id) async {
    await _ready;
    // Check if kind is used by any entries
    final entryRows = await db
        .customSelect(
          'SELECT COUNT(*) as count FROM entries WHERE widget_kind = ?;',
          variables: [Variable.withString(id)],
          readsFrom: const {},
        )
        .get();
    final entryCount = entryRows.first.data['count'] as int;
    if (entryCount > 0) {
      throw StateError(
        'Cannot delete kind "$id": used by $entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
      );
    }

    // Consider FK in product_components; for now, allow cascade-like cleanup manually.
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM product_components WHERE kind_id = ?;',
        [id],
      );
      await db.customStatement('DELETE FROM kinds WHERE id = ?;', [id]);
    });
    _notify();
  }

  Future<KindDef?> getKind(String id) async {
    await _ready;
    final rows = await db
        .customSelect(
          'SELECT * FROM kinds WHERE id = ? LIMIT 1;',
          variables: [Variable.withString(id)],
          readsFrom: const {},
        )
        .get();
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
      isProtected: (d['is_protected'] as int? ?? 0) != 0,
    );
  }

  Future<List<KindDef>> listKinds() async {
    await _ready;
    final rows = await db
        .customSelect(
          'SELECT * FROM kinds ORDER BY name ASC;',
          readsFrom: const {},
        )
        .get();
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
        isProtected: (d['is_protected'] as int? ?? 0) != 0,
      );
    }).toList();
  }

  Stream<List<KindDef>> watchKinds() async* {
    yield await listKinds();
    await for (final _ in _changes.stream) {
      yield await listKinds();
    }
  }
}

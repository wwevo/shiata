import 'dart:async';

import '../db/raw_db.dart';

class UnitDef {
  UnitDef({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class UnitsRepository {
  UnitsRepository({required this.db}) : _ready = db.ensureInitialized();

  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();

  Stream<void> watchChanges() => _changes.stream;

  Future<List<UnitDef>> listUnits() async {
    await _ready;
    final rows = await db
        .customSelect(
          'SELECT * FROM units ORDER BY id ASC;',
          readsFrom: const {},
        )
        .get();
    return rows.map((r) {
      final d = r.data;
      return UnitDef(
        id: d['id'] as String,
        label: d['label'] as String,
      );
    }).toList();
  }

  Stream<List<UnitDef>> watchUnits() async* {
    yield await listUnits();
    await for (final _ in _changes.stream) {
      yield await listUnits();
    }
  }
}

import 'dart:async';

import 'package:drift/drift.dart';

import '../db/raw_db.dart';

class SettingsRepository {
  SettingsRepository({required this.db}) : _ready = db.ensureInitialized();

  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();

  Stream<void> watchChanges() => _changes.stream;

  Future<String?> getSetting(String key) async {
    await _ready;
    final rows = await db
        .customSelect(
          'SELECT text_value FROM settings WHERE key = ?;',
          readsFrom: const {},
          variables: [Variable<String>(key)],
        )
        .get();
    if (rows.isEmpty) return null;
    final d = rows.first.data;
    return d['text_value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _ready;
    await db.customStatement(
      "INSERT OR REPLACE INTO settings (key, text_value) VALUES (?, ?);",
      [key, value],
    );
    _changes.add(null);
  }

  Stream<String?> watchSetting(String key) async* {
    yield await getSetting(key);
    await for (final _ in _changes.stream) {
      yield await getSetting(key);
    }
  }
}

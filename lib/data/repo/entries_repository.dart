import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/raw_db.dart';

class EntryRecord {
  EntryRecord({
    required this.id,
    required this.widgetKind,
    required this.createdAt,
    required this.targetAt,
    required this.showInCalendar,
    required this.payloadJson,
    required this.schemaVersion,
    required this.updatedAt,
    this.sourceEventId,
    this.sourceEntryId,
    this.sourceWidgetKind,
  });

  final String id;
  final String widgetKind;
  final int createdAt; // UTC millis
  final int targetAt; // UTC millis
  final bool showInCalendar;
  final String payloadJson;
  final int schemaVersion;
  final int updatedAt; // UTC millis
  final String? sourceEventId;
  final String? sourceEntryId;
  final String? sourceWidgetKind;

  Map<String, Object?> toDb() => {
        'id': id,
        'widget_kind': widgetKind,
        'created_at': createdAt,
        'target_at': targetAt,
        'show_in_calendar': showInCalendar ? 1 : 0,
        'payload_json': payloadJson,
        'schema_version': schemaVersion,
        'updated_at': updatedAt,
        'source_event_id': sourceEventId,
        'source_entry_id': sourceEntryId,
        'source_widget_kind': sourceWidgetKind,
      };

  static EntryRecord fromDb(Map<String, Object?> row) {
    return EntryRecord(
      id: row['id'] as String,
      widgetKind: row['widget_kind'] as String,
      createdAt: row['created_at'] as int,
      targetAt: row['target_at'] as int,
      showInCalendar: (row['show_in_calendar'] as int) != 0,
      payloadJson: row['payload_json'] as String,
      schemaVersion: row['schema_version'] as int,
      updatedAt: row['updated_at'] as int,
      sourceEventId: row['source_event_id'] as String?,
      sourceEntryId: row['source_entry_id'] as String?,
      sourceWidgetKind: row['source_widget_kind'] as String?,
    );
  }
}

class EntriesRepository {
  EntriesRepository({required this.db}) : _ready = db.ensureInitialized();
  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<EntryRecord> create({
    required String widgetKind,
    required DateTime targetAtLocal,
    required Map<String, Object?> payload,
    bool showInCalendar = true,
    int schemaVersion = 1,
    String? sourceEventId,
    String? sourceEntryId,
    String? sourceWidgetKind,
  }) async {
    await _ready;
    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
    final targetUtc = targetAtLocal.toUtc().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    final rec = EntryRecord(
      id: id,
      widgetKind: widgetKind,
      createdAt: nowUtc,
      targetAt: targetUtc,
      showInCalendar: showInCalendar,
      payloadJson: jsonEncode(payload),
      schemaVersion: schemaVersion,
      updatedAt: nowUtc,
      sourceEventId: sourceEventId,
      sourceEntryId: sourceEntryId,
      sourceWidgetKind: sourceWidgetKind,
    );

    final cols = rec.toDb().keys.join(', ');
    final placeholders = List.filled(rec.toDb().length, '?').join(', ');
    await db.customStatement(
      'INSERT INTO entries ($cols) VALUES ($placeholders);',
      rec.toDb().values.toList(),
    );
    _notify();
    return rec;
  }

  Future<void> update(String id, Map<String, Object?> patch) async {
    await _ready;
    if (patch.isEmpty) return;
    final updates = <String>[];
    final args = <Object?>[];
    patch.forEach((k, v) {
      updates.add('$k = ?');
      args.add(v);
    });
    // always bump updated_at
    updates.add('updated_at = ?');
    args.add(DateTime.now().toUtc().millisecondsSinceEpoch);
    args.add(id);
    await db.customStatement(
      'UPDATE entries SET ${updates.join(', ')} WHERE id = ?;',
      args,
    );
    _notify();
  }

  Future<void> delete(String id) async {
    await _ready;
    await db.customStatement('DELETE FROM entries WHERE id = ?;', [id]);
    _notify();
  }

  Future<EntryRecord?> getById(String id) async {
    await _ready;
    final rows = await db.customSelect(
      'SELECT * FROM entries WHERE id = ? LIMIT 1;',
      variables: [Variable.withString(id)],
      readsFrom: const {},
    ).get();
    if (rows.isEmpty) return null;
    return EntryRecord.fromDb(rows.first.data);
  }

  Stream<EntryRecord?> watchById(String id) async* {
    yield await getById(id);
    await for (final _ in _changes.stream) {
      yield await getById(id);
    }
  }

  // Helper to compute local day boundaries → UTC millis
  (int, int) _localDayRangeUtc(DateTime localDate) {
    final start = DateTime(localDate.year, localDate.month, localDate.day);
    final end = start.add(const Duration(days: 1));
    return (start.toUtc().millisecondsSinceEpoch, end.toUtc().millisecondsSinceEpoch);
  }

  Stream<List<EntryRecord>> watchByDay(DateTime localDate) async* {
    Future<List<EntryRecord>> query() async {
      final (startUtc, endUtc) = _localDayRangeUtc(localDate);
      final rows = await db.customSelect(
        'SELECT * FROM entries WHERE target_at >= ? AND target_at < ? ORDER BY target_at ASC, widget_kind ASC;',
        variables: [Variable.withInt(startUtc), Variable.withInt(endUtc)],
        readsFrom: const {},
      ).get();
      return rows.map((r) => EntryRecord.fromDb(r.data)).toList();
    }

    yield await query();
    await for (final _ in _changes.stream) {
      yield await query();
    }
  }

  Stream<Map<DateTime, List<EntryRecord>>> watchByDayRange(DateTime startLocal, DateTime endLocal, {bool onlyShowInCalendar = true}) async* {
    Future<Map<DateTime, List<EntryRecord>>> query() async {
      // Convert to UTC bounds
      final startUtc = DateTime(startLocal.year, startLocal.month, startLocal.day).toUtc().millisecondsSinceEpoch;
      final endUtc = DateTime(endLocal.year, endLocal.month, endLocal.day).toUtc().millisecondsSinceEpoch;
      final whereCalendar = onlyShowInCalendar ? 'AND show_in_calendar = 1' : '';
      final rows = await db.customSelect(
        'SELECT * FROM entries WHERE target_at >= ? AND target_at < ? $whereCalendar ORDER BY target_at ASC;',
        variables: [Variable.withInt(startUtc), Variable.withInt(endUtc)],
        readsFrom: const {},
      ).get();
      final list = rows.map((r) => EntryRecord.fromDb(r.data)).toList();
      // Group by local day
      final map = <DateTime, List<EntryRecord>>{};
      for (final rec in list) {
        final local = DateTime.fromMillisecondsSinceEpoch(rec.targetAt, isUtc: true).toLocal();
        final dayKey = DateTime(local.year, local.month, local.day);
        (map[dayKey] ??= []).add(rec);
      }
      return map;
    }

    yield await query();
    await for (final _ in _changes.stream) {
      yield await query();
    }
  }
}

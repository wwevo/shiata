import 'dart:async';

import 'package:drift/drift.dart';

import '../db/raw_db.dart';

class CollectionDef {
  CollectionDef({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.icon,
    this.color,
    this.isProtected = false,
  });

  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final bool isActive;
  final String? icon;
  final int? color;
  final bool isProtected;
}

enum CollectionComponentType { kind, product }

class CollectionComponentDef {
  CollectionComponentDef.kind({
    required this.collectionId,
    required this.compId,
    required double this.amount,
  }) : type = CollectionComponentType.kind,
        grams = null;

  CollectionComponentDef.product({
    required this.collectionId,
    required this.compId,
    required int this.grams,
  }) : type = CollectionComponentType.product,
        amount = null;

  final String collectionId;
  final CollectionComponentType type;
  final String compId; // kindId or productId
  final double? amount; // for kind components
  final int? grams; // for product components
}

class CollectionsRepository {
  CollectionsRepository({required this.db}) : _ready = db.ensureInitialized();
  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Stream<void> watchChanges() => _changes.stream;

  Future<void> upsertCollection(CollectionDef r, {String? oldId}) async {
    await _ready;
    // Validate inputs
    if (r.name.trim().isEmpty) {
      throw ArgumentError('Collection name cannot be empty');
    }

    await db.transaction(() async {
      if (oldId != null && oldId != r.id) {
        // Handle ID rename cascade
        // 1. Check if new ID already exists
        final existing = await getCollection(r.id);
        if (existing != null) {
          throw StateError('Cannot rename collection to "${r.id}": ID already exists');
        }

        // 2. Perform cascade updates
        await db.customStatement(
          'UPDATE collection_components SET collection_id = ? WHERE collection_id = ?;',
          [r.id, oldId],
        );
        await db.customStatement(
          'UPDATE entries SET recipe_id = ? WHERE recipe_id = ?;',
          [r.id, oldId],
        );

        // 3. Update the collection itself (ID change)
        await db.customStatement(
          'UPDATE collections SET id = ? WHERE id = ?;',
          [r.id, oldId],
        );
      }

      // 4. Upsert the data
      await db.customStatement(
        'INSERT INTO collections (id, name, created_at, updated_at, is_active, icon, color, is_protected) VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
            'ON CONFLICT(id) DO UPDATE SET name=excluded.name, updated_at=excluded.updated_at, is_active=excluded.is_active, icon=excluded.icon, color=excluded.color, is_protected=excluded.is_protected;',
        [
          r.id,
          r.name,
          r.createdAt,
          r.updatedAt,
          r.isActive ? 1 : 0,
          r.icon,
          r.color,
          r.isProtected ? 1 : 0,
        ],
      );
    });
    _notify();
  }

  Future<void> deleteCollection(String id) async {
    await _ready;
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM collection_components WHERE collection_id = ?;',
        [id],
      );
      await db.customStatement('DELETE FROM collections WHERE id = ?;', [id]);
    });
    _notify();
  }

  Future<CollectionDef?> getCollection(String id) async {
    await _ready;
    final rows = await db
        .customSelect(
      'SELECT * FROM collections WHERE id = ? LIMIT 1;',
      variables: [Variable.withString(id)],
      readsFrom: const {},
    )
        .get();
    if (rows.isEmpty) return null;
    final d = rows.first.data;
    return CollectionDef(
      id: d['id'] as String,
      name: d['name'] as String,
      createdAt: d['created_at'] as int,
      updatedAt: d['updated_at'] as int,
      isActive: (d['is_active'] as int) != 0,
      icon: d['icon'] as String?,
      color: d['color'] as int?,
      isProtected: (d['is_protected'] as int? ?? 0) != 0,
    );
  }

  Future<List<CollectionDef>> listCollections({bool onlyActive = true}) async {
    await _ready;
    final where = onlyActive ? 'WHERE is_active = 1' : '';
    final rows = await db
        .customSelect('SELECT * FROM collections $where ORDER BY name ASC;')
        .get();
    return rows.map((r) {
      final d = r.data;
      return CollectionDef(
        id: d['id'] as String,
        name: d['name'] as String,
        createdAt: d['created_at'] as int,
        updatedAt: d['updated_at'] as int,
        isActive: (d['is_active'] as int) != 0,
        icon: d['icon'] as String?,
        color: d['color'] as int?,
        isProtected: (d['is_protected'] as int? ?? 0) != 0,
      );
    }).toList();
  }

  Stream<List<CollectionDef>> watchCollections({bool onlyActive = true}) async* {
    yield await listCollections(onlyActive: onlyActive);
    await for (final _ in _changes.stream) {
      yield await listCollections(onlyActive: onlyActive);
    }
  }

  Future<List<CollectionComponentDef>> getComponents(String collectionId) async {
    await _ready;
    final rows = await db
        .customSelect(
      'SELECT * FROM collection_components WHERE collection_id = ?;',
      variables: [Variable.withString(collectionId)],
      readsFrom: const {},
    )
        .get();
    final list = <CollectionComponentDef>[];
    for (final r in rows) {
      final d = r.data;
      final type = (d['type'] as String);
      if (type == 'kind') {
        list.add(
          CollectionComponentDef.kind(
            collectionId: d['collection_id'] as String,
            compId: d['comp_id'] as String,
            amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      } else {
        list.add(
          CollectionComponentDef.product(
            collectionId: d['collection_id'] as String,
            compId: d['comp_id'] as String,
            grams: (d['grams'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return list;
  }

  Future<List<CollectionComponentDef>> listAllComponents() async {
    await _ready;
    final rows = await db
        .customSelect(
          'SELECT * FROM collection_components ORDER BY collection_id ASC;',
          readsFrom: const {},
        )
        .get();
    final list = <CollectionComponentDef>[];
    for (final r in rows) {
      final d = r.data;
      final type = (d['type'] as String);
      if (type == 'kind') {
        list.add(
          CollectionComponentDef.kind(
            collectionId: d['collection_id'] as String,
            compId: d['comp_id'] as String,
            amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      } else {
        list.add(
          CollectionComponentDef.product(
            collectionId: d['collection_id'] as String,
            compId: d['comp_id'] as String,
            grams: (d['grams'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return list;
  }

  Stream<List<CollectionComponentDef>> watchAllComponents() async* {
    yield await listAllComponents();
    await for (final _ in _changes.stream) {
      yield await listAllComponents();
    }
  }

  /// Watch collection components (reactive).
  Stream<List<CollectionComponentDef>> watchComponents(String collectionId) async* {
    yield await getComponents(collectionId);
    await for (final _ in _changes.stream) {
      yield await getComponents(collectionId);
    }
  }

  Future<void> setComponents(
      String collectionId,
      List<CollectionComponentDef> comps,
      ) async {
    await _ready;
    await db.transaction(() async {
      await db.customStatement(
        'DELETE FROM collection_components WHERE collection_id = ?;',
        [collectionId],
      );
      for (final c in comps) {
        if (c.type == CollectionComponentType.kind) {
          await db.customStatement(
            "INSERT INTO collection_components (collection_id, type, comp_id, amount, grams) VALUES (?, 'kind', ?, ?, NULL);",
            [collectionId, c.compId, c.amount],
          );
        } else {
          await db.customStatement(
            "INSERT INTO collection_components (collection_id, type, comp_id, amount, grams) VALUES (?, 'product', ?, NULL, ?);",
            [collectionId, c.compId, c.grams],
          );
        }
      }
    });
    _notify();
  }

  /// Export all collections with components as JSON-serializable maps
  Future<List<Map<String, Object?>>> dumpCollections() async {
    final list = await listCollections(onlyActive: false);
    final out = <Map<String, Object?>>[];
    for (final r in list) {
      final comps = await getComponents(r.id);
      out.add({
        'id': r.id,
        'name': r.name,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'isActive': r.isActive,
        'icon': r.icon,
        'color': r.color,
        'isProtected': r.isProtected,
        'components': [
          for (final c in comps)
            {
              'type': c.type == CollectionComponentType.kind ? 'kind' : 'product',
              'compId': c.compId,
              'amount': c.amount,
              'grams': c.grams,
            },
        ],
      });
    }
    return out;
  }
}

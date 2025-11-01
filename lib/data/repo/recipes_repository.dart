import 'dart:async';

import 'package:drift/drift.dart';

import '../db/raw_db.dart';

class RecipeDef {
  RecipeDef({required this.id, required this.name, required this.createdAt, required this.updatedAt, this.isActive = true, this.icon, this.color});
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final bool isActive;
  final String? icon;
  final int? color;
}

enum RecipeComponentType { kind, product }

class RecipeComponentDef {
  RecipeComponentDef.kind({required this.recipeId, required this.compId, required double amount})
      : type = RecipeComponentType.kind,
        this.amount = amount,
        this.grams = null;
  RecipeComponentDef.product({required this.recipeId, required this.compId, required int grams})
      : type = RecipeComponentType.product,
        this.amount = null,
        this.grams = grams;

  final String recipeId;
  final RecipeComponentType type;
  final String compId; // kindId or productId
  final double? amount; // for kind components
  final int? grams; // for product components
}

class RecipesRepository {
  RecipesRepository({required this.db}) : _ready = db.ensureInitialized();
  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();
  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> upsertRecipe(RecipeDef r) async {
    await _ready;
    await db.customStatement(
      'INSERT INTO recipes (id, name, created_at, updated_at, is_active, icon, color) VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET name=excluded.name, updated_at=excluded.updated_at, is_active=excluded.is_active, icon=excluded.icon, color=excluded.color;',
      [r.id, r.name, r.createdAt, r.updatedAt, r.isActive ? 1 : 0, r.icon, r.color],
    );
    _notify();
  }

  Future<void> deleteRecipe(String id) async {
    await _ready;
    await db.transaction(() async {
      await db.customStatement('DELETE FROM recipe_components WHERE recipe_id = ?;', [id]);
      await db.customStatement('DELETE FROM recipes WHERE id = ?;', [id]);
    });
    _notify();
  }

  Future<RecipeDef?> getRecipe(String id) async {
    await _ready;
    final rows = await db.customSelect('SELECT * FROM recipes WHERE id = ? LIMIT 1;', variables: [Variable.withString(id)], readsFrom: const {}).get();
    if (rows.isEmpty) return null;
    final d = rows.first.data;
    return RecipeDef(
      id: d['id'] as String,
      name: d['name'] as String,
      createdAt: d['created_at'] as int,
      updatedAt: d['updated_at'] as int,
      isActive: (d['is_active'] as int) != 0,
      icon: d['icon'] as String?,
      color: d['color'] as int?,
    );
  }

  Future<List<RecipeDef>> listRecipes({bool onlyActive = true}) async {
    await _ready;
    final where = onlyActive ? 'WHERE is_active = 1' : '';
    final rows = await db.customSelect('SELECT * FROM recipes $where ORDER BY name ASC;').get();
    return rows.map((r) {
      final d = r.data;
      return RecipeDef(
        id: d['id'] as String,
        name: d['name'] as String,
        createdAt: d['created_at'] as int,
        updatedAt: d['updated_at'] as int,
        isActive: (d['is_active'] as int) != 0,
        icon: d['icon'] as String?,
        color: d['color'] as int?,
      );
    }).toList();
  }

  Stream<List<RecipeDef>> watchRecipes({bool onlyActive = true}) async* {
    yield await listRecipes(onlyActive: onlyActive);
    await for (final _ in _changes.stream) {
      yield await listRecipes(onlyActive: onlyActive);
    }
  }

  Future<List<RecipeComponentDef>> getComponents(String recipeId) async {
    await _ready;
    final rows = await db.customSelect('SELECT * FROM recipe_components WHERE recipe_id = ?;', variables: [Variable.withString(recipeId)], readsFrom: const {}).get();
    final list = <RecipeComponentDef>[];
    for (final r in rows) {
      final d = r.data;
      final type = (d['type'] as String);
      if (type == 'kind') {
        list.add(RecipeComponentDef.kind(recipeId: d['recipe_id'] as String, compId: d['comp_id'] as String, amount: (d['amount'] as num?)?.toDouble() ?? 0.0));
      } else {
        list.add(RecipeComponentDef.product(recipeId: d['recipe_id'] as String, compId: d['comp_id'] as String, grams: (d['grams'] as num?)?.toInt() ?? 0));
      }
    }
    return list;
  }

  Future<void> setComponents(String recipeId, List<RecipeComponentDef> comps) async {
    await _ready;
    await db.transaction(() async {
      await db.customStatement('DELETE FROM recipe_components WHERE recipe_id = ?;', [recipeId]);
      for (final c in comps) {
        if (c.type == RecipeComponentType.kind) {
          await db.customStatement(
            "INSERT INTO recipe_components (recipe_id, type, comp_id, amount, grams) VALUES (?, 'kind', ?, ?, NULL);",
            [recipeId, c.compId, c.amount],
          );
        } else {
          await db.customStatement(
            "INSERT INTO recipe_components (recipe_id, type, comp_id, amount, grams) VALUES (?, 'product', ?, NULL, ?);",
            [recipeId, c.compId, c.grams],
          );
        }
      }
    });
    _notify();
  }

  void dispose() {
    _changes.close();
  }
}

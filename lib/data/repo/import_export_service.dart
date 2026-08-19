import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/raw_db.dart';
import '../providers.dart';
import 'entries_repository.dart';
import 'kinds_repository.dart';
import 'products_repository.dart';
import 'recipes_repository.dart';

class ImportResult {
  ImportResult({
    required this.kindsUpserted,
    required this.productsUpserted,
    required this.recipesUpserted,
    required this.componentsWritten,
    required this.warnings,
  });

  final int kindsUpserted;
  final int productsUpserted;
  final int recipesUpserted;
  final int componentsWritten;
  final List<String> warnings;
}

class ImportExportService {
  ImportExportService({
    required this.db,
    required this.kinds,
    required this.products,
    required this.recipes,
    required this.entries,
  });

  final AppDb db;
  final KindsRepository kinds;
  final ProductsRepository products;
  final RecipesRepository recipes;
  final EntriesRepository entries;

  /// Export full bundle including entries.
  Future<Map<String, Object?>> exportBundle() async {
    final kindsList = await kinds.dumpKinds();
    final productsList = await products.dumpProductsWithComponents();
    final recipesList = await recipes.dumpRecipes();
    final entriesList = await entries.dumpEntries();
    return <String, Object?>{
      'version': 1,
      'kinds': kindsList,
      'products': productsList,
      'recipes': recipesList,
      'entries': entriesList,
    };
  }

  /// Load initial seeds from assets and import them (destructive).
  Future<ImportResult> seedInitialData() async {
    const assetPath = 'assets/debug/db_seeds/initial_seeds.json';
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      return await importBundle(jsonStr);
    } catch (e) {
      throw StateError('Failed to load initial seeds from $assetPath: $e');
    }
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
    int recipesUpserted = 0;
    int componentsWritten = 0;

    // Wipe existing data first (entries → recipe_components → recipes → product_components → products → kinds)
    await db.transaction(() async {
      await db.customStatement('DELETE FROM entries;');
      await db.customStatement('DELETE FROM recipe_components;');
      await db.customStatement('DELETE FROM recipes;');
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
      final defaultShow =
          item['defaultShowInCalendar'] == true ||
          item['defaultShowInCalendar'] == 1;
      final isProtected = item['isProtected'] == true || item['isProtected'] == 1;
      await kinds.upsertKind(
        KindDef(
          id: id,
          name: name,
          unit: unit,
          color: color,
          icon: (icon == null || icon.isEmpty) ? null : icon,
          min: min,
          max: max,
          defaultShowInCalendar: defaultShow,
          isProtected: isProtected,
        ),
      );
      kindsUpserted++;
    }

    // Products + components
    final prodsArr = (root['products'] as List?) ?? const [];
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final item in prodsArr) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString().trim();
      final name = (item['name'] ?? '').toString().trim();
      final icon = (item['icon'] as String?)?.trim();
      final colorVal = item['color'];
      final color = colorVal is int
          ? colorVal
          : (colorVal is String && int.tryParse(colorVal) != null)
          ? int.parse(colorVal)
          : null;
      final isProtected = item['isProtected'] == true || item['isProtected'] == 1;
      final createdAt = _asInt(item['createdAt']) ?? now;
      final updatedAt = _asInt(item['updatedAt']) ?? now;
      final isActive = item['isActive'] != false && item['isActive'] != 0;

      await products.upsertProduct(
        ProductDef(
          id: id,
          name: name,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isActive: isActive,
          icon: (icon == null || icon.isEmpty) ? null : icon,
          color: color,
          isProtected: isProtected,
        ),
      );
      productsUpserted++;

      final comps = <ProductComponent>[];
      final compsArr = (item['components'] as List?) ?? const [];
      for (final c in compsArr) {
        if (c is! Map) continue;
        final kindId = (c['kindId'] ?? '').toString().trim();
        final per100Raw = c['per100'];
        final per100 = (per100Raw is num)
            ? per100Raw.toDouble()
            : double.tryParse(per100Raw?.toString() ?? '0') ?? 0.0;
        comps.add(
          ProductComponent(
            productId: id,
            kindId: kindId,
            amountPerGram: per100,
          ),
        );
      }
      await products.setComponents(id, comps);
      componentsWritten += comps.length;
    }

    // Recipes + components
    final recipesArr = (root['recipes'] as List?) ?? const [];
    for (final item in recipesArr) {
      if (item is! Map) continue;
      final id = (item['id'] ?? '').toString().trim();
      final name = (item['name'] ?? '').toString().trim();
      final createdAt = _asInt(item['createdAt']) ?? now;
      final updatedAt = _asInt(item['updatedAt']) ?? now;
      final isActive = item['isActive'] == true || item['isActive'] == 1;
      final icon = (item['icon'] as String?)?.trim();
      final colorVal = item['color'];
      final color = colorVal is int
          ? colorVal
          : (colorVal is String && int.tryParse(colorVal) != null)
          ? int.parse(colorVal)
          : null;
      final isProtected = item['isProtected'] == true || item['isProtected'] == 1;
      await recipes.upsertRecipe(
        RecipeDef(
          id: id,
          name: name,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isActive: isActive,
          icon: (icon == null || icon.isEmpty) ? null : icon,
          color: color,
          isProtected: isProtected,
        ),
      );
      recipesUpserted++;

      final comps = <RecipeComponentDef>[];
      final compsArr = (item['components'] as List?) ?? const [];
      for (final c in compsArr) {
        if (c is! Map) continue;
        final type = (c['type'] ?? '').toString().trim();
        final compId = (c['compId'] ?? '').toString().trim();
        if (type == 'kind') {
          final amountRaw = c['amount'];
          final amount = (amountRaw is num)
              ? amountRaw.toDouble()
              : double.tryParse(amountRaw?.toString() ?? '0') ?? 0.0;
          comps.add(
            RecipeComponentDef.kind(
              recipeId: id,
              compId: compId,
              amount: amount,
            ),
          );
        } else if (type == 'product') {
          final gramsVal = _asInt(c['grams']) ?? 0;
          comps.add(
            RecipeComponentDef.product(
              recipeId: id,
              compId: compId,
              grams: gramsVal,
            ),
          );
        }
      }
      await recipes.setComponents(id, comps);
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
      recipesUpserted: recipesUpserted,
      componentsWritten: componentsWritten,
      warnings: const <String>[],
    );
  }

  /// Export selected items with automatic dependency resolution.
  /// Dependencies are automatically included:
  /// - Products include their component kinds
  /// - Recipes include their ingredient products and those products' component kinds
  Future<Map<String, Object?>> exportSelected({
    List<String>? kindIds,
    List<String>? productIds,
    List<String>? recipeIds,
    List<String>? entryIds,
    bool includeEntries = false,
  }) async {
    final selectedKindIds = <String>{...?kindIds};
    final selectedProductIds = <String>{...?productIds};
    final selectedRecipeIds = <String>{...?recipeIds};

    // Resolve dependencies: products → component kinds
    for (final productId in List<String>.from(selectedProductIds)) {
      final components = await products.getComponents(productId);
      for (final c in components) {
        selectedKindIds.add(c.kindId);
      }
    }

    // Resolve dependencies: recipes → ingredient products → component kinds
    for (final recipeId in List<String>.from(selectedRecipeIds)) {
      final components = await recipes.getComponents(recipeId);
      for (final c in components) {
        if (c.type == RecipeComponentType.product) {
          selectedProductIds.add(c.compId);
          // Also get that product's component kinds
          final prodComponents = await products.getComponents(c.compId);
          for (final pc in prodComponents) {
            selectedKindIds.add(pc.kindId);
          }
        } else if (c.type == RecipeComponentType.kind) {
          selectedKindIds.add(c.compId);
        }
      }
    }

    // Now export only the selected items
    final kindsList = <Map<String, Object?>>[];
    for (final id in selectedKindIds) {
      final k = await kinds.getKind(id);
      if (k != null) {
        kindsList.add({
          'id': k.id,
          'name': k.name,
          'unit': k.unit,
          'color': k.color,
          'icon': k.icon,
          'min': k.min,
          'max': k.max,
          'defaultShowInCalendar': k.defaultShowInCalendar,
          'isProtected': k.isProtected,
        });
      }
    }

    final productsList = <Map<String, Object?>>[];
    for (final id in selectedProductIds) {
      final p = await products.getProduct(id);
      if (p != null) {
        final comps = await products.getComponents(id);
        productsList.add({
          'id': p.id,
          'name': p.name,
          'createdAt': p.createdAt,
          'updatedAt': p.updatedAt,
          'isActive': p.isActive,
          'icon': p.icon,
          'color': p.color,
          'isProtected': p.isProtected,
          'components': [
            for (final c in comps)
              {'kindId': c.kindId, 'per100': c.amountPerGram},
          ],
        });
      }
    }

    final recipesList = <Map<String, Object?>>[];
    for (final id in selectedRecipeIds) {
      final r = await recipes.getRecipe(id);
      if (r != null) {
        final comps = await recipes.getComponents(id);
        recipesList.add({
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
                'type': c.type == RecipeComponentType.kind ? 'kind' : 'product',
                'compId': c.compId,
                'amount': c.amount,
                'grams': c.grams,
              },
          ],
        });
      }
    }

    final bundle = <String, Object?>{
      'version': 1,
      'kinds': kindsList,
      'products': productsList,
      'recipes': recipesList,
    };

    // Include specific entries if entryIds provided
    if (entryIds != null && entryIds.isNotEmpty) {
      final entriesList = <Map<String, Object?>>[];
      final allEntries = await entries.dumpEntries();

      for (final entryData in allEntries) {
        final entryId = entryData['id'] as String;
        if (entryIds.contains(entryId)) {
          entriesList.add(entryData);
        }
      }

      bundle['entries'] = entriesList;
    } else if (includeEntries) {
      // Include all entries related to selected items
      // TODO: Implement filtered entry export based on selected kinds/products/recipes
      bundle['entries'] = const <Map<String, Object?>>[];
    }

    return bundle;
  }

  EntryRecord _entryFromMap(Map raw) {
    int asInt(Object? v) => _asInt(v) ?? 0;
    bool asBool(Object? v) => (v is bool)
        ? v
        : (v is num)
        ? v != 0
        : v == '1' || v == 'true';
    return EntryRecord(
      id: (raw['id'] ?? '').toString(),
      widgetKind: (raw['widget_kind'] ?? '').toString(),
      createdAt: asInt(raw['created_at']),
      targetAt: asInt(raw['target_at']),
      showInCalendar: asBool(raw['show_in_calendar']),
      payloadJson: (raw['payload_json'] ?? '{}').toString(),
      updatedAt: asInt(raw['updated_at']),
      sourceEntryId:
          (raw['source_entry_id'] as String?) ??
          (raw['sourceEntryId'] as String?),
      sourceWidgetKind:
          (raw['source_widget_kind'] as String?) ??
          (raw['sourceWidgetKind'] as String?),
      productId:
          (raw['product_id'] as String?) ?? (raw['productId'] as String?),
      productGrams: _asInt(raw['product_grams']),
      recipeId: (raw['recipe_id'] as String?) ?? (raw['recipeId'] as String?),
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
  final rr = ref.watch(recipesRepositoryProvider);
  final er = ref.watch(entriesRepositoryProvider);
  if (db == null || kr == null || pr == null || rr == null || er == null) {
    return null;
  }
  return ImportExportService(
    db: db,
    kinds: kr,
    products: pr,
    recipes: rr,
    entries: er,
  );
});

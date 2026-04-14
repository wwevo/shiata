// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;

import 'package:shiata/data/db/raw_db.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/data/repo/entries_repository.dart';
import 'package:shiata/data/repo/import_export_service.dart';

void main() {
  // Suppress drift warnings about multiple database instances in tests
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Export Dependencies Tests', () {
    late AppDb db;
    late KindsRepository kinds;
    late ProductsRepository products;
    late RecipesRepository recipes;
    late EntriesRepository entries;
    late ImportExportService service;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      kinds = KindsRepository(db: db);
      products = ProductsRepository(db: db);
      recipes = RecipesRepository(db: db);
      entries = EntriesRepository(db: db);
      service = ImportExportService(
        db: db,
        kinds: kinds,
        products: products,
        recipes: recipes,
        entries: entries,
      );

      // Setup test data
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Create kinds
      await kinds.upsertKind(KindDef(
        id: 'vitamin_c',
        name: 'Vitamin C',
        unit: 'mg',
        color: null,
        icon: null,
        min: 0,
        max: 100000,
        defaultShowInCalendar: false,
      ));
      await kinds.upsertKind(KindDef(
        id: 'protein',
        name: 'Protein',
        unit: 'g',
        color: null,
        icon: null,
        min: 0,
        max: 100000,
        defaultShowInCalendar: false,
      ));

      // Create product with components
      await products.upsertProduct(ProductDef(
        id: 'banana',
        name: 'Banana',
        createdAt: now,
        updatedAt: now,
      ));
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'vitamin_c', amountPerGram: 5.0),
        ProductComponent(productId: 'banana', kindId: 'protein', amountPerGram: 1.0),
      ]);

      await products.upsertProduct(ProductDef(
        id: 'apple',
        name: 'Apple',
        createdAt: now,
        updatedAt: now,
      ));
      await products.setComponents('apple', [
        ProductComponent(productId: 'apple', kindId: 'vitamin_c', amountPerGram: 3.0),
      ]);

      // Create recipe with product components
      await recipes.upsertRecipe(RecipeDef(
        id: 'fruit_salad',
        name: 'Fruit Salad',
        color: null,
        icon: null,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      ));
      await recipes.setComponents('fruit_salad', [
        RecipeComponentDef.product(
          recipeId: 'fruit_salad',
          compId: 'banana',
          grams: 100,
        ),
        RecipeComponentDef.product(
          recipeId: 'fruit_salad',
          compId: 'apple',
          grams: 50,
        ),
      ]);
    });

    test('Export product: includes its component kinds', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Export Product with Kind Dependencies');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // Export only banana product
      final bundle = await service.exportSelected(
        productIds: ['banana'],
      );

      final exportedProducts = (bundle['products'] as List?)?.map((p) => p['id']).toList() ?? [];
      final exportedKinds = (bundle['kinds'] as List?)?.map((k) => k['id']).toList() ?? [];

      print('INIT:     Created banana product with vitamin_c and protein components');
      print('ACTION:   Export selected products: [banana]');
      print('EXPECTED: Exported products: [banana], exported kinds: [vitamin_c, protein]');
      print('ACTUAL:   Exported products: $exportedProducts, exported kinds: $exportedKinds\n');

      expect(exportedProducts, contains('banana'));
      expect(exportedKinds, containsAll(['vitamin_c', 'protein']));

      print('RESULT:   ✅ PASS - Product export includes all component kinds');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('Export recipe: includes products and their kinds', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Export Recipe with Product and Kind Dependencies');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // Export only fruit_salad recipe
      final bundle = await service.exportSelected(
        recipeIds: ['fruit_salad'],
      );

      final exportedRecipes = (bundle['recipes'] as List?)?.map((r) => r['id']).toList() ?? [];
      final exportedProducts = (bundle['products'] as List?)?.map((p) => p['id']).toList() ?? [];
      final exportedKinds = (bundle['kinds'] as List?)?.map((k) => k['id']).toList() ?? [];

      print('INIT:     Created fruit_salad recipe with banana and apple products');
      print('ACTION:   Export selected recipes: [fruit_salad]');
      print('EXPECTED: Exported recipes: [fruit_salad], products: [banana, apple], kinds: [vitamin_c, protein]');
      print('ACTUAL:   Exported recipes: $exportedRecipes, products: $exportedProducts, kinds: $exportedKinds\n');

      expect(exportedRecipes, contains('fruit_salad'));
      expect(exportedProducts, containsAll(['banana', 'apple']));
      expect(exportedKinds, containsAll(['vitamin_c', 'protein']));

      print('RESULT:   ✅ PASS - Recipe export includes all product and kind dependencies');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('Export multiple items: deduplicates shared dependencies', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Export Multiple Items with Shared Dependencies');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // Export both products (both share vitamin_c)
      final bundle = await service.exportSelected(
        productIds: ['banana', 'apple'],
      );

      final exportedProducts = (bundle['products'] as List?)?.map((p) => p['id']).toList() ?? [];
      final exportedKinds = (bundle['kinds'] as List?)?.map((k) => k['id']).toList() ?? [];

      print('INIT:     banana has [vitamin_c, protein], apple has [vitamin_c]');
      print('ACTION:   Export selected products: [banana, apple]');
      print('EXPECTED: Exported products: [banana, apple], kinds: [vitamin_c, protein] (deduplicated)');
      print('ACTUAL:   Exported products: $exportedProducts, kinds: $exportedKinds\n');

      expect(exportedProducts, containsAll(['banana', 'apple']));
      expect(exportedKinds, containsAll(['vitamin_c', 'protein']));
      // Ensure vitamin_c is not duplicated
      final vitCCount = exportedKinds.where((k) => k == 'vitamin_c').length;
      expect(vitCCount, 1);

      print('RESULT:   ✅ PASS - Shared dependencies are deduplicated');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('Export kind only: no extra dependencies', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Export Kind without Dependencies');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // Export only vitamin_c kind
      final bundle = await service.exportSelected(
        kindIds: ['vitamin_c'],
      );

      final exportedKinds = (bundle['kinds'] as List?)?.map((k) => k['id']).toList() ?? [];
      final exportedProducts = (bundle['products'] as List?) ?? [];
      final exportedRecipes = (bundle['recipes'] as List?) ?? [];

      print('INIT:     Created vitamin_c kind (used by banana and apple)');
      print('ACTION:   Export selected kinds: [vitamin_c]');
      print('EXPECTED: Exported kinds: [vitamin_c], products: [], recipes: []');
      print('ACTUAL:   Exported kinds: $exportedKinds, products: ${exportedProducts.length}, recipes: ${exportedRecipes.length}\n');

      expect(exportedKinds, contains('vitamin_c'));
      expect(exportedProducts, isEmpty);
      expect(exportedRecipes, isEmpty);

      print('RESULT:   ✅ PASS - Kind export does not include dependent products/recipes');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });
}

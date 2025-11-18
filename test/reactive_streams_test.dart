// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import 'package:shiata/data/db/raw_db.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/data/repo/entries_repository.dart';

void main() {
  // Suppress drift warnings about multiple database instances in tests
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Reactive Streams Tests', () {
    late AppDb db;
    late KindsRepository kinds;
    late ProductsRepository products;
    late RecipesRepository recipes;
    late EntriesRepository entries;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      kinds = KindsRepository(db: db);
      products = ProductsRepository(db: db);
      recipes = RecipesRepository(db: db);
      entries = EntriesRepository(db: db);
    });

    tearDown(() async {
      kinds.dispose();
      products.dispose();
      recipes.dispose();
      entries.dispose();
      await db.close();
    });

    test('watchKinds: stream emits initial value', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchKinds - Initial Emission');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final first = await kinds.watchKinds().first;

      print('INIT:     Stream created');
      print('EXPECTED: Stream should emit initial empty list');
      print('ACTUAL:   Received list with ${first.length} items\n');

      expect(first, isA<List<KindDef>>());
      print('RESULT:   ✅ PASS - Stream emitted initial value');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchKinds: stream emits after CREATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchKinds - Reactive CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stream = kinds.watchKinds();

      // Take first 2 emissions: initial + after create
      final emissions = stream.take(2).toList();

      // Wait for initial emission
      await stream.first;
      print('INIT:     Initial kinds count: 0');

      // ACTION: Create new kind
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
      print('ACTION:   Created kind "protein"');

      // Wait for emissions to complete
      final results = await emissions;

      print('EXPECTED: Stream should emit 2 times (initial + after create)');
      print('ACTUAL:   Initial: ${results[0].length}, Final: ${results[1].length}\n');

      expect(results.length, 2);
      expect(results[0].length, 0);
      expect(results[1].length, 1);
      print('RESULT:   ✅ PASS - Stream reactively emitted after CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchProducts: stream emits after CREATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchProducts - Reactive CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stream = products.watchProducts();
      final emissions = stream.take(2).toList();

      await stream.first;
      print('INIT:     Initial products count: 0');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await products.upsertProduct(ProductDef(
        id: 'apple',
        name: 'Apple',
        createdAt: now,
        updatedAt: now,
      ));
      print('ACTION:   Created product "apple"');

      final results = await emissions;

      print('EXPECTED: Stream should emit new list with +1 product');
      print('ACTUAL:   Initial: ${results[0].length}, Final: ${results[1].length}\n');

      expect(results[1].length, 1);
      print('RESULT:   ✅ PASS - Stream reactively emitted after CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchRecipes: stream emits after CREATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchRecipes - Reactive CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stream = recipes.watchRecipes();
      final emissions = stream.take(2).toList();

      await stream.first;
      print('INIT:     Initial recipes count: 0');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await recipes.upsertRecipe(RecipeDef(
        id: 'smoothie',
        name: 'Green Smoothie',
        createdAt: now,
        updatedAt: now,
      ));
      print('ACTION:   Created recipe "smoothie"');

      final results = await emissions;

      print('EXPECTED: Stream should emit new list with +1 recipe');
      print('ACTUAL:   Initial: ${results[0].length}, Final: ${results[1].length}\n');

      expect(results[1].length, 1);
      print('RESULT:   ✅ PASS - Stream reactively emitted after CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchComponents: stream emits after component changes (v0.8.5)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchComponents - Reactive Component Changes (NEW in v0.8.5)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create recipe
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await recipes.upsertRecipe(RecipeDef(
        id: 'smoothie',
        name: 'Green Smoothie',
        createdAt: now,
        updatedAt: now,
      ));

      final stream = recipes.watchComponents('smoothie');

      // Take 3 emissions: initial (empty) + after add + after update
      final emissions = stream.take(3).toList();

      await stream.first;
      print('INIT:     Initial components count: 0');

      // ACTION: Add components
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'protein', amount: 30.0),
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 100.0),
      ]);
      print('ACTION:   Added 2 components to recipe');

      // ACTION: Update components (remove one)
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'protein', amount: 35.0),
      ]);
      print('ACTION:   Removed vitamin_c component, updated protein amount');

      final results = await emissions;

      print('EXPECTED: Stream should emit 3 times with counts [0, 2, 1]');
      print('ACTUAL:   Counts: [${results[0].length}, ${results[1].length}, ${results[2].length}]');
      print('          Final amount: ${results[2].first.amount}\n');

      expect(results[0].length, 0);
      expect(results[1].length, 2);
      expect(results[2].length, 1);
      expect(results[2].first.amount, 35.0);
      print('RESULT:   ✅ PASS - Stream reactively emitted after component changes');
      print('          This fixes the _RecipeTemplateSummary FutureBuilder bug from v0.8.4');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchById: stream emits after entry updated', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchById - Reactive Single Entry Updates');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create entry
      final entry = await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 18, 10, 0),
        payload: {'amount': 25.0},
      );
      print('INIT:     Created entry with id: ${entry.id}');

      final stream = entries.watchById(entry.id);
      final emissions = stream.take(2).toList();

      await stream.first;

      // ACTION: Update entry
      await entries.update(entry.id, {
        'payload_json': '{"amount": 35.0}',
      });
      print('ACTION:   Updated amount from 25.0 to 35.0');

      final results = await emissions;

      print('EXPECTED: Stream should emit updated entry');
      print('ACTUAL:   Initial payload: ${results[0]?.payloadJson}');
      print('          Updated payload: ${results[1]?.payloadJson}\n');

      expect(results[1]?.payloadJson, contains('35.0'));
      print('RESULT:   ✅ PASS - Stream reactively emitted after entry update');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchById: stream emits null after entry deleted', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchById - Reactive Entry Deletion');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create entry
      final entry = await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 18, 10, 0),
        payload: {'amount': 25.0},
      );
      print('INIT:     Created entry with id: ${entry.id}');

      final stream = entries.watchById(entry.id);
      final emissions = stream.take(2).toList();

      await stream.first;

      // ACTION: Delete entry
      await entries.delete(entry.id);
      print('ACTION:   Deleted entry');

      final results = await emissions;

      print('EXPECTED: Stream should emit null after deletion');
      print('ACTUAL:   Initial: entry exists = ${results[0] != null}');
      print('          After delete: entry exists = ${results[1] != null}\n');

      expect(results[0], isNotNull);
      expect(results[1], isNull);
      print('RESULT:   ✅ PASS - Stream reactively emitted null after deletion');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });
}

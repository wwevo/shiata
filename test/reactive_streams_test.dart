// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;

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

    test('watchKinds: stream emits after CREATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchKinds - Reactive CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stream = kinds.watchKinds();
      final emittedValues = <List<KindDef>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emittedValues.last.length;
      print('INIT:     Initial kinds count: $initialCount');

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

      await Future.delayed(const Duration(milliseconds: 50));
      final finalCount = emittedValues.last.length;

      print('EXPECTED: Stream should emit new list with +1 kind');
      print('ACTUAL:   Initial: $initialCount, Final: $finalCount\n');

      expect(finalCount, initialCount + 1);
      expect(emittedValues.length, greaterThan(1));
      print('RESULT:   ✅ PASS - Stream reactively emitted after CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchKinds: stream emits after UPDATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchKinds - Reactive UPDATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create initial kind
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

      final stream = kinds.watchKinds();
      final emittedValues = <List<KindDef>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final oldName = emittedValues.last.first.name;
      print('INIT:     Kind name: "$oldName"');

      // ACTION: Update kind name
      await kinds.upsertKind(KindDef(
        id: 'vitamin_c',
        name: 'Vitamin C (Ascorbic Acid)',
        unit: 'mg',
        color: null,
        icon: null,
        min: 0,
        max: 100000,
        defaultShowInCalendar: false,
      ));
      print('ACTION:   Updated kind name to "Vitamin C (Ascorbic Acid)"');

      await Future.delayed(const Duration(milliseconds: 50));
      final newName = emittedValues.last.first.name;

      print('EXPECTED: Stream should emit updated list with new name');
      print('ACTUAL:   Old: "$oldName", New: "$newName"\n');

      expect(newName, 'Vitamin C (Ascorbic Acid)');
      expect(emittedValues.length, greaterThan(1));
      print('RESULT:   ✅ PASS - Stream reactively emitted after UPDATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchProducts: stream emits after CREATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchProducts - Reactive CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stream = products.watchProducts();
      final emittedValues = <List<ProductDef>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emittedValues.last.length;
      print('INIT:     Initial products count: $initialCount');

      // ACTION: Create new product
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await products.upsertProduct(ProductDef(
        id: 'apple',
        name: 'Apple',
        createdAt: now,
        updatedAt: now,
      ));
      print('ACTION:   Created product "apple"');

      await Future.delayed(const Duration(milliseconds: 50));
      final finalCount = emittedValues.last.length;

      print('EXPECTED: Stream should emit new list with +1 product');
      print('ACTUAL:   Initial: $initialCount, Final: $finalCount\n');

      expect(finalCount, initialCount + 1);
      expect(emittedValues.length, greaterThan(1));
      print('RESULT:   ✅ PASS - Stream reactively emitted after CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchRecipes: stream emits after CREATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchRecipes - Reactive CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stream = recipes.watchRecipes();
      final emittedValues = <List<RecipeDef>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emittedValues.last.length;
      print('INIT:     Initial recipes count: $initialCount');

      // ACTION: Create new recipe
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await recipes.upsertRecipe(RecipeDef(
        id: 'smoothie',
        name: 'Green Smoothie',
        createdAt: now,
        updatedAt: now,
      ));
      print('ACTION:   Created recipe "smoothie"');

      await Future.delayed(const Duration(milliseconds: 50));
      final finalCount = emittedValues.last.length;

      print('EXPECTED: Stream should emit new list with +1 recipe');
      print('ACTUAL:   Initial: $initialCount, Final: $finalCount\n');

      expect(finalCount, initialCount + 1);
      expect(emittedValues.length, greaterThan(1));
      print('RESULT:   ✅ PASS - Stream reactively emitted after CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
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
      final emittedValues = <List<RecipeComponentDef>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emittedValues.last.length;
      print('INIT:     Initial components count: $initialCount');

      // ACTION: Add components
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'protein', amount: 30.0),
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 100.0),
      ]);
      print('ACTION:   Added 2 components to recipe');

      await Future.delayed(const Duration(milliseconds: 50));
      final afterAddCount = emittedValues.last.length;

      print('EXPECTED: Stream should emit with 2 components');
      print('ACTUAL:   Initial: $initialCount, After add: $afterAddCount');

      expect(afterAddCount, 2);
      expect(emittedValues.length, greaterThan(1));

      // ACTION: Update components (remove one)
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'protein', amount: 35.0),
      ]);
      print('ACTION:   Removed vitamin_c component, updated protein amount');

      await Future.delayed(const Duration(milliseconds: 50));
      final afterUpdateCount = emittedValues.last.length;
      final updatedAmount = emittedValues.last.first.amount;

      print('EXPECTED: Stream should emit with 1 component, amount = 35.0');
      print('ACTUAL:   Final count: $afterUpdateCount, amount: $updatedAmount\n');

      expect(afterUpdateCount, 1);
      expect(updatedAmount, 35.0);
      expect(emittedValues.length, greaterThan(2));
      print('RESULT:   ✅ PASS - Stream reactively emitted after component changes');
      print('          This fixes the _RecipeTemplateSummary FutureBuilder bug from v0.8.4');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchByDay: stream emits after entry created for specific day', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchByDay - Reactive Day-Specific Entries');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final targetDay = DateTime(2025, 11, 18);
      final stream = entries.watchByDay(targetDay);
      final emittedValues = <List<EntryRecord>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emittedValues.last.length;
      print('INIT:     Initial entries for 2025-11-18: $initialCount');

      // ACTION: Create entry for target day
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 18, 10, 0),
        payload: {'amount': 25.0},
      );
      print('ACTION:   Created entry for 2025-11-18 10:00');

      await Future.delayed(const Duration(milliseconds: 50));
      final afterTargetCount = emittedValues.last.length;

      // ACTION: Create entry for different day (should not affect stream)
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 19, 10, 0),
        payload: {'amount': 30.0},
      );
      print('ACTION:   Created entry for 2025-11-19 10:00 (different day)');

      await Future.delayed(const Duration(milliseconds: 50));
      final finalCount = emittedValues.last.length;

      print('EXPECTED: Stream should emit +1 for target day only');
      print('ACTUAL:   Initial: $initialCount, After target: $afterTargetCount, After other: $finalCount\n');

      expect(afterTargetCount, initialCount + 1);
      expect(finalCount, afterTargetCount); // Should not change for different day
      print('RESULT:   ✅ PASS - Stream only emits for target day entries');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchByDayRange: stream emits for entries within date range', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchByDayRange - Reactive Date Range Entries');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final startDate = DateTime(2025, 11, 18);
      final endDate = DateTime(2025, 11, 20);
      final stream = entries.watchByDayRange(startDate, endDate);
      final emittedValues = <Map<DateTime, List<EntryRecord>>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialDays = emittedValues.last.keys.length;
      print('INIT:     Initial days with entries in range: $initialDays');

      // ACTION: Create entries in range
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 18, 10, 0),
        payload: {'amount': 25.0},
      );
      await entries.create(
        widgetKind: 'vitamin_c',
        targetAtLocal: DateTime(2025, 11, 19, 14, 0),
        payload: {'amount': 100.0},
      );
      print('ACTION:   Created 2 entries in range (Nov 18-19)');

      await Future.delayed(const Duration(milliseconds: 50));
      final afterInRangeDays = emittedValues.last.keys.length;
      final totalInRange = emittedValues.last.values.fold<int>(0, (sum, list) => sum + list.length);

      // ACTION: Create entry outside range
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 21, 10, 0),
        payload: {'amount': 30.0},
      );
      print('ACTION:   Created entry outside range (Nov 21)');

      await Future.delayed(const Duration(milliseconds: 50));
      final finalDays = emittedValues.last.keys.length;
      final finalTotal = emittedValues.last.values.fold<int>(0, (sum, list) => sum + list.length);

      print('EXPECTED: Stream should include range entries only');
      print('ACTUAL:   Days after in-range: $afterInRangeDays, entries: $totalInRange');
      print('          Days after out-range: $finalDays, entries: $finalTotal\n');

      expect(totalInRange, greaterThanOrEqualTo(2));
      expect(finalTotal, totalInRange); // Outside entry should not be included
      print('RESULT:   ✅ PASS - Stream only emits for entries within date range');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchSearch: stream emits with matching entries for query', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchSearch - Reactive Text Search');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create test entries
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 18, 10, 0),
        payload: {'amount': 25.0, 'note': 'chicken breast'},
      );
      await entries.create(
        widgetKind: 'vitamin_c',
        targetAtLocal: DateTime(2025, 11, 18, 14, 0),
        payload: {'amount': 100.0, 'note': 'orange'},
      );
      print('INIT:     Created 2 entries: "chicken breast" and "orange"');

      final stream = entries.watchSearch('chicken');
      final emittedValues = <List<EntryRecord>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialMatches = emittedValues.last.length;
      print('ACTION:   Searching for "chicken"');
      print('EXPECTED: Should find 1 match (chicken breast)');
      print('ACTUAL:   Found $initialMatches matches\n');

      expect(initialMatches, 1);
      expect(emittedValues.last.first.payloadJson, contains('chicken'));

      // ACTION: Create another matching entry
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime(2025, 11, 18, 18, 0),
        payload: {'amount': 30.0, 'note': 'chicken thigh'},
      );
      print('ACTION:   Created new entry: "chicken thigh"');

      await Future.delayed(const Duration(milliseconds: 50));
      final finalMatches = emittedValues.last.length;

      print('EXPECTED: Should now find 2 matches');
      print('ACTUAL:   Found $finalMatches matches\n');

      expect(finalMatches, 2);
      expect(emittedValues.length, greaterThan(1));
      print('RESULT:   ✅ PASS - Stream reactively updates search results');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchById: stream emits after specific entry updated', () async {
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
      final emittedValues = <EntryRecord?>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialPayload = emittedValues.last?.payloadJson;
      print('          Initial payload: $initialPayload');

      // ACTION: Update entry
      await entries.update(entry.id, {
        'payload_json': '{"amount": 35.0}',
      });
      print('ACTION:   Updated amount from 25.0 to 35.0');

      await Future.delayed(const Duration(milliseconds: 50));
      final updatedPayload = emittedValues.last?.payloadJson;

      print('EXPECTED: Stream should emit updated entry');
      print('ACTUAL:   Updated payload: $updatedPayload\n');

      expect(updatedPayload, contains('35.0'));
      expect(emittedValues.length, greaterThan(1));
      print('RESULT:   ✅ PASS - Stream reactively emitted after entry update');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
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
      final emittedValues = <EntryRecord?>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initial = emittedValues.last;
      print('          Initial: entry exists = ${initial != null}');

      // ACTION: Delete entry
      await entries.delete(entry.id);
      print('ACTION:   Deleted entry');

      await Future.delayed(const Duration(milliseconds: 50));
      final afterDelete = emittedValues.last;

      print('EXPECTED: Stream should emit null after deletion');
      print('ACTUAL:   After delete: entry exists = ${afterDelete != null}\n');

      expect(afterDelete, isNull);
      expect(emittedValues.length, greaterThan(1));
      print('RESULT:   ✅ PASS - Stream reactively emitted null after deletion');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });
  });
}

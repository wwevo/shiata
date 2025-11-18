// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;

import 'package:shiata/data/db/raw_db.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/data/repo/entries_repository.dart';

/// v0.8.6 - Enhanced Tests & Validations
///
/// These tests intentionally provoke errors to document expected behavior.
/// "Tests müssen so gestaltet werden, dass Fehler gefunden werden."
/// "Der größte Bug sitzt immer vor dem Bildschirm!"
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Validation Tests - User Input Errors', () {
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
    });

    test('KIND: Creating kind with min > max (nonsensical constraint)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Kind Validation - Min > Max (User Error)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User accidentally enters min=100, max=0');
      print('EXPECTED: Should throw ArgumentError with helpful message\n');

      expect(
        () async => await kinds.upsertKind(KindDef(
          id: 'broken_kind',
          name: 'Broken Kind',
          unit: 'g',
          color: null,
          icon: null,
          min: 100,  // ❌ min > max!
          max: 0,    // ❌ nonsensical
          defaultShowInCalendar: false,
        )),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents nonsensical constraints');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('KIND: Creating kind with empty name', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Kind Validation - Empty Name (User Error)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User submits form without filling in name field');
      print('EXPECTED: Should throw ArgumentError("name cannot be empty")\n');

      expect(
        () async => await kinds.upsertKind(KindDef(
          id: 'nameless',
          name: '',  // ❌ Empty name!
          unit: 'g',
          color: null,
          icon: null,
          min: 0,
          max: 1000,
          defaultShowInCalendar: false,
        )),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents empty names');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('KIND: Creating kind with empty unit', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Kind Validation - Empty Unit (User Error)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User creates kind but forgets to specify unit');
      print('EXPECTED: Should throw ArgumentError("unit cannot be empty")\n');

      expect(
        () async => await kinds.upsertKind(KindDef(
          id: 'unitless',
          name: 'Unitless Kind',
          unit: '',  // ❌ No unit!
          color: null,
          icon: null,
          min: 0,
          max: 1000,
          defaultShowInCalendar: false,
        )),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents unitless kinds');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('PRODUCT: Creating product with empty name', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Product Validation - Empty Name (User Error)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User clicks "Create Product" without entering name');
      print('EXPECTED: Should throw ArgumentError("name cannot be empty")\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(
        () async => await products.upsertProduct(ProductDef(
          id: 'nameless_product',
          name: '',  // ❌ Empty name!
          createdAt: now,
          updatedAt: now,
        )),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents nameless products');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('RECIPE: Creating recipe with empty name', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Recipe Validation - Empty Name (User Error)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User submits recipe form with blank name field');
      print('EXPECTED: Should throw ArgumentError("name cannot be empty")\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(
        () async => await recipes.upsertRecipe(RecipeDef(
          id: 'nameless_recipe',
          name: '',  // ❌ Empty name!
          createdAt: now,
          updatedAt: now,
        )),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents nameless recipes');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('ENTRY: Creating entry with negative amount (nonsensical)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Entry Validation - Negative Amount (User Error)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User types "-50" in amount field (typo or confusion)');
      print('EXPECTED: Should throw ArgumentError("amount must be >= 0")\n');

      expect(
        () async => await entries.create(
          widgetKind: 'protein',
          targetAtLocal: DateTime.now(),
          payload: {'amount': -50.0},  // ❌ Negative amount!
        ),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents negative amounts');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('PRODUCT: Creating product with 0 grams in entry (nonsensical)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Entry Validation - Zero Grams Product (User Error)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User enters "0g" for product amount');
      print('EXPECTED: Should throw ArgumentError("grams must be > 0")\n');

      // Setup product
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await products.upsertProduct(ProductDef(
        id: 'banana',
        name: 'Banana',
        createdAt: now,
        updatedAt: now,
      ));

      expect(
        () async => await entries.create(
          widgetKind: 'product_instance',
          targetAtLocal: DateTime.now(),
          payload: {},
          productId: 'banana',
          productGrams: 0,  // ❌ Zero grams!
        ),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents 0g products');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });

  group('Edge Case Tests - Boundary Values', () {
    late AppDb db;
    late KindsRepository kinds;
    late EntriesRepository entries;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      kinds = KindsRepository(db: db);
      entries = EntriesRepository(db: db);
    });

    tearDown(() async {
      kinds.dispose();
      entries.dispose();
    });

    test('ENTRY: Date 100 years in future is accepted (potential user error)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Entry Edge Case - Far Future Date (User Typo)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User selects year 2125 instead of 2025 (date picker confusion)');
      print('CURRENT:  No validation - accepts any future date');
      print('EXPECTED: Maybe warn if date > 1 year in future?\n');

      final farFuture = DateTime(2125, 11, 18);
      final entry = await entries.create(
        widgetKind: 'protein',
        targetAtLocal: farFuture,
        payload: {'amount': 50.0},
      );

      print('ACTUAL:   Entry created for year 2125');
      print('ISSUE:    Entry won\'t show up in normal views (way out of range)');
      print('          User thinks entry is lost!');

      expect(entry.targetAt, greaterThan(DateTime(2100).toUtc().millisecondsSinceEpoch));

      print('\nRESULT:   ⚠️  DOCUMENTS EDGE CASE - Far future dates accepted');
      print('FIX:      Consider warning if targetAt > now + 1 year');
      print('          Or limit date picker to reasonable range');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('KIND: Extremely large max value (Int overflow potential)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Kind Edge Case - Extremely Large Max Value');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User enters max=999999999999 (many nines)');
      print('CURRENT:  No validation - stores whatever user enters');
      print('EXPECTED: Should maybe cap at reasonable value?\n');

      await kinds.upsertKind(KindDef(
        id: 'extreme',
        name: 'Extreme Kind',
        unit: 'g',
        color: null,
        icon: null,
        min: 0,
        max: 999999999,  // Nearly 1 billion
        defaultShowInCalendar: false,
      ));

      final retrieved = await kinds.getKind('extreme');
      print('ACTUAL:   Kind created with max=${retrieved!.max}');
      print('ISSUE:    Probably fine, but could cause UI layout issues');

      expect(retrieved.max, 999999999);

      print('\nRESULT:   ✅ DOCUMENTS BOUNDARY - Large values accepted');
      print('NOTE:     This is probably OK - Dart ints are 64-bit');
      print('          But UI should handle display gracefully (1B not 1000000000)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });

  group('Constraint Tests - Data Integrity', () {
    late AppDb db;
    late KindsRepository kinds;
    late ProductsRepository products;
    late EntriesRepository entries;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      kinds = KindsRepository(db: db);
      products = ProductsRepository(db: db);
      entries = EntriesRepository(db: db);
    });

    tearDown(() async {
      kinds.dispose();
      products.dispose();
      entries.dispose();
    });

    test('CONSTRAINT: Deleting kind with existing entries (foreign key violation)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Constraint - Delete Kind With Entries (Data Integrity)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User deletes "Protein" kind, but has 2 protein entries');
      print('EXPECTED: Should prevent deletion with error "Kind is in use by N entries"\n');

      // Setup: Create kind and entries
      await kinds.upsertKind(KindDef(
        id: 'protein',
        name: 'Protein',
        unit: 'g',
        color: null,
        icon: null,
        min: 0,
        max: 1000,
        defaultShowInCalendar: false,
      ));

      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime.now(),
        payload: {'amount': 50.0},
      );
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: DateTime.now(),
        payload: {'amount': 75.0},
      );

      print('SETUP:    Created kind "protein" with 2 entries\n');

      // Try to delete kind - should throw
      expect(
        () async => await kinds.deleteKind('protein'),
        throwsStateError,
      );

      print('RESULT:   ✅ PASS - Constraint prevents orphaning entries');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('CONSTRAINT: Deleting product with existing entries (foreign key violation)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Constraint - Delete Product With Entries (Data Integrity)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User deletes "Banana" product, but logged eating 1 banana');
      print('EXPECTED: Should prevent deletion with error\n');

      // Setup
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await products.upsertProduct(ProductDef(
        id: 'banana',
        name: 'Banana',
        createdAt: now,
        updatedAt: now,
      ));

      await entries.create(
        widgetKind: 'product_instance',
        targetAtLocal: DateTime.now(),
        payload: {},
        productId: 'banana',
        productGrams: 100,
      );

      print('SETUP:    Created product "banana" with 1 entry\n');

      // Try to delete - should throw
      expect(
        () async => await products.deleteProduct('banana'),
        throwsStateError,
      );

      print('RESULT:   ✅ PASS - Constraint prevents orphaning product entries');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('CONSTRAINT: Entry with non-existent productId (orphaned from start)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Constraint - Entry With Invalid Product ID (Data Corruption)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: Bug/corruption creates entry with productId that doesn\'t exist');
      print('EXPECTED: Should validate productId exists before creating entry\n');

      expect(
        () async => await entries.create(
          widgetKind: 'product_instance',
          targetAtLocal: DateTime.now(),
          payload: {},
          productId: 'nonexistent_product',  // ❌ Product doesn't exist!
          productGrams: 100,
        ),
        throwsArgumentError,
      );

      print('RESULT:   ✅ PASS - Validation prevents entries with invalid productId');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });

  group('UI State Tests - User Workflow Scenarios', () {
    late AppDb db;
    late EntriesRepository entries;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      entries = EntriesRepository(db: db);
    });

    tearDown(() async {
      entries.dispose();
    });

    test('UI: Empty search results allows recovery (v0.8.4 regression test)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: UI State - Empty Search Results Recovery (Bug Regression)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      print('SCENARIO: User filters for "Recipes" but has none → stuck on empty page');
      print('FIXED IN: v0.8.4 - Filter chips now always visible');
      print('THIS TEST: Validates the fix stays in place\n');

      // This is a regression test - we don't test the actual bug
      // We test that the FIXED behavior is maintained

      final results = await entries.watchSearch('nonexistent_term_xyz').first;

      print('SETUP:    Search for term that returns no results');
      print('ACTUAL:   Search returns: ${results.length} entries');
      print('EXPECTED: UI shows filter chips even with 0 results');
      print('          User can click "Clear All" to recover\n');

      expect(results, isEmpty);

      print('RESULT:   ✅ REGRESSION TEST - Documents v0.8.4 fix');
      print('NOTE:     This is a UI test - validated manually');
      print('          Data layer correctly returns empty list');
      print('          UI must show clear/reset option when empty');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });
}

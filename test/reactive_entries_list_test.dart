// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;

import 'package:shiata/data/db/raw_db.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/entries_repository.dart';
import 'package:shiata/data/repo/product_service.dart';

void main() {
  // Suppress drift warnings about multiple database instances in tests
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Reactive Entries List Tests', () {
    late AppDb db;
    late KindsRepository kinds;
    late ProductsRepository products;
    late EntriesRepository entries;
    late ProductService productService;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      kinds = KindsRepository(db: db);
      products = ProductsRepository(db: db);
      entries = EntriesRepository(db: db);
      productService = ProductService(entries: entries, products: products);

      // Setup test kinds
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

      // Setup test product
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await products.upsertProduct(ProductDef(
        id: 'apple',
        name: 'Apple',
        createdAt: now,
        updatedAt: now,
      ));
      await products.setComponents('apple', [
        ProductComponent(productId: 'apple', kindId: 'protein', amountPerGram: 0.3),
        ProductComponent(productId: 'apple', kindId: 'vitamin_c', amountPerGram: 4.6),
      ]);
    });

    test('watchAllEntriesWithChildren: initial state returns all entries including children', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchAllEntriesWithChildren - Initial State with Hierarchy');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create product instance with children
      final targetAt = DateTime(2025, 11, 18, 10, 0).toLocal();
      await productService.createProductEntry(
        productId: 'apple',
        productGrams: 100,
        targetAtLocal: targetAt,
        isStatic: false,
      );
      print('INIT:     Created product instance (100g apple) with 2 nutrient children');

      // ACTION: Watch all entries
      final stream = entries.watchAllEntriesWithChildren();
      final allEntries = await stream.first;
      print('ACTION:   Called watchAllEntriesWithChildren()');

      // Build hierarchy
      final childrenByParent = <String, List<EntryRecord>>{};
      for (final entry in allEntries) {
        if (entry.sourceEntryId != null && entry.sourceEntryId!.isNotEmpty) {
          childrenByParent.putIfAbsent(entry.sourceEntryId!, () => []).add(entry);
        }
      }

      final topLevel = allEntries.where((e) => e.sourceEntryId == null).toList();
      final parentEntry = topLevel.firstWhere((e) => e.widgetKind == 'product');
      final children = childrenByParent[parentEntry.id] ?? [];

      print('EXPECTED: 1 parent (product) + 2 children (protein, vitamin_c)');
      print('ACTUAL:   ${topLevel.length} parent(s), ${children.length} children for product\n');

      // Assertions
      expect(topLevel.length, 1, reason: 'Should have 1 top-level entry (product)');
      expect(children.length, 2, reason: 'Product should have 2 children (nutrients)');
      expect(children.any((e) => e.widgetKind == 'protein'), true);
      expect(children.any((e) => e.widgetKind == 'vitamin_c'), true);

      print('RESULT:   ✅ PASS - Hierarchy correctly built from stream data');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchAllEntriesWithChildren: stream emits after CREATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchAllEntriesWithChildren - Reactive CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final stream = entries.watchAllEntriesWithChildren();
      final emittedValues = <List<EntryRecord>>[];

      // Collect stream values
      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      // Wait for initial emission
      await Future.delayed(const Duration(milliseconds: 50));
      final initialCount = emittedValues.last.length;
      print('INIT:     Stream initially emitted $initialCount entries');

      // ACTION: Create new entry
      final targetAt = DateTime(2025, 11, 18, 12, 0).toLocal();
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: targetAt,
        payload: {'amount': 25.0},
      );
      print('ACTION:   Created new direct protein entry (25g)');

      // Wait for stream to emit
      await Future.delayed(const Duration(milliseconds: 50));
      final finalCount = emittedValues.last.length;

      print('EXPECTED: Stream emits new value with +1 entry');
      print('ACTUAL:   Initial: $initialCount, Final: $finalCount\n');

      expect(finalCount, initialCount + 1, reason: 'Stream should emit new entry');
      expect(emittedValues.length, greaterThan(1), reason: 'Stream should have emitted multiple times');

      print('RESULT:   ✅ PASS - Stream reactively emitted after CREATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchAllEntriesWithChildren: stream emits after DELETE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchAllEntriesWithChildren - Reactive DELETE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create entry
      final targetAt = DateTime(2025, 11, 18, 14, 0).toLocal();
      final record = await entries.create(
        widgetKind: 'protein',
        targetAtLocal: targetAt,
        payload: {'amount': 30.0},
      );
      print('INIT:     Created protein entry (30g), ID: ${record.id}');

      final stream = entries.watchAllEntriesWithChildren();
      final emittedValues = <List<EntryRecord>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final beforeDelete = emittedValues.last.length;
      print('           Stream shows $beforeDelete entries');

      // ACTION: Delete entry
      await entries.delete(record.id);
      print('ACTION:   Deleted entry ${record.id}');

      await Future.delayed(const Duration(milliseconds: 50));
      final afterDelete = emittedValues.last.length;

      print('EXPECTED: Stream emits new value with -1 entry');
      print('ACTUAL:   Before: $beforeDelete, After: $afterDelete\n');

      expect(afterDelete, beforeDelete - 1, reason: 'Stream should reflect deletion');
      expect(emittedValues.last.any((e) => e.id == record.id), false,
        reason: 'Deleted entry should not be in stream');

      print('RESULT:   ✅ PASS - Stream reactively emitted after DELETE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchAllEntriesWithChildren: stream emits after UPDATE', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchAllEntriesWithChildren - Reactive UPDATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create entry
      final targetAt = DateTime(2025, 11, 18, 16, 0).toLocal();
      final record = await entries.create(
        widgetKind: 'protein',
        targetAtLocal: targetAt,
        payload: {'amount': 40.0},
      );
      print('INIT:     Created protein entry (40g), ID: ${record.id}');

      final stream = entries.watchAllEntriesWithChildren();
      final emittedValues = <List<EntryRecord>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));
      final initialEmissions = emittedValues.length;
      print('           Stream emitted $initialEmissions time(s)');

      // ACTION: Update entry
      await entries.update(record.id, {
        'payload_json': '{"amount": 50.0}',
      });
      print('ACTION:   Updated entry ${record.id} (amount: 40 → 50)');

      await Future.delayed(const Duration(milliseconds: 50));
      final finalEmissions = emittedValues.length;

      // Find updated entry in latest emission
      final updated = emittedValues.last.firstWhere((e) => e.id == record.id);
      final updatedPayload = updated.payloadJson;

      print('EXPECTED: Stream emits new value, payload updated');
      print('ACTUAL:   Emissions: $initialEmissions → $finalEmissions, Payload: $updatedPayload\n');

      expect(finalEmissions, greaterThan(initialEmissions), reason: 'Stream should emit on UPDATE');
      expect(updatedPayload, contains('50.0'), reason: 'Updated value should be in stream');

      print('RESULT:   ✅ PASS - Stream reactively emitted after UPDATE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });

    test('watchAllEntriesWithChildren: complex hierarchy with product + children', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchAllEntriesWithChildren - Complex Hierarchy Validation');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create multiple entries with hierarchy
      final targetAt = DateTime(2025, 11, 18, 18, 0).toLocal();

      // Direct protein entry (no parent)
      await entries.create(
        widgetKind: 'protein',
        targetAtLocal: targetAt,
        payload: {'amount': 10.0},
      );

      // Product entry with children
      await productService.createProductEntry(
        productId: 'apple',
        productGrams: 150,
        targetAtLocal: targetAt.add(const Duration(hours: 1)),
        isStatic: false,
      );

      print('INIT:     Created 1 direct protein + 1 product (150g apple with 2 children)');

      // ACTION: Watch stream
      final stream = entries.watchAllEntriesWithChildren();
      final allEntries = await stream.first;

      // Build hierarchy
      final childrenByParent = <String, List<EntryRecord>>{};
      for (final entry in allEntries) {
        if (entry.sourceEntryId != null && entry.sourceEntryId!.isNotEmpty) {
          childrenByParent.putIfAbsent(entry.sourceEntryId!, () => []).add(entry);
        }
      }

      final topLevel = allEntries.where((e) => e.sourceEntryId == null).toList();
      final productParent = topLevel.firstWhere((e) => e.widgetKind == 'product');
      final productChildren = childrenByParent[productParent.id] ?? [];

      print('ACTION:   Built childrenByParent map from stream data');
      print('EXPECTED: 2 top-level entries (1 protein, 1 product), product has 2 children');
      print('ACTUAL:   ${topLevel.length} top-level, product has ${productChildren.length} children\n');

      expect(topLevel.length, 2, reason: '1 direct protein + 1 product parent');
      expect(topLevel.where((e) => e.widgetKind == 'protein').length, 1);
      expect(topLevel.where((e) => e.widgetKind == 'product').length, 1);
      expect(productChildren.length, 2, reason: 'Product should have 2 nutrient children');

      // Validate children types
      final childKinds = productChildren.map((e) => e.widgetKind).toSet();
      expect(childKinds.contains('protein'), true);
      expect(childKinds.contains('vitamin_c'), true);

      print('RESULT:   ✅ PASS - Complex hierarchy correctly represented in stream');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('watchAllEntriesWithChildren: stream emits when child is deleted', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: watchAllEntriesWithChildren - Reactive Child DELETE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // INIT: Create product with children
      final targetAt = DateTime(2025, 11, 18, 20, 0).toLocal();
      await productService.createProductEntry(
        productId: 'apple',
        productGrams: 200,
        targetAtLocal: targetAt,
        isStatic: false,
      );

      final stream = entries.watchAllEntriesWithChildren();
      final emittedValues = <List<EntryRecord>>[];

      final subscription = stream.listen((data) {
        emittedValues.add(data);
      });

      await Future.delayed(const Duration(milliseconds: 50));

      // Find a child entry
      final allEntries = emittedValues.last;
      final child = allEntries.firstWhere((e) => e.sourceEntryId != null);
      final beforeDelete = allEntries.length;

      print('INIT:     Product with children created, total entries: $beforeDelete');
      print('           Found child entry: ${child.widgetKind} (ID: ${child.id})');

      // ACTION: Delete child
      await entries.delete(child.id);
      print('ACTION:   Deleted child entry ${child.id}');

      await Future.delayed(const Duration(milliseconds: 50));
      final afterDelete = emittedValues.last.length;

      print('EXPECTED: Stream emits with -1 entry (child removed)');
      print('ACTUAL:   Before: $beforeDelete, After: $afterDelete\n');

      expect(afterDelete, beforeDelete - 1, reason: 'Child deletion should be reflected');
      expect(emittedValues.last.any((e) => e.id == child.id), false,
        reason: 'Deleted child should not be in stream');

      print('RESULT:   ✅ PASS - Stream reactively emitted after child DELETE');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await subscription.cancel();
    });
  });
}

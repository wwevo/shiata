// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;

import 'package:shiata/data/db/raw_db.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/entries_repository.dart';
import 'package:shiata/data/repo/product_service.dart';
import 'dart:convert';

void main() {
  // Suppress drift warnings about multiple database instances in tests
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Template Propagation Tests', () {
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
    });

    test('Product template change: dynamic instance UPDATES, static instance UNCHANGED', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Product Template Propagation (Dynamic vs Static)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup product template with initial components
      await products.upsertProduct(ProductDef(
        id: 'banana',
        name: 'Banana',
        createdAt: now,
        updatedAt: now,
      ));
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'vitamin_c', amountPerGram: 5.0),
      ]);

      // Create one dynamic and one static instance
      final target = DateTime.now();
      final dynamicId = await productService.createProductEntry(
        productId: 'banana',
        productGrams: 100,
        targetAtLocal: target,
        isStatic: false,
      );
      final staticId = await productService.createProductEntry(
        productId: 'banana',
        productGrams: 100,
        targetAtLocal: target,
        isStatic: true,
      );

      // Verify initial state
      var dynamicChildren = await entries.listChildrenOfParent(dynamicId!);
      var staticChildren = await entries.listChildrenOfParent(staticId!);
      var dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      var staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;

      print('INIT:     Template: banana (5mg vitamin C per 100g)');
      print('          Dynamic instance: ${dynamicPayload['amount']}mg, Static instance: ${staticPayload['amount']}mg\n');

      // Change template components
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'vitamin_c', amountPerGram: 10.0),
      ]);

      // Propagate changes using ProductService
      await productService.updateAllEntriesForProductToCurrentFormula('banana');

      print('ACTION:   Template changed: 5mg → 10mg per 100g');
      print('          Propagation executed via ProductService.updateAllEntriesForProductToCurrentFormula()\n');

      // Verify final state
      dynamicChildren = await entries.listChildrenOfParent(dynamicId);
      staticChildren = await entries.listChildrenOfParent(staticId);
      dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;

      print('EXPECTED: Dynamic=10mg (updated), Static=5mg (unchanged)');
      print('ACTUAL:   Dynamic=${dynamicPayload['amount']}mg, Static=${staticPayload['amount']}mg\n');

      expect(dynamicPayload['amount'], 10.0, reason: 'Dynamic instance should update to 10mg');
      expect(staticPayload['amount'], 5.0, reason: 'Static instance should remain 5mg');

      final passed = dynamicPayload['amount'] == 10.0 && staticPayload['amount'] == 5.0;
      print('RESULT:   ${passed ? "✅ PASS" : "❌ FAIL"} - Propagation works correctly');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('Product template change: small values NOT NULLED (bug regression test)', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Integer Division Bug Regression (Small Values)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup with SMALL value (0.5mg per 100g)
      await products.upsertProduct(ProductDef(
        id: 'supplement',
        name: 'Supplement',
        createdAt: now,
        updatedAt: now,
      ));
      await products.setComponents('supplement', [
        ProductComponent(productId: 'supplement', kindId: 'vitamin_c', amountPerGram: 0.5),
      ]);

      final target = DateTime.now();
      final instanceId = await productService.createProductEntry(
        productId: 'supplement',
        productGrams: 100,
        targetAtLocal: target,
        isStatic: false,
      );

      var children = await entries.listChildrenOfParent(instanceId!);
      var payload = jsonDecode(children.first.payloadJson) as Map<String, dynamic>;

      print('INIT:     Template: supplement (0.5mg vitamin C per 100g)');
      print('          Instance (100g): ${payload['amount']}mg\n');

      // Change template to another small value
      await products.setComponents('supplement', [
        ProductComponent(productId: 'supplement', kindId: 'vitamin_c', amountPerGram: 0.8),
      ]);

      // Propagate changes
      await productService.updateAllEntriesForProductToCurrentFormula('supplement');

      print('ACTION:   Template changed: 0.5mg → 0.8mg per 100g');
      print('          Propagation executed\n');

      children = await entries.listChildrenOfParent(instanceId);
      payload = jsonDecode(children.first.payloadJson) as Map<String, dynamic>;

      print('EXPECTED: 0.8mg (NOT 0, bug was: (0.8 * 100) ~/ 100 = 80 ~/ 100 = 0)');
      print('ACTUAL:   ${payload['amount']}mg\n');

      expect(payload['amount'], 0.8, reason: 'Should be 0.8, NOT 0 (bug was integer division)');
      expect(payload['amount'], isNot(0), reason: 'CRITICAL: Value must not be nulled!');

      final passed = payload['amount'] == 0.8;
      print('RESULT:   ${passed ? "✅ PASS" : "❌ FAIL"} - Small values preserved (/ not ~/)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('Product name propagation: template name updates dynamic instances', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Product Name Propagation');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup product with initial name
      await products.upsertProduct(ProductDef(
        id: 'apple',
        name: 'Apple',
        createdAt: now,
        updatedAt: now,
      ));
      await products.setComponents('apple', [
        ProductComponent(productId: 'apple', kindId: 'vitamin_c', amountPerGram: 3.0),
      ]);

      final target = DateTime.now();
      final dynamicId = await productService.createProductEntry(
        productId: 'apple',
        productGrams: 100,
        targetAtLocal: target,
        isStatic: false,
      );

      // Verify initial name
      var dynamicEntry = await entries.getById(dynamicId!);
      var dynamicPayload = jsonDecode(dynamicEntry!.payloadJson) as Map<String, dynamic>;

      print('INIT:     Template name: "Apple"');
      print('          Dynamic instance name: "${dynamicPayload['name']}"\n');

      // Change product name
      await products.upsertProduct(ProductDef(
        id: 'apple',
        name: 'Green Apple',
        createdAt: now,
        updatedAt: now,
      ));

      // Propagate changes
      await productService.updateAllEntriesForProductToCurrentFormula('apple');

      print('ACTION:   Template renamed: "Apple" → "Green Apple"');
      print('          Propagation executed\n');

      // Verify name update
      dynamicEntry = await entries.getById(dynamicId);
      dynamicPayload = jsonDecode(dynamicEntry!.payloadJson) as Map<String, dynamic>;

      print('EXPECTED: Dynamic instance name: "Green Apple"');
      print('ACTUAL:   Dynamic instance name: "${dynamicPayload['name']}"\n');

      expect(dynamicPayload['name'], 'Green Apple', reason: 'Dynamic instance should update to new name');

      final passed = dynamicPayload['name'] == 'Green Apple';
      print('RESULT:   ${passed ? "✅ PASS" : "❌ FAIL"} - Name propagation works');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });
}

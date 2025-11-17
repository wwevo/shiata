import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull;

import 'package:shiata/data/db/raw_db.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/entries_repository.dart';
import 'package:shiata/data/repo/product_service.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/data/repo/recipe_service.dart';
import 'package:shiata/data/repo/product_hierarchy_service.dart';
import 'package:shiata/data/repo/recipe_hierarchy_service.dart';
import 'package:shiata/domain/widgets/registry.dart';
import 'package:shiata/domain/widgets/widget_kind.dart';
import 'package:shiata/domain/widgets/kinds/db_backed_kind.dart';
import 'package:flutter/material.dart';
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
    late RecipesRepository recipes;
    late ProductService productService;
    late RecipeService recipeService;
    late ProductHierarchyService productHierarchyService;
    late RecipeHierarchyService recipeHierarchyService;
    late WidgetRegistry registry;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      kinds = KindsRepository(db: db);
      products = ProductsRepository(db: db);
      entries = EntriesRepository(db: db);
      recipes = RecipesRepository(db: db);
      productService = ProductService(entries: entries, products: products);
      recipeService = RecipeService(entries: entries, recipes: recipes, productService: productService);

      // Load kinds for registry
      await kinds.upsertKind(KindDef(id: 'vitamin_c', name: 'Vitamin C', unit: 'mg', color: null, icon: null, min: 0, max: 100000, defaultShowInCalendar: false));
      await kinds.upsertKind(KindDef(id: 'protein', name: 'Protein', unit: 'g', color: null, icon: null, min: 0, max: 100000, defaultShowInCalendar: false));

      // Build registry manually (like widgetRegistryProvider does)
      final kindsList = await kinds.listKinds();
      final map = <String, WidgetKind>{};
      for (final k in kindsList) {
        map[k.id] = DbBackedKind(k, iconResolver: (name, fallback) => fallback);
      }
      registry = WidgetRegistry(map);

      productHierarchyService = ProductHierarchyService(
        entries: entries,
        products: products,
        productService: productService,
        registry: registry,
      );
      recipeHierarchyService = RecipeHierarchyService(
        entries: entries,
        recipes: recipes,
        recipeService: recipeService,
        productHierarchyService: productHierarchyService,
        registry: registry,
      );
    });

    test('Product template change: dynamic instance UPDATES, static instance UNCHANGED', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Product Template Propagation (Dynamic vs Static)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup
      await products.upsertProduct(ProductDef(id: 'banana', name: 'Banana', createdAt: now, updatedAt: now));
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'vitamin_c', amountPerGram: 5.0),
      ]);

      final target = DateTime.now();
      final dynamicId = await productService.createProductEntry(
        productId: 'banana', productGrams: 100, targetAtLocal: target, isStatic: false,
      );
      final staticId = await productService.createProductEntry(
        productId: 'banana', productGrams: 100, targetAtLocal: target, isStatic: true,
      );

      // Verify initial state
      var dynamicChildren = await entries.listChildrenOfParent(dynamicId!);
      var staticChildren = await entries.listChildrenOfParent(staticId!);
      var dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      var staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;

      print('INIT:     Template: banana (5mg vitamin C per 100g)');
      print('          Dynamic instance: ${dynamicPayload['amount']}mg, Static instance: ${staticPayload['amount']}mg\n');

      // Change template and propagate
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'vitamin_c', amountPerGram: 10.0),
      ]);
      await productHierarchyService.propagateTemplateChange('banana');

      print('ACTION:   Template changed: 5mg → 10mg per 100g');
      print('          Propagation executed\n');

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

      // Setup with SMALL value
      await products.upsertProduct(ProductDef(id: 'supplement', name: 'Supplement', createdAt: now, updatedAt: now));
      await products.setComponents('supplement', [
        ProductComponent(productId: 'supplement', kindId: 'vitamin_c', amountPerGram: 0.5),
      ]);

      final target = DateTime.now();
      final instanceId = await productService.createProductEntry(
        productId: 'supplement', productGrams: 100, targetAtLocal: target, isStatic: false,
      );

      var children = await entries.listChildrenOfParent(instanceId!);
      var payload = jsonDecode(children.first.payloadJson) as Map<String, dynamic>;

      print('INIT:     Template: supplement (0.5mg vitamin C per 100g)');
      print('          Instance (100g): ${payload['amount']}mg\n');

      // Change template and propagate
      await products.setComponents('supplement', [
        ProductComponent(productId: 'supplement', kindId: 'vitamin_c', amountPerGram: 0.8),
      ]);
      await productHierarchyService.propagateTemplateChange('supplement');

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

    test('Recipe template change: dynamic instance UPDATES, static instance UNCHANGED', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Recipe Template Propagation (Dynamic vs Static)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      await recipes.upsertRecipe(RecipeDef(id: 'smoothie', name: 'Smoothie', createdAt: now, updatedAt: now));
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 50.0),
      ]);

      final target = DateTime.now();
      final dynamicId = await recipeService.createRecipeEntry(
        recipeId: 'smoothie', targetAtLocal: target, isStatic: false,
      );
      final staticId = await recipeService.createRecipeEntry(
        recipeId: 'smoothie', targetAtLocal: target, isStatic: true,
      );

      var dynamicChildren = await entries.listChildrenOfParent(dynamicId!);
      var staticChildren = await entries.listChildrenOfParent(staticId!);
      var dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      var staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;

      print('INIT:     Template: smoothie (50mg vitamin C)');
      print('          Dynamic instance: ${dynamicPayload['amount']}mg, Static instance: ${staticPayload['amount']}mg\n');

      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 100.0),
      ]);
      await recipeHierarchyService.propagateTemplateChange('smoothie');

      print('ACTION:   Template changed: 50mg → 100mg vitamin C');
      print('          Propagation executed\n');

      dynamicChildren = await entries.listChildrenOfParent(dynamicId);
      staticChildren = await entries.listChildrenOfParent(staticId);
      dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;

      print('EXPECTED: Dynamic=100mg (updated), Static=50mg (unchanged)');
      print('ACTUAL:   Dynamic=${dynamicPayload['amount']}mg, Static=${staticPayload['amount']}mg\n');

      expect(dynamicPayload['amount'], 100.0, reason: 'Dynamic recipe instance should update to 100mg');
      expect(staticPayload['amount'], 50.0, reason: 'Static recipe instance should remain 50mg');

      final passed = dynamicPayload['amount'] == 100.0 && staticPayload['amount'] == 50.0;
      print('RESULT:   ${passed ? "✅ PASS" : "❌ FAIL"} - Recipe propagation works correctly');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('Recipe with product: template change propagates recursively', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Recursive Propagation (Recipe → Product → Nutrient)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      await products.upsertProduct(ProductDef(id: 'banana', name: 'Banana', createdAt: now, updatedAt: now));
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'protein', amountPerGram: 10.0),
      ]);

      await recipes.upsertRecipe(RecipeDef(id: 'smoothie', name: 'Smoothie', createdAt: now, updatedAt: now));
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.product(recipeId: 'smoothie', compId: 'banana', grams: 200),
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 50.0),
      ]);

      final target = DateTime.now();
      final recipeId = await recipeService.createRecipeEntry(
        recipeId: 'smoothie', targetAtLocal: target, isStatic: false,
      );

      final recipeChildren = await entries.listChildrenOfParent(recipeId!);
      final productParent = recipeChildren.firstWhere((c) => c.widgetKind == 'product');
      var productChildren = await entries.listChildrenOfParent(productParent.id);
      var proteinPayload = jsonDecode(productChildren.first.payloadJson) as Map<String, dynamic>;

      print('INIT:     Recipe: smoothie (200g banana + 50mg vitamin C)');
      print('          Product: banana (10g protein per 100g)');
      print('          → Recipe contains: ${proteinPayload['amount']}g protein (200g * 10g/100g)\n');

      await recipes.setComponents('smoothie', [
        RecipeComponentDef.product(recipeId: 'smoothie', compId: 'banana', grams: 300),
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 50.0),
      ]);
      await recipeHierarchyService.propagateTemplateChange('smoothie');

      print('ACTION:   Recipe template changed: 200g banana → 300g banana');
      print('          Propagation executed (RECURSIVE through product)\n');

      final updatedRecipeChildren = await entries.listChildrenOfParent(recipeId);
      final updatedProductParent = updatedRecipeChildren.firstWhere((c) => c.widgetKind == 'product');
      productChildren = await entries.listChildrenOfParent(updatedProductParent.id);
      proteinPayload = jsonDecode(productChildren.first.payloadJson) as Map<String, dynamic>;

      print('EXPECTED: 30g protein (300g * 10g/100g)');
      print('ACTUAL:   ${proteinPayload['amount']}g protein\n');

      expect(proteinPayload['amount'], 30.0, reason: 'Protein should update to 30g (300g * 10g/100g)');

      final passed = proteinPayload['amount'] == 30.0;
      print('RESULT:   ${passed ? "✅ PASS" : "❌ FAIL"} - Recursive propagation works (recipe→product→nutrient)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('recipe_id column populated for new instances', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: DB Schema - recipe_id Column Population');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      await recipes.upsertRecipe(RecipeDef(id: 'test_recipe', name: 'Test', createdAt: now, updatedAt: now));
      await recipes.setComponents('test_recipe', [
        RecipeComponentDef.kind(recipeId: 'test_recipe', compId: 'vitamin_c', amount: 10.0),
      ]);

      final target = DateTime.now();
      final instanceId = await recipeService.createRecipeEntry(recipeId: 'test_recipe', targetAtLocal: target);
      final instance = await entries.getById(instanceId!);

      print('INIT:     Created recipe instance via RecipeService');
      print('ACTION:   Query entry by ID from database');
      print('EXPECTED: recipe_id column = "test_recipe"');
      print('ACTUAL:   recipe_id column = "${instance?.recipeId}"\n');

      expect(instance, isNotNull);
      expect(instance!.recipeId, 'test_recipe', reason: 'recipe_id column should be populated');

      final passed = instance.recipeId == 'test_recipe';
      print('RESULT:   ${passed ? "✅ PASS" : "❌ FAIL"} - recipe_id column correctly populated');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });

    test('listParentsByRecipeId returns all instances', () async {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('TEST: Query Method - listParentsByRecipeId()');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      await recipes.upsertRecipe(RecipeDef(id: 'test', name: 'Test', createdAt: now, updatedAt: now));
      await recipes.setComponents('test', [
        RecipeComponentDef.kind(recipeId: 'test', compId: 'vitamin_c', amount: 10.0),
      ]);

      final target = DateTime.now();
      await recipeService.createRecipeEntry(recipeId: 'test', targetAtLocal: target);
      await recipeService.createRecipeEntry(recipeId: 'test', targetAtLocal: target.add(Duration(hours: 1)));
      await recipeService.createRecipeEntry(recipeId: 'test', targetAtLocal: target.add(Duration(hours: 2)));

      print('INIT:     Created 3 instances of recipe "test" at different times');
      print('ACTION:   Query listParentsByRecipeId("test")');
      print('EXPECTED: 3 instances found, all with recipe_id="test"');

      final instances = await entries.listParentsByRecipeId('test');

      print('ACTUAL:   ${instances.length} instances found\n');

      expect(instances.length, 3, reason: 'Should find all 3 recipe instances');
      expect(instances.every((i) => i.recipeId == 'test'), isTrue);

      final passed = instances.length == 3 && instances.every((i) => i.recipeId == 'test');
      print('RESULT:   ${passed ? "✅ PASS" : "❌ FAIL"} - Query returns all recipe instances');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    });
  });
}

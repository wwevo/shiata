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
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup: Product template with 5mg vitamin C per 100g
      await products.upsertProduct(ProductDef(id: 'banana', name: 'Banana', createdAt: now, updatedAt: now));
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'vitamin_c', amountPerGram: 5.0), // 5mg per 100g
      ]);

      // Create 2 instances: 1 dynamic, 1 static (both 100g)
      final target = DateTime.now();
      final dynamicId = await productService.createProductEntry(
        productId: 'banana',
        productGrams: 100,
        targetAtLocal: target,
        isStatic: false, // DYNAMIC
      );
      final staticId = await productService.createProductEntry(
        productId: 'banana',
        productGrams: 100,
        targetAtLocal: target,
        isStatic: true, // STATIC
      );

      // Verify initial values (both should have 5mg)
      var dynamicChildren = await entries.listChildrenOfParent(dynamicId!);
      var staticChildren = await entries.listChildrenOfParent(staticId!);
      expect(dynamicChildren.length, 1);
      expect(staticChildren.length, 1);

      var dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      var staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;
      expect(dynamicPayload['amount'], 5.0); // 100g * 0.05 = 5mg
      expect(staticPayload['amount'], 5.0);

      // Change template to 10mg per 100g
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'vitamin_c', amountPerGram: 10.0), // 10mg per 100g
      ]);

      // Propagate changes
      await productHierarchyService.propagateTemplateChange('banana');

      // Verify: dynamic updated, static unchanged
      dynamicChildren = await entries.listChildrenOfParent(dynamicId);
      staticChildren = await entries.listChildrenOfParent(staticId);

      dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;

      expect(dynamicPayload['amount'], 10.0, reason: 'Dynamic instance should update to 10mg');
      expect(staticPayload['amount'], 5.0, reason: 'Static instance should remain 5mg');
    });

    test('Product template change: small values NOT NULLED (bug regression test)', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup: Product with SMALL amountPerGram (tests the ~/ bug)
      // amountPerGram: 0.5mg per 100g
      // At 100g: 0.5 * 100 / 100 = 0.5mg ✅
      // With integer division: (0.5 * 100) ~/ 100 = 50 ~/ 100 = 0 ❌
      await products.upsertProduct(ProductDef(id: 'supplement', name: 'Supplement', createdAt: now, updatedAt: now));
      await products.setComponents('supplement', [
        ProductComponent(productId: 'supplement', kindId: 'vitamin_c', amountPerGram: 0.5), // Small value!
      ]);

      // Create dynamic instance (100g)
      final target = DateTime.now();
      final instanceId = await productService.createProductEntry(
        productId: 'supplement',
        productGrams: 100,
        targetAtLocal: target,
        isStatic: false,
      );

      // Verify initial value
      var children = await entries.listChildrenOfParent(instanceId!);
      var payload = jsonDecode(children.first.payloadJson) as Map<String, dynamic>;
      expect(payload['amount'], 0.5, reason: '0.5 * 100 / 100 = 0.5mg');

      // Change template (still small value)
      // 0.8mg per 100g -> at 100g = 0.8mg
      await products.setComponents('supplement', [
        ProductComponent(productId: 'supplement', kindId: 'vitamin_c', amountPerGram: 0.8),
      ]);

      // Propagate
      await productHierarchyService.propagateTemplateChange('supplement');

      // Verify: NOT nulled, correctly calculated
      children = await entries.listChildrenOfParent(instanceId);
      payload = jsonDecode(children.first.payloadJson) as Map<String, dynamic>;

      expect(payload['amount'], 0.8, reason: 'Should be 0.8, NOT 0 (bug was integer division)');
      expect(payload['amount'], isNot(0), reason: 'CRITICAL: Value must not be nulled!');
    });

    test('Recipe template change: dynamic instance UPDATES, static instance UNCHANGED', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup: Recipe template with 50mg vitamin C
      await recipes.upsertRecipe(RecipeDef(id: 'smoothie', name: 'Smoothie', createdAt: now, updatedAt: now));
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 50.0),
      ]);

      // Create 2 instances: 1 dynamic, 1 static
      final target = DateTime.now();
      final dynamicId = await recipeService.createRecipeEntry(
        recipeId: 'smoothie',
        targetAtLocal: target,
        isStatic: false, // DYNAMIC
      );
      final staticId = await recipeService.createRecipeEntry(
        recipeId: 'smoothie',
        targetAtLocal: target,
        isStatic: true, // STATIC
      );

      // Verify initial values (both should have 50mg)
      var dynamicChildren = await entries.listChildrenOfParent(dynamicId!);
      var staticChildren = await entries.listChildrenOfParent(staticId!);

      var dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      var staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;
      expect(dynamicPayload['amount'], 50.0);
      expect(staticPayload['amount'], 50.0);

      // Change template to 100mg
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 100.0),
      ]);

      // Propagate changes
      await recipeHierarchyService.propagateTemplateChange('smoothie');

      // Verify: dynamic updated, static unchanged
      dynamicChildren = await entries.listChildrenOfParent(dynamicId);
      staticChildren = await entries.listChildrenOfParent(staticId);

      dynamicPayload = jsonDecode(dynamicChildren.first.payloadJson) as Map<String, dynamic>;
      staticPayload = jsonDecode(staticChildren.first.payloadJson) as Map<String, dynamic>;

      expect(dynamicPayload['amount'], 100.0, reason: 'Dynamic recipe instance should update to 100mg');
      expect(staticPayload['amount'], 50.0, reason: 'Static recipe instance should remain 50mg');
    });

    test('Recipe with product: template change propagates recursively', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      // Setup: Product
      await products.upsertProduct(ProductDef(id: 'banana', name: 'Banana', createdAt: now, updatedAt: now));
      await products.setComponents('banana', [
        ProductComponent(productId: 'banana', kindId: 'protein', amountPerGram: 10.0), // 10g per 100g
      ]);

      // Setup: Recipe containing product
      await recipes.upsertRecipe(RecipeDef(id: 'smoothie', name: 'Smoothie', createdAt: now, updatedAt: now));
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.product(recipeId: 'smoothie', compId: 'banana', grams: 200),
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 50.0),
      ]);

      // Create dynamic recipe instance
      final target = DateTime.now();
      final recipeId = await recipeService.createRecipeEntry(
        recipeId: 'smoothie',
        targetAtLocal: target,
        isStatic: false,
      );

      // Verify initial structure
      final recipeChildren = await entries.listChildrenOfParent(recipeId!);
      expect(recipeChildren.length, 2); // vitamin_c + product parent

      final productParent = recipeChildren.firstWhere((c) => c.widgetKind == 'product');
      var productChildren = await entries.listChildrenOfParent(productParent.id);
      expect(productChildren.length, 1);
      var proteinPayload = jsonDecode(productChildren.first.payloadJson) as Map<String, dynamic>;
      expect(proteinPayload['amount'], 20.0); // 200g * 0.1 = 20g

      // Change recipe template: more banana
      await recipes.setComponents('smoothie', [
        RecipeComponentDef.product(recipeId: 'smoothie', compId: 'banana', grams: 300), // 200 -> 300
        RecipeComponentDef.kind(recipeId: 'smoothie', compId: 'vitamin_c', amount: 50.0),
      ]);

      // Propagate
      await recipeHierarchyService.propagateTemplateChange('smoothie');

      // Verify: product children updated (RECURSIVE)
      final updatedRecipeChildren = await entries.listChildrenOfParent(recipeId);
      final updatedProductParent = updatedRecipeChildren.firstWhere((c) => c.widgetKind == 'product');
      productChildren = await entries.listChildrenOfParent(updatedProductParent.id);
      proteinPayload = jsonDecode(productChildren.first.payloadJson) as Map<String, dynamic>;

      expect(proteinPayload['amount'], 30.0, reason: 'Protein should update to 30g (300g * 0.1)');
    });

    test('recipe_id column populated for new instances', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      await recipes.upsertRecipe(RecipeDef(id: 'test_recipe', name: 'Test', createdAt: now, updatedAt: now));
      await recipes.setComponents('test_recipe', [
        RecipeComponentDef.kind(recipeId: 'test_recipe', compId: 'vitamin_c', amount: 10.0),
      ]);

      final target = DateTime.now();
      final instanceId = await recipeService.createRecipeEntry(
        recipeId: 'test_recipe',
        targetAtLocal: target,
      );

      final instance = await entries.getById(instanceId!);
      expect(instance, isNotNull);
      expect(instance!.recipeId, 'test_recipe', reason: 'recipe_id column should be populated');
    });

    test('listParentsByRecipeId returns all instances', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      await recipes.upsertRecipe(RecipeDef(id: 'test', name: 'Test', createdAt: now, updatedAt: now));
      await recipes.setComponents('test', [
        RecipeComponentDef.kind(recipeId: 'test', compId: 'vitamin_c', amount: 10.0),
      ]);

      final target = DateTime.now();
      await recipeService.createRecipeEntry(recipeId: 'test', targetAtLocal: target);
      await recipeService.createRecipeEntry(recipeId: 'test', targetAtLocal: target.add(Duration(hours: 1)));
      await recipeService.createRecipeEntry(recipeId: 'test', targetAtLocal: target.add(Duration(hours: 2)));

      final instances = await entries.listParentsByRecipeId('test');
      expect(instances.length, 3, reason: 'Should find all 3 recipe instances');
      expect(instances.every((i) => i.recipeId == 'test'), isTrue);
    });
  });
}

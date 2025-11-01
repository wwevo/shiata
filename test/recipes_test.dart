import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:shiata/data/db/raw_db.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/entries_repository.dart';
import 'package:shiata/data/repo/product_service.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/data/repo/recipe_service.dart';

void main() {
  group('Recipes repository & service', () {
    late AppDb db;
    late KindsRepository kinds;
    late ProductsRepository products;
    late EntriesRepository entries;
    late RecipesRepository recipes;
    late ProductService productService;
    late RecipeService recipeService;

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.ensureInitialized();
      kinds = KindsRepository(db: db);
      products = ProductsRepository(db: db);
      entries = EntriesRepository(db: db);
      recipes = RecipesRepository(db: db);
      productService = ProductService(entries: entries, products: products);
      recipeService = RecipeService(entries: entries, recipes: recipes, productService: productService);
    });

    test('CRUD: create recipe, set components, get/list, delete', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      // Seed a kind and a product+component for later
      await kinds.upsertKind(KindDef(id: 'vitamin_c', name: 'Vitamin C', unit: 'mg', color: null, icon: null, min: 0, max: 100000, defaultShowInCalendar: false));
      await products.upsertProduct(ProductDef(id: 'smoothie', name: 'Smoothie', createdAt: now, updatedAt: now));
      await products.setComponents('smoothie', [
        ProductComponent(productId: 'smoothie', kindId: 'vitamin_c', amountPerGram: 0.5), // 0.5 mg per gram
      ]);

      // Create a recipe with 1 kind and 1 product component
      await recipes.upsertRecipe(RecipeDef(id: 'breakfast', name: 'Breakfast', createdAt: now, updatedAt: now));
      await recipes.setComponents('breakfast', [
        RecipeComponentDef.kind(recipeId: 'breakfast', compId: 'vitamin_c', amount: 60.0),
        RecipeComponentDef.product(recipeId: 'breakfast', compId: 'smoothie', grams: 250),
      ]);

      final list = await recipes.listRecipes();
      expect(list.map((r) => r.id).toList(), contains('breakfast'));
      final comps = await recipes.getComponents('breakfast');
      expect(comps.length, 2);
      expect(comps.any((c) => c is RecipeComponentDef && c.type == RecipeComponentType.kind && c.compId == 'vitamin_c'), isTrue);
      expect(comps.any((c) => c is RecipeComponentDef && c.type == RecipeComponentType.product && c.compId == 'smoothie'), isTrue);

      await recipes.deleteRecipe('breakfast');
      final afterDelete = await recipes.listRecipes();
      expect(afterDelete.any((r) => r.id == 'breakfast'), isFalse);
    });

    test('RecipeService: instantiate recipe → entries created with children', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      // Seed kinds/products
      await kinds.upsertKind(KindDef(id: 'vitamin_c', name: 'Vitamin C', unit: 'mg', color: null, icon: null, min: 0, max: 100000, defaultShowInCalendar: false));
      await kinds.upsertKind(KindDef(id: 'protein', name: 'Protein', unit: 'g', color: null, icon: null, min: 0, max: 100000, defaultShowInCalendar: false));
      await products.upsertProduct(ProductDef(id: 'smoothie', name: 'Smoothie', createdAt: now, updatedAt: now));
      await products.setComponents('smoothie', [
        ProductComponent(productId: 'smoothie', kindId: 'protein', amountPerGram: 0.1),
      ]);

      await recipes.upsertRecipe(RecipeDef(id: 'breakfast', name: 'Breakfast', createdAt: now, updatedAt: now));
      await recipes.setComponents('breakfast', [
        RecipeComponentDef.kind(recipeId: 'breakfast', compId: 'vitamin_c', amount: 60.0),
        RecipeComponentDef.product(recipeId: 'breakfast', compId: 'smoothie', grams: 200),
      ]);

      final target = DateTime.now();
      final parentId = await recipeService.createRecipeEntry(recipeId: 'breakfast', targetAtLocal: target);
      expect(parentId, isNotNull);
      // Verify parent exists
      final parent = await entries.getById(parentId!);
      expect(parent, isNotNull);
      expect(parent!.widgetKind, 'recipe');
      final payload = jsonDecode(parent.payloadJson) as Map<String, dynamic>;
      expect(payload['name'], 'Breakfast');

      // Verify direct children under recipe parent
      final children = await entries.listChildrenOfParent(parentId);
      // One should be vitamin_c (direct), one should be a product parent for smoothie
      expect(children.any((c) => c.widgetKind == 'vitamin_c'), isTrue);
      expect(children.any((c) => c.widgetKind == 'product'), isTrue);

      final productParent = children.firstWhere((c) => c.widgetKind == 'product');
      // Verify product children (protein) exist under the product parent
      final grand = await entries.listChildrenOfParent(productParent.id);
      expect(grand.any((c) => c.widgetKind == 'protein'), isTrue);
    });

    test('RecipeService: delete recipe template converts instances children and removes parents', () async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await kinds.upsertKind(KindDef(id: 'vitamin_c', name: 'Vitamin C', unit: 'mg', color: null, icon: null, min: 0, max: 100000, defaultShowInCalendar: false));
      await products.upsertProduct(ProductDef(id: 'smoothie', name: 'Smoothie', createdAt: now, updatedAt: now));
      await products.setComponents('smoothie', [
        ProductComponent(productId: 'smoothie', kindId: 'vitamin_c', amountPerGram: 0.2),
      ]);
      await recipes.upsertRecipe(RecipeDef(id: 'r1', name: 'R1', createdAt: now, updatedAt: now));
      await recipes.setComponents('r1', [
        RecipeComponentDef.kind(recipeId: 'r1', compId: 'vitamin_c', amount: 30.0),
        RecipeComponentDef.product(recipeId: 'r1', compId: 'smoothie', grams: 150),
      ]);
      final target = DateTime.now();
      final parentId = await recipeService.createRecipeEntry(recipeId: 'r1', targetAtLocal: target);
      expect(parentId, isNotNull);

      // Delete the template (should convert existing instances children and remove parents)
      await recipeService.deleteRecipeTemplate('r1');

      // No recipe parents should remain
      final all = await db.customSelect("SELECT * FROM entries WHERE widget_kind = 'recipe';").get();
      expect(all, isEmpty);
    });
  });
}

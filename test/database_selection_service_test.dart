import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/data/repo/database_selection_service.dart';
import 'package:shiata/data/repo/entries_repository.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/ui/main_screen_providers.dart';

void main() {
  group('DatabaseSelectionService Tests', () {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    final vitaminC = KindDef(
      id: 'kind_vitamin_c',
      name: 'Vitamin C',
      unit: 'mg',
      min: 0,
      max: 1000,
    );
    final protein = KindDef(
      id: 'kind_protein',
      name: 'Protein',
      unit: 'g',
      min: 0,
      max: 1000,
    );
    final calories = KindDef(
      id: 'kind_calories',
      name: 'Calories',
      unit: 'kcal',
      min: 0,
      max: 10000,
    );

    final banana = ProductDef(
      id: 'prod_banana',
      name: 'Banana',
      createdAt: now,
      updatedAt: now,
    );
    final apple = ProductDef(
      id: 'prod_apple',
      name: 'Apple',
      createdAt: now,
      updatedAt: now,
    );

    final fruitSalad = RecipeDef(
      id: 'recipe_fruit_salad',
      name: 'Fruit Salad',
      createdAt: now,
      updatedAt: now,
    );

    final List<ProductComponent> productComponents = [
      ProductComponent(
        productId: 'prod_banana',
        kindId: 'kind_vitamin_c',
        amountPerGram: 10,
      ),
      ProductComponent(
        productId: 'prod_banana',
        kindId: 'kind_protein',
        amountPerGram: 1,
      ),
      ProductComponent(
        productId: 'prod_apple',
        kindId: 'kind_vitamin_c',
        amountPerGram: 5,
      ),
    ];

    final List<RecipeComponentDef> recipeComponents = [
      RecipeComponentDef.product(
        recipeId: 'recipe_fruit_salad',
        compId: 'prod_banana',
        grams: 100,
      ),
      RecipeComponentDef.product(
        recipeId: 'recipe_fruit_salad',
        compId: 'prod_apple',
        grams: 100,
      ),
      RecipeComponentDef.kind(
        recipeId: 'recipe_fruit_salad',
        compId: 'kind_calories',
        amount: 150,
      ),
    ];

    final List<KindDef> kinds = [vitaminC, protein, calories];
    final List<ProductDef> products = [banana, apple];
    final List<RecipeDef> recipes = [fruitSalad];

    final entry1 = EntryRecord(
      id: 'entry_recipe_1',
      widgetKind: 'recipe',
      targetAt: now,
      payloadJson: '{"name": "Breakfast Salad"}',
      showInCalendar: true,
      createdAt: now,
      updatedAt: now,
    );
    final entry2 = EntryRecord(
      id: 'entry_prod_1',
      widgetKind: 'product',
      targetAt: now,
      payloadJson: '{"name": "Banana"}',
      sourceEntryId: 'entry_recipe_1',
      showInCalendar: true,
      createdAt: now,
      updatedAt: now,
    );
    final entry3 = EntryRecord(
      id: 'entry_kind_1',
      widgetKind: 'kind',
      targetAt: now,
      payloadJson: '{"name": "Vitamin C"}',
      sourceEntryId: 'entry_prod_1',
      showInCalendar: true,
      createdAt: now,
      updatedAt: now,
    );
    final List<EntryRecord> entries = [entry1, entry2, entry3];

    test('Selecting a recipe selects all product and kind descendants all the way down', () {
      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'recipe_fruit_salad',
        category: SelectionCategory.recipes,
        selected: true,
        currentSelection: {},
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      // Descendants: prod_banana, prod_apple, kind_vitamin_c, kind_protein, kind_calories
      expect(result.includedChildCount, 5);
      expect(result.newSelection.containsKey('recipe_fruit_salad'), isTrue);
      expect(result.newSelection['recipe_fruit_salad'], SelectionCategory.recipes);
      expect(result.newSelection['prod_banana'], SelectionCategory.products);
      expect(result.newSelection['prod_apple'], SelectionCategory.products);
      expect(result.newSelection['kind_vitamin_c'], SelectionCategory.kinds);
      expect(result.newSelection['kind_protein'], SelectionCategory.kinds);
      expect(result.newSelection['kind_calories'], SelectionCategory.kinds);
    });

    test('Selecting a product selects its component kinds', () {
      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'prod_banana',
        category: SelectionCategory.products,
        selected: true,
        currentSelection: {},
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      expect(result.includedChildCount, 2);
      expect(result.newSelection['prod_banana'], SelectionCategory.products);
      expect(result.newSelection['kind_vitamin_c'], SelectionCategory.kinds);
      expect(result.newSelection['kind_protein'], SelectionCategory.kinds);
    });

    test('Selecting a recipe when all child nodes are already selected results in includedChildCount of 0', () {
      final initialSelection = <String, SelectionCategory>{
        'prod_banana': SelectionCategory.products,
        'prod_apple': SelectionCategory.products,
        'kind_protein': SelectionCategory.kinds,
        'kind_vitamin_c': SelectionCategory.kinds,
        'kind_calories': SelectionCategory.kinds,
      };

      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'recipe_fruit_salad',
        category: SelectionCategory.recipes,
        selected: true,
        currentSelection: initialSelection,
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      expect(result.includedChildCount, 0);
      expect(result.newSelection.containsKey('recipe_fruit_salad'), isTrue);
    });

    test('Selecting a recipe when some child nodes are already selected counts only unselected child nodes', () {
      final initialSelection = <String, SelectionCategory>{
        'prod_banana': SelectionCategory.products,
        'kind_vitamin_c': SelectionCategory.kinds,
      };

      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'recipe_fruit_salad',
        category: SelectionCategory.recipes,
        selected: true,
        currentSelection: initialSelection,
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      // Total descendants: 5 (prod_banana, prod_apple, kind_vitamin_c, kind_protein, kind_calories)
      // Already selected: prod_banana, kind_vitamin_c -> 3 remaining
      expect(result.includedChildCount, 3);
    });

    test('Deselecting a child kind deselects its parent product and parent recipe with warning names', () {
      // First select the recipe and all children
      final initialSelection = <String, SelectionCategory>{
        'recipe_fruit_salad': SelectionCategory.recipes,
        'prod_banana': SelectionCategory.products,
        'prod_apple': SelectionCategory.products,
        'kind_protein': SelectionCategory.kinds,
        'kind_vitamin_c': SelectionCategory.kinds,
        'kind_calories': SelectionCategory.kinds,
      };

      // Deselect protein (which is a component of banana, which is in fruit_salad)
      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'kind_protein',
        category: SelectionCategory.kinds,
        selected: false,
        currentSelection: initialSelection,
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      expect(result.newSelection.containsKey('kind_protein'), isFalse);
      expect(result.newSelection.containsKey('prod_banana'), isFalse);
      expect(result.newSelection.containsKey('recipe_fruit_salad'), isFalse);
      // Apple and Calories and Vitamin C are still selected
      expect(result.newSelection.containsKey('prod_apple'), isTrue);
      expect(result.newSelection.containsKey('kind_calories'), isTrue);
      expect(result.newSelection.containsKey('kind_vitamin_c'), isTrue);

      expect(result.deselectedParentNames, contains('Banana'));
      expect(result.deselectedParentNames, contains('Fruit Salad'));
    });

    test('Deselecting a child product deselects parent recipe with warning names', () {
      final initialSelection = <String, SelectionCategory>{
        'recipe_fruit_salad': SelectionCategory.recipes,
        'prod_banana': SelectionCategory.products,
      };

      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'prod_banana',
        category: SelectionCategory.products,
        selected: false,
        currentSelection: initialSelection,
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      expect(result.newSelection.containsKey('prod_banana'), isFalse);
      expect(result.newSelection.containsKey('recipe_fruit_salad'), isFalse);
      expect(result.deselectedParentNames, ['Fruit Salad']);
    });

    test('Selecting a top-level calendar entry selects all nested child entries', () {
      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'entry_recipe_1',
        category: SelectionCategory.entries,
        selected: true,
        currentSelection: {},
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      expect(result.includedChildCount, 2);
      expect(result.newSelection['entry_recipe_1'], SelectionCategory.entries);
      expect(result.newSelection['entry_prod_1'], SelectionCategory.entries);
      expect(result.newSelection['entry_kind_1'], SelectionCategory.entries);
    });

    test('Deselecting a nested child entry deselects ancestor entries with warning names', () {
      final initialSelection = <String, SelectionCategory>{
        'entry_recipe_1': SelectionCategory.entries,
        'entry_prod_1': SelectionCategory.entries,
        'entry_kind_1': SelectionCategory.entries,
      };

      final result = DatabaseSelectionService.handleSelectionChange(
        entryId: 'entry_kind_1',
        category: SelectionCategory.entries,
        selected: false,
        currentSelection: initialSelection,
        kinds: kinds,
        products: products,
        recipes: recipes,
        recipeComponents: recipeComponents,
        productComponents: productComponents,
        allEntries: entries,
      );

      expect(result.newSelection.containsKey('entry_kind_1'), isFalse);
      expect(result.newSelection.containsKey('entry_prod_1'), isFalse);
      expect(result.newSelection.containsKey('entry_recipe_1'), isFalse);
      expect(result.deselectedParentNames, contains('Banana'));
      expect(result.deselectedParentNames, contains('Breakfast Salad'));
    });
  });
}

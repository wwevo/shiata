import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiata/data/providers.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';
import 'package:shiata/ui/main_screen_providers.dart';
import 'package:shiata/ui/pages/database_page.dart';

void main() {
  group('DatabasePage Selection Widget Tests', () {
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

    final banana = ProductDef(
      id: 'prod_banana',
      name: 'Banana',
      createdAt: now,
      updatedAt: now,
    );

    final fruitSalad = RecipeDef(
      id: 'recipe_fruit_salad',
      name: 'Fruit Salad',
      createdAt: now,
      updatedAt: now,
    );

    final productComponents = [
      ProductComponent(
        productId: 'prod_banana',
        kindId: 'kind_vitamin_c',
        amountPerGram: 5.0,
      ),
      ProductComponent(
        productId: 'prod_banana',
        kindId: 'kind_protein',
        amountPerGram: 1.0,
      ),
    ];

    final recipeComponents = [
      RecipeComponentDef.product(
        recipeId: 'recipe_fruit_salad',
        compId: 'prod_banana',
        grams: 100,
      ),
    ];

    testWidgets(
        'Selecting a recipe shows info popup; cancelling leaves selection empty; confirming selects children',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          kindsListProvider
              .overrideWith((ref) => Stream.value([vitaminC, protein])),
          allProductsListProvider.overrideWith((ref) => Stream.value([banana])),
          allRecipesListProvider
              .overrideWith((ref) => Stream.value([fruitSalad])),
          allProductComponentsProvider
              .overrideWith((ref) => Stream.value(productComponents)),
          allRecipeComponentsProvider
              .overrideWith((ref) => Stream.value(recipeComponents)),
          allEntriesWithChildrenProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DatabasePage(),
          ),
        ),
      );

      // Pump several frames so all async stream providers emit data
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Recipes tab (Tab index 3)
      await tester.tap(find.text('Recipes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Fruit Salad'), findsOneWidget);

      // Find checkbox on Fruit Salad and tap it
      final recipeCheckbox = find.byType(Checkbox).hitTestable();
      expect(recipeCheckbox, findsOneWidget);

      await tester.tap(recipeCheckbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify info popup appears
      expect(find.text('3 child nodes need to be included'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);

      // 1. Cancel the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify selection remains empty
      expect(container.read(bulkSelectionProvider).isEmpty, isTrue);

      // 2. Tap checkbox again and confirm this time
      await tester.tap(recipeCheckbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('3 child nodes need to be included'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify selection in bulkSelectionProvider contains recipe and children
      final selection = container.read(bulkSelectionProvider);
      expect(selection.containsKey('recipe_fruit_salad'), isTrue);
      expect(selection.containsKey('prod_banana'), isTrue);
      expect(selection.containsKey('kind_vitamin_c'), isTrue);
      expect(selection.containsKey('kind_protein'), isTrue);

      // Switch to Products tab and verify banana is selected
      await tester.tap(find.text('Products'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Banana'), findsOneWidget);
      final productCheckbox =
          tester.widget<Checkbox>(find.byType(Checkbox).hitTestable());
      expect(productCheckbox.value, isTrue);

      // Switch to Kinds tab
      await tester.tap(find.text('Kinds'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vitamin C'), findsOneWidget);

      // Find the checkbox for Vitamin C and uncheck it
      final kindCheckboxes = find.byType(Checkbox).hitTestable();
      await tester.tap(kindCheckboxes.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Warning popup should appear saying Banana and Fruit Salad will be deselected
      expect(find.textContaining('will be deselected as well'), findsOneWidget);
      expect(find.textContaining('Banana'), findsOneWidget);
      expect(find.textContaining('Fruit Salad'), findsOneWidget);

      // 3. Cancel the warning dialog -> selection shouldn't change
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final unchangedSelection = container.read(bulkSelectionProvider);
      expect(unchangedSelection.containsKey('recipe_fruit_salad'), isTrue);
      expect(unchangedSelection.containsKey('prod_banana'), isTrue);
      expect(unchangedSelection.containsKey('kind_vitamin_c'), isTrue);

      // 4. Tap Vitamin C again and Confirm deselection
      await tester.tap(kindCheckboxes.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('will be deselected as well'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final updatedSelection = container.read(bulkSelectionProvider);
      expect(updatedSelection.containsKey('recipe_fruit_salad'), isFalse);
      expect(updatedSelection.containsKey('prod_banana'), isFalse);
      expect(updatedSelection.containsKey('kind_vitamin_c'), isFalse);
      // protein is still selected
      expect(updatedSelection.containsKey('kind_protein'), isTrue);
    });

    testWidgets(
        'Selecting a recipe when all child nodes are already selected does not show info popup',
        (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          kindsListProvider
              .overrideWith((ref) => Stream.value([vitaminC, protein])),
          allProductsListProvider.overrideWith((ref) => Stream.value([banana])),
          allRecipesListProvider
              .overrideWith((ref) => Stream.value([fruitSalad])),
          allProductComponentsProvider
              .overrideWith((ref) => Stream.value(productComponents)),
          allRecipeComponentsProvider
              .overrideWith((ref) => Stream.value(recipeComponents)),
          allEntriesWithChildrenProvider.overrideWith((ref) => Stream.value([])),
        ],
      );

      // Pre-select all child nodes
      container.read(bulkSelectionProvider.notifier).state = {
        'prod_banana': SelectionCategory.products,
        'kind_vitamin_c': SelectionCategory.kinds,
        'kind_protein': SelectionCategory.kinds,
      };

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DatabasePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Recipes tab
      await tester.tap(find.text('Recipes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Fruit Salad'), findsOneWidget);

      final recipeCheckbox = find.byType(Checkbox).hitTestable();
      expect(recipeCheckbox, findsOneWidget);

      await tester.tap(recipeCheckbox);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No dialog should appear
      expect(find.textContaining('child nodes need to be included'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      // Recipe should now be selected
      final selection = container.read(bulkSelectionProvider);
      expect(selection.containsKey('recipe_fruit_salad'), isTrue);
      expect(selection.containsKey('prod_banana'), isTrue);
      expect(selection.containsKey('kind_vitamin_c'), isTrue);
      expect(selection.containsKey('kind_protein'), isTrue);
    });
  });
}

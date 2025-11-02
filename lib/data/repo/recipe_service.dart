
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'entries_repository.dart';
import 'recipes_repository.dart';
import 'product_service.dart';
import 'package:drift/drift.dart';

class RecipeService {
  RecipeService({required this.entries, required this.recipes, required this.productService});
  final EntriesRepository entries;
  final RecipesRepository recipes;
  final ProductService? productService;

  /// Creates a static parent recipe entry and its children for the given recipe id.
  /// - Kind components: create direct child entries with `amount: double` and `showInCalendar=false`.
  /// - Product components: delegate to ProductService to create a product parent+children and link the product parent under the recipe parent.
  Future<String?> createRecipeEntry({
    required String recipeId,
    required DateTime targetAtLocal,
    Map<String, double>? kindOverrides,
    Map<String, int>? productGramOverrides,
    bool showParentInCalendar = true,
  }) async {
    final def = await recipes.getRecipe(recipeId);
    if (def == null) return null;
    final comps = await recipes.getComponents(recipeId);

    // Parent payload keeps recipe id and name for simple rendering.
    final parent = await entries.create(
      widgetKind: 'recipe',
      targetAtLocal: targetAtLocal,
      payload: {
        'recipe_id': recipeId,
        'name': def.name,
      },
      showInCalendar: showParentInCalendar,
      schemaVersion: 1,
      isStatic: true,
    );

    // Create children
    for (final c in comps) {
      if (c.type == RecipeComponentType.kind) {
        final amount = (kindOverrides?[c.compId]) ?? (c.amount ?? 0.0);
        await entries.create(
          widgetKind: c.compId,
          targetAtLocal: targetAtLocal,
          payload: {
            'amount': amount,
          },
          showInCalendar: false,
          schemaVersion: 1,
          sourceEntryId: parent.id,
          sourceWidgetKind: 'recipe',
        );
      } else {
        // Product component
        final grams = (productGramOverrides?[c.compId]) ?? (c.grams ?? 0);
        if (productService != null && grams > 0) {
          // Create a product parent entry; then link it under recipe parent by updating source fields.
          final productParentId = await productService!.createProductEntry(
            productId: c.compId,
            productGrams: grams,
            targetAtLocal: targetAtLocal,
            isStatic: true,
          );
          if (productParentId != null) {
            await entries.update(productParentId, {
              'source_entry_id': parent.id,
              'source_widget_kind': 'recipe',
            });
          }
        }
      }
    }

    return parent.id;
  }

  /// Delete a recipe template and convert all its instances' children to standalone entries.
  /// - For each recipe parent entry, detach children and delete the parent.
  Future<void> deleteRecipeTemplate(String recipeId) async {
    // Find all parent entries for this recipe
    final parents = await entries.db.customSelect(
      "SELECT * FROM entries WHERE widget_kind = 'recipe' AND json_extract(payload_json, '\$.recipe_id') = ?;",
      variables: [Variable.withString(recipeId)],
    ).get();
    for (final row in parents) {
      final parentId = row.data['id'] as String;
      // Detach children and make them visible
      await entries.convertChildrenOfParentToStandalone(parentId);
      // Delete the parent
      await entries.delete(parentId);
    }
    // Delete template and its components
    await recipes.deleteRecipe(recipeId);
  }
}

final recipeServiceProvider = Provider<RecipeService?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final r = ref.watch(recipesRepositoryProvider);
  final ps = ref.watch(productServiceProvider);
  if (e == null || r == null) return null;
  return RecipeService(entries: e, recipes: r, productService: ps);
});

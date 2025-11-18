import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'entries_repository.dart';
import 'recipe_service.dart';
import 'recipes_repository.dart';

/// Service for propagating recipe template changes to instances.
class RecipeHierarchyService {
  RecipeHierarchyService({
    required this.entries,
    required this.recipes,
    required this.recipeService,
  });

  final EntriesRepository entries;
  final RecipesRepository recipes;
  final RecipeService recipeService;

  /// Propagate template changes to non-static instances.
  /// When a recipe template is updated, this recalculates all non-static instances.
  /// Returns the number of instances that were updated.
  Future<int> propagateTemplateChange(String recipeId) async {
    // Get recipe definition for current name
    final def = await recipes.getRecipe(recipeId);
    if (def == null) return 0;

    // Get all instances of this recipe
    final instances = await entries.listParentsByRecipeId(recipeId);

    int updatedCount = 0;
    for (final instance in instances) {
      if (!instance.isStatic) {
        // Update parent payload with current name from template
        final payload = jsonDecode(instance.payloadJson) as Map<String, dynamic>;
        payload['name'] = def.name;
        await entries.update(instance.id, {
          'payload_json': jsonEncode(payload),
        });

        // Reset and recreate children from template
        await entries.deleteChildrenOfParent(instance.id);

        final targetAt = DateTime.fromMillisecondsSinceEpoch(
          instance.targetAt,
          isUtc: true,
        ).toLocal();
        final comps = await recipes.getComponents(recipeId);

        for (final c in comps) {
          if (c.type == RecipeComponentType.kind) {
            final amount = c.amount ?? 0.0;
            await entries.create(
              widgetKind: c.compId,
              targetAtLocal: targetAt,
              payload: {'amount': amount},
              showInCalendar: false,
              sourceEntryId: instance.id,
              sourceWidgetKind: 'recipe',
            );
          } else {
            final grams = c.grams ?? 0;
            if (grams > 0) {
              final productService = recipeService.productService;
              if (productService != null) {
                final productParentId = await productService.createProductEntry(
                  productId: c.compId,
                  productGrams: grams,
                  targetAtLocal: targetAt,
                  isStatic: false,
                );
                if (productParentId != null) {
                  await entries.update(productParentId, {
                    'source_entry_id': instance.id,
                    'source_widget_kind': 'recipe',
                  });
                }
              }
            }
          }
        }

        updatedCount++;
      }
    }

    return updatedCount;
  }
}

final recipeHierarchyServiceProvider = Provider<RecipeHierarchyService?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final r = ref.watch(recipesRepositoryProvider);
  final rs = ref.watch(recipeServiceProvider);
  if (e == null || r == null || rs == null) return null;
  return RecipeHierarchyService(
    entries: e,
    recipes: r,
    recipeService: rs,
  );
});

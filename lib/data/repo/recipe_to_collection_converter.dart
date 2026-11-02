import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'collections_repository.dart';
import 'entries_repository.dart';
import 'recipes_repository.dart';

/// Service for converting recipes to collections
class RecipeToCollectionConverter {
  RecipeToCollectionConverter({
    required this.entries,
    required this.recipes,
    required this.collections,
  });

  final EntriesRepository entries;
  final RecipesRepository recipes;
  final CollectionsRepository collections;

  /// Copy a recipe to a new collection (recipe remains unchanged)
  Future<void> copyRecipeToCollection(String recipeId) async {
    final recipe = await recipes.getRecipe(recipeId);
    if (recipe == null) return;
    final comps = await recipes.getComponents(recipeId);

    // Create new collection with same data
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await collections.upsertCollection(
      CollectionDef(
        id: recipeId, // Use same ID
        name: recipe.name,
        createdAt: now,
        updatedAt: now,
        isActive: true,
        icon: recipe.icon,
        color: recipe.color,
        isProtected: recipe.isProtected,
      ),
    );

    // Convert components
    final collectionComps = <CollectionComponentDef>[];
    for (final c in comps) {
      if (c.type == RecipeComponentType.kind) {
        collectionComps.add(
          CollectionComponentDef.kind(
            collectionId: recipeId,
            compId: c.compId,
            amount: c.amount ?? 0.0,
          ),
        );
      } else {
        collectionComps.add(
          CollectionComponentDef.product(
            collectionId: recipeId,
            compId: c.compId,
            grams: c.grams ?? 0,
          ),
        );
      }
    }
    await collections.setComponents(recipeId, collectionComps);
  }

  /// Move recipe to collection: delete recipe, convert non-static instances
  Future<void> moveRecipeToCollection(String recipeId, {bool convertAll = false}) async {
    // 1. Copy recipe data to collection
    await copyRecipeToCollection(recipeId);

    // 2. Find all recipe instances
    final parentEntries = await entries.listParentsByRecipeId(recipeId);

    // 3. Convert instances
    for (final parent in parentEntries) {
      // Skip static instances unless convertAll is true
      if (parent.isStatic && !convertAll) continue;

      // Update widget_kind from 'recipe' to 'collection'
      // Update payload_json to use collection_id instead of recipe_id
      try {
        final payload = jsonDecode(parent.payloadJson) as Map<String, dynamic>;
        payload['collection_id'] = payload['recipe_id'];
        payload.remove('recipe_id');

        await entries.update(parent.id, {
          'widget_kind': 'collection',
          'payload_json': jsonEncode(payload),
        });

        // Update children's source_widget_kind
        final children = await entries.listChildrenOfParent(parent.id);
        for (final child in children) {
          await entries.update(child.id, {
            'source_widget_kind': 'collection',
          });
        }
      } catch (_) {
        // Skip entries that fail to convert
      }
    }

    // 4. Delete the original recipe
    await recipes.deleteRecipe(recipeId);
  }
}

final recipeToCollectionConverterProvider = Provider<RecipeToCollectionConverter?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final r = ref.watch(recipesRepositoryProvider);
  final c = ref.watch(collectionsRepositoryProvider);
  if (e == null || r == null || c == null) return null;
  return RecipeToCollectionConverter(entries: e, recipes: r, collections: c);
});

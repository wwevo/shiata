import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/recipe_service.dart';
import '../../data/repo/recipes_repository.dart';
import '../../domain/widgets/registry.dart';
import '../editors/recipe_template_editor_dialog.dart';
import '../widgets/icon_resolver.dart';

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesListProvider);
    final repo = ref.watch(recipesRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            tooltip: 'Add recipe',
            onPressed: repo == null
                ? null
                : () async {
                    showDialog(
                      context: context,
                      builder: (_) => const RecipeEditorDialog(
                        existing: null, // Create mode
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: recipesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No recipes yet'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final r = list[i];
              final icon = resolveIcon(r.icon, Icons.restaurant_menu);
              final color = r.color != null ? Color(r.color!) : Colors.brown;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    child: Icon(icon, color: Colors.white),
                  ),
                  title: Text(r.name),
                  subtitle: _RecipeTemplateSummary(recipeId: r.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => RecipeEditorDialog(
                              existing: r,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteRecipe(context, ref, r, repo),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _deleteRecipe(
    BuildContext context,
    WidgetRef ref,
    RecipeDef recipe,
    RecipesRepository? repo,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete recipe?'),
            content: const Text(
              'Instances will convert: children become standalone entries; parents removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    final svc = ref.read(recipeServiceProvider);
    if (svc == null || repo == null) return;
    await svc.deleteRecipeTemplate(recipe.id);
    await repo.deleteRecipe(recipe.id);
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Recipe deleted')));
  }

}

/// Shows component summary for a recipe template (products + kinds)
class _RecipeTemplateSummary extends ConsumerWidget {
  const _RecipeTemplateSummary({required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesRepo = ref.watch(recipesRepositoryProvider);
    final productsRepo = ref.watch(productsRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);

    if (recipesRepo == null || productsRepo == null) {
      return Text(recipeId);
    }

    return StreamBuilder<List<RecipeComponentDef>>(
      stream: recipesRepo.watchComponents(recipeId),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return Text(recipeId);
        }

        final components = snapshot.data!;
        if (components.isEmpty) {
          return Text('$recipeId • No components');
        }

        // Aggregate components
        double totalProductGrams = 0.0;
        final kindSummaries = <String, double>{};

        for (final comp in components) {
          if (comp.type == RecipeComponentType.product) {
            totalProductGrams += (comp.grams ?? 0).toDouble();
          } else if (comp.type == RecipeComponentType.kind) {
            kindSummaries[comp.compId] =
                (kindSummaries[comp.compId] ?? 0.0) + (comp.amount ?? 0.0);
          }
        }

        // Build summary
        final parts = <String>[];
        if (totalProductGrams > 0) {
          final formatted = totalProductGrams < 1
              ? totalProductGrams.toStringAsFixed(2)
              : totalProductGrams.toStringAsFixed(0);
          parts.add('${formatted}g');
        }

        // Add top kind amounts
        if (kindSummaries.isNotEmpty) {
          // Normalize values for sorting (convert all to grams for weight units)
          final normalizedForSort = <String, double>{};
          for (final entry in kindSummaries.entries) {
            final k = registry.byId(entry.key);
            final unit = k?.unit ?? '';
            double normalized = entry.value;
            switch (unit) {
              case 'mg':
                normalized = entry.value / 1000;
                break;
              case 'ug':
              case 'µg':
                normalized = entry.value / 1000000;
                break;
              default:
                normalized = entry.value;
            }
            normalizedForSort[entry.key] = normalized;
          }

          // Sort by normalized values
          final sortedKinds = kindSummaries.entries.toList()
            ..sort(
              (a, b) => (normalizedForSort[b.key] ?? 0.0).compareTo(
                normalizedForSort[a.key] ?? 0.0,
              ),
            );

          for (final entry in sortedKinds.take(2)) {
            final kind = registry.byId(entry.key);
            final kindName = kind?.displayName ?? entry.key;
            final unit = kind?.unit ?? '';
            final formatted = entry.value < 1
                ? entry.value.toStringAsFixed(2)
                : entry.value.toStringAsFixed(0);
            parts.add('$kindName: $formatted$unit');
          }
        }

        final summary = parts.isEmpty ? recipeId : parts.join(' • ');
        return Text(summary);
      },
    );
  }
}

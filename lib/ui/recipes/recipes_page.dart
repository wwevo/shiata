
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipe_service.dart';
import '../../data/repo/recipes_repository.dart';
import '../../domain/widgets/registry.dart';
import '../editors/recipe_template_editor_dialog.dart';
import '../widgets/icon_resolver.dart';

class RecipesPage extends ConsumerWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    final created = await _askForIdAndName(context);
                    if (created == null) return;
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (_) => RecipeEditorDialog(
                          recipeId: created.key,
                          recipeName: created.value,
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: repo == null
          ? const Center(child: Text('Repository not ready'))
          : StreamBuilder<List<RecipeDef>>(
              stream: repo.watchRecipes(),
              builder: (context, snapshot) {
                final list = snapshot.data ?? const <RecipeDef>[];
                if (list.isEmpty) return const Center(child: Text('No recipes yet'));
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
                                  builder: (_) => RecipeEditorDialog(recipeId: r.id),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete recipe?'),
                                        content: const Text('Instances will convert: children become standalone entries; parents removed.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (!confirm) return;
                                final svc = ref.read(recipeServiceProvider);
                                if (svc == null) return;
                                await svc.deleteRecipeTemplate(r.id);
                                await repo.deleteRecipe(r.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe deleted')));
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Future<MapEntry<String, String>?> _askForIdAndName(BuildContext context) async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('New recipe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'Id (stable, e.g., potato_salad)')),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (display)')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
            ],
          ),
        ) ??
        false;
    if (!ok) return null;
    final id = idCtrl.text.trim();
    final name = nameCtrl.text.trim();
    if (id.isEmpty || name.isEmpty) return null;
    return MapEntry(id, name);
  }
}

/// Shows component summary for a recipe template (products + nutrients)
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

    return FutureBuilder<List<RecipeComponentDef>>(
      future: recipesRepo.getComponents(recipeId),
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
            kindSummaries[comp.compId] = (kindSummaries[comp.compId] ?? 0.0) + (comp.amount ?? 0.0);
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
          final sortedKinds = kindSummaries.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
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

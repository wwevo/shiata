
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/recipe_service.dart';
import '../../data/repo/recipes_repository.dart';
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
                    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
                    await repo.upsertRecipe(RecipeDef(id: created.key, name: created.value, createdAt: now, updatedAt: now));
                    if (context.mounted) {
//                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeEditorPage(recipeId: created.key)));
                      showDialog(
                        context: context,
                        builder: (_) => RecipeEditorDialog(recipeId: created.key),
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
                        subtitle: Text(r.id),
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/recipe_service.dart';
import '../../domain/widgets/registry.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../editors/product_instance_editor_dialog.dart';
import '../main_screen_providers.dart';

class SearchResults extends ConsumerWidget {
  const SearchResults({super.key, required this.controller});
  final ScrollController controller;

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final q = ref.watch(searchQueryProvider);
    if (repo == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<EntryRecord>>(
      stream: repo.watchSearch(q),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const <EntryRecord>[];
        if (q.trim().isEmpty) {
          return const Center(child: Text('Type to search'));
        }
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No results for "$q"', style: Theme.of(context).textTheme.bodyMedium),
            ),
          );
        }
        return ListView.builder(
          controller: controller,
          itemCount: results.length,
          itemBuilder: (ctx, i) {
            final e = results[i];
            final kind = registry.byId(e.widgetKind);

            // Determine icon and color based on widget kind
            IconData icon;
            Color color;
            if (e.widgetKind == 'product') {
              icon = Icons.shopping_basket;
              color = Colors.purple;
            } else if (e.widgetKind == 'recipe') {
              icon = Icons.restaurant_menu;
              color = Colors.brown;
            } else {
              icon = kind?.icon ?? Icons.circle;
              color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
            }

            // Extract title and summary from payload
            String title = kind?.displayName ?? e.widgetKind;
            String summary = '';
            try {
              final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;

              // Extract name for products and recipes
              if (e.widgetKind == 'product') {
                title = (map['name'] as String?) ?? 'Product';
                final grams = (map['grams'] as num?)?.toInt();
                if (grams != null) summary = '$grams g';
              } else if (e.widgetKind == 'recipe') {
                title = (map['name'] as String?) ?? 'Recipe';
              } else {
                // For kinds, show amount
                final amount = (map['amount'] as num?)?.toDouble();
                if (amount != null) {
                  summary = '${amount.toStringAsFixed(1)} ${kind?.unit ?? ''}';
                }
              }
            } catch (_) {}

            final localTime = DateTime.fromMillisecondsSinceEpoch(e.targetAt, isUtc: true).toLocal();

            final isProduct = e.widgetKind == 'product';
            final isRecipe = e.widgetKind == 'recipe';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Icon(icon, size: 18),
                ),
                title: Text('$title${summary.isEmpty ? '' : ' • $summary'}'),
                subtitle: Text(
                  '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}  ${_fmtTime(localTime)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isProduct)
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => ProductEditorDialog(entryId: e.id),
                          );
                        },
                      )
                    else if (!isRecipe)
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          final k = registry.byId(e.widgetKind);
                          if (k != null) {
                            showDialog(
                              context: context,
                              builder: (_) => KindInstanceEditorDialog(kind: k, entryId: e.id),
                            );
                          }
                        },
                      ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteEntry(context, ref, e, isProduct, isRecipe, repo),
                    ),
                    Icon(isProduct || isRecipe ? Icons.chevron_right : Icons.chevron_right),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    EntryRecord e,
    bool isProduct,
    bool isRecipe,
    EntriesRepository repo,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          isProduct
              ? 'This will remove the product entry and its components. You can undo from the snackbar.'
              : 'This will remove the entry. You can undo from the snackbar.',
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
    );
    if (confirm != true) return;

    if (isProduct) {
      final original = e;
      Map<String, Object?> parentPayload = const {};
      String? productId;
      int grams = 0;
      bool staticFlag = false;
      try {
        final map = jsonDecode(original.payloadJson) as Map<String, dynamic>;
        parentPayload = map;
        productId = map['product_id'] as String?;
        grams = (map['grams'] as num?)?.toInt() ?? 0;
      } catch (_) {}
      staticFlag = original.isStatic;
      final targetLocal = DateTime.fromMillisecondsSinceEpoch(
        original.targetAt,
        isUtc: true,
      ).toLocal();
      final service = ref.read(productServiceProvider);
      await repo.deleteChildrenOfParent(original.id);
      await repo.delete(original.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              try {
                if (service != null && productId != null && grams > 0) {
                  await service.createProductEntry(
                    productId: productId,
                    productGrams: grams,
                    targetAtLocal: targetLocal,
                    isStatic: staticFlag,
                  );
                } else {
                  await repo.create(
                    widgetKind: original.widgetKind,
                    targetAtLocal: targetLocal,
                    payload: parentPayload,
                    showInCalendar: original.showInCalendar,
                    schemaVersion: original.schemaVersion,
                  );
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } else if (isRecipe) {
      String recipeId = '';
      try {
        final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
        recipeId = (map['recipe_id'] as String?) ?? '';
      } catch (_) {}
      final targetLocal = DateTime.fromMillisecondsSinceEpoch(
        e.targetAt,
        isUtc: true,
      ).toLocal();

      // Delete recipe and its children
      await repo.deleteChildrenOfParent(e.id);
      await repo.delete(e.id);
      if (!context.mounted) return;
      final recipeSvc = ref.read(recipeServiceProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recipe deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              try {
                if (recipeSvc != null && recipeId.isNotEmpty) {
                  await recipeSvc.createRecipeEntry(
                    recipeId: recipeId,
                    targetAtLocal: targetLocal,
                    showParentInCalendar: true,
                  );
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } else {
      final original = e;
      await repo.delete(e.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Entry deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              final local = DateTime.fromMillisecondsSinceEpoch(
                original.targetAt,
                isUtc: true,
              ).toLocal();
              try {
                final payload = jsonDecode(original.payloadJson) as Map<String, Object?>;
                await repo.create(
                  widgetKind: original.widgetKind,
                  targetAtLocal: local,
                  payload: payload,
                  showInCalendar: original.showInCalendar,
                  schemaVersion: original.schemaVersion,
                );
              } catch (_) {}
            },
          ),
        ),
      );
    }
  }
}

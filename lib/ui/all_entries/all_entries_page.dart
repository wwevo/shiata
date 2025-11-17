import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/recipe_service.dart';
import '../../domain/widgets/registry.dart';
import '../../utils/formatters.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../editors/product_instance_editor_dialog.dart';
import '../editors/recipe_instance_dialog.dart';
import '../main_screen_providers.dart';

/// Page that displays all entries with search filtering.
class AllEntriesPage extends ConsumerWidget {
  const AllEntriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchService = ref.watch(searchServiceProvider);
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    if (searchService == null || repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Entries')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Entries'),
      ),
      body: StreamBuilder<List<EntryRecord>>(
        stream: searchService.searchAllEntries(searchQuery),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? <EntryRecord>[];

          if (searchQuery.trim().isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Type in the search field to find entries'),
              ),
            );
          }

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No entries found for "$searchQuery"',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (ctx, i) {
              final entry = entries[i];
              return _buildEntryCard(context, ref, entry, repo, registry);
            },
          );
        },
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context,
    WidgetRef ref,
    EntryRecord entry,
    EntriesRepository repo,
    WidgetRegistry registry,
  ) {
    final kind = registry.byId(entry.widgetKind);

    // Determine icon and color based on widget kind
    IconData icon;
    Color color;
    if (entry.widgetKind == 'product') {
      icon = Icons.shopping_basket;
      color = Colors.purple;
    } else if (entry.widgetKind == 'recipe') {
      icon = Icons.restaurant_menu;
      color = Colors.brown;
    } else {
      icon = kind?.icon ?? Icons.circle;
      color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
    }

    // Extract title and summary from payload
    String title = kind?.displayName ?? entry.widgetKind;
    String summary = '';
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;

      if (entry.widgetKind == 'product') {
        title = (map['name'] as String?) ?? 'Product';
        final grams = (map['grams'] as num?)?.toInt();
        if (grams != null) summary = '$grams g';
      } else if (entry.widgetKind == 'recipe') {
        title = (map['name'] as String?) ?? 'Recipe';
      } else {
        // For kinds, show amount
        final amount = (map['amount'] as num?)?.toDouble();
        if (amount != null) {
          final unit = kind?.unit ?? '';
          summary = amount < 1
              ? '${amount.toStringAsFixed(2)} $unit'
              : '${amount.toStringAsFixed(0)} $unit';
        }
      }
    } catch (_) {}

    final localTime = DateTime.fromMillisecondsSinceEpoch(
      entry.targetAt,
      isUtc: true,
    ).toLocal();

    final isProduct = entry.widgetKind == 'product';
    final isRecipe = entry.widgetKind == 'recipe';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text('$title${summary.isEmpty ? '' : ' • $summary'}'),
        subtitle: Row(
          children: [
            Text(
              '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}  ${fmtTime(localTime)}',
            ),
            if (entry.isStatic) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.lock,
                size: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                'Static',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
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
                    builder: (_) => ProductEditorDialog(entryId: entry.id),
                  );
                },
              )
            else if (isRecipe)
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => RecipeInstantiateDialog(entryId: entry.id),
                  );
                },
              )
            else
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  final k = registry.byId(entry.widgetKind);
                  if (k != null) {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          KindInstanceEditorDialog(kind: k, entryId: entry.id),
                    );
                  }
                },
              ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  _deleteEntry(context, ref, entry, isProduct, isRecipe, repo),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    EntryRecord entry,
    bool isProduct,
    bool isRecipe,
    EntriesRepository repo,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          isProduct
              ? 'This will remove the product entry and its components. You can undo from the snackbar.'
              : isRecipe
                  ? 'This will remove the recipe entry and its components. You can undo from the snackbar.'
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
      final original = entry;
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
      messenger.showSnackBar(
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
        final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
        recipeId = (map['recipe_id'] as String?) ?? '';
      } catch (_) {}
      final targetLocal = DateTime.fromMillisecondsSinceEpoch(
        entry.targetAt,
        isUtc: true,
      ).toLocal();

      await repo.deleteChildrenOfParent(entry.id);
      await repo.delete(entry.id);
      if (!context.mounted) return;
      final recipeSvc = ref.read(recipeServiceProvider);
      messenger.showSnackBar(
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
      final original = entry;
      await repo.delete(entry.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
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
                final payload =
                    jsonDecode(original.payloadJson) as Map<String, Object?>;
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

/// Centralized factory for creating consistent entry list items across all app sections.
///
/// This factory ensures that all entry types (kinds, products, recipes) are displayed
/// identically regardless of which page renders them (day details, weekly overview, search, etc.).
///
/// Benefits:
/// - Single source of truth for list item appearance
/// - Consistent metadata display (date, time, static flag)
/// - Easy maintenance and future customization
/// - Follows CLAUDE.md patterns (Card + ListTile + CircleAvatar)
library;

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

/// Configuration for metadata display in list items
class EntryListItemConfig {
  final bool showDate;
  final bool showTime;
  final bool showStaticFlag;
  final bool showHiddenIndicator;

  const EntryListItemConfig({
    this.showDate = true,
    this.showTime = true,
    this.showStaticFlag = true,
    this.showHiddenIndicator = false,
  });

  /// For day details: only time (date is implied by selected day)
  static const dayDetails = EntryListItemConfig(
    showDate: false,
    showTime: true,
  );

  /// For weekly overview, search results, and all entries: full date + time
  static const fullDateTime = EntryListItemConfig(
    showDate: true,
    showTime: true,
  );
}

class EntryListItemFactory {
  /// Builds a list item for a kind entry
  static Widget buildKindListItem({
    required BuildContext context,
    required WidgetRef ref,
    required EntryRecord entry,
    required WidgetRegistry registry,
    EntryListItemConfig config = const EntryListItemConfig(),
  }) {
    final kind = registry.byId(entry.widgetKind);
    final icon = kind?.icon ?? Icons.circle;
    final color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;

    // Extract amount from payload
    String summary = '';
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      final amount = (map['amount'] as num?)?.toDouble();
      if (amount != null) {
        final unit = kind?.unit ?? '';
        summary = amount < 1
            ? '${amount.toStringAsFixed(2)} $unit'
            : '${amount.toStringAsFixed(0)} $unit';
      }
    } catch (_) {}

    final metadata = _buildMetadata(entry, config, context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          foregroundColor: Colors.white,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text('${kind?.displayName ?? entry.widgetKind}${summary.isEmpty ? '' : ' • $summary'}'),
        subtitle: metadata != null ? metadata : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                if (kind != null) {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        KindInstanceEditorDialog(kind: kind, entryId: entry.id),
                  );
                }
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteEntry(context, ref, entry, false, false),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a list item for a product entry (with expand/collapse for children)
  static Widget buildProductListItem({
    required BuildContext context,
    required WidgetRef ref,
    required EntryRecord entry,
    required List<EntryRecord> children,
    EntryListItemConfig config = const EntryListItemConfig(),
  }) {
    // Extract name and grams from payload
    String title = 'Product';
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Product';
      final grams = (map['grams'] as num?)?.toInt();
      title = grams != null ? '$name • $grams g' : name;
    } catch (_) {}

    final metadata = _buildMetadata(entry, config, context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          child: Icon(Icons.shopping_basket, color: Colors.white),
        ),
        title: Text(title),
        subtitle: metadata,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => ProductEditorDialog(entryId: entry.id),
                );
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteEntry(context, ref, entry, true, false),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a list item for a recipe entry (with expand/collapse for children)
  static Widget buildRecipeListItem({
    required BuildContext context,
    required WidgetRef ref,
    required EntryRecord entry,
    required List<EntryRecord> children,
    required Map<String, List<EntryRecord>> childrenByParent,
    required WidgetRegistry registry,
    EntryListItemConfig config = const EntryListItemConfig(),
  }) {
    // Extract recipe name and build summary
    String title = 'Recipe';
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      title = (map['name'] as String?) ?? 'Recipe';
    } catch (_) {}

    final metadata = _buildMetadata(entry, config, context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.brown,
          foregroundColor: Colors.white,
          child: Icon(Icons.restaurant_menu, color: Colors.white),
        ),
        title: Text(title),
        subtitle: metadata,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (_) => RecipeInstantiateDialog(entryId: entry.id),
                );
              },
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteEntry(context, ref, entry, false, true),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds metadata row (date, time, static flag) based on configuration
  static Widget? _buildMetadata(
    EntryRecord entry,
    EntryListItemConfig config,
    BuildContext context,
  ) {
    final localTime = DateTime.fromMillisecondsSinceEpoch(
      entry.targetAt,
      isUtc: true,
    ).toLocal();

    final parts = <Widget>[];

    // Date and time
    if (config.showDate && config.showTime) {
      parts.add(Text(
        '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}  ${fmtTime(localTime)}',
      ));
    } else if (config.showTime) {
      parts.add(Text(fmtTime(localTime)));
    } else if (config.showDate) {
      parts.add(Text(
        '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}',
      ));
    }

    // Static flag
    if (config.showStaticFlag && entry.isStatic) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(width: 8));
      }
      parts.add(Icon(
        Icons.lock,
        size: 14,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ));
      parts.add(const SizedBox(width: 4));
      parts.add(Text(
        'Static',
        style: Theme.of(context).textTheme.labelSmall,
      ));
    }

    // Hidden indicator (for child entries)
    if (config.showHiddenIndicator && !entry.showInCalendar) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(width: 8));
      }
      parts.add(Text(
        'Hidden',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
      ));
    }

    return parts.isEmpty ? null : Row(children: parts);
  }

  /// Handles entry deletion with undo support
  static Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    EntryRecord entry,
    bool isProduct,
    bool isRecipe,
  ) async {
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) return;

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

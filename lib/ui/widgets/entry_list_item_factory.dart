/// Centralized recursive factory for creating consistent entry list items across all app sections.
///
/// This factory ensures that all entry types (kinds, products, recipes) are displayed
/// identically regardless of which page renders them (day details, weekly overview, search, etc.).
///
/// Key features:
/// - Recursive rendering: supports arbitrary nesting depth (recipe→product→kind, future: recipe→recipe)
/// - Expand/collapse: integrated expand state management via expandedEntriesProvider
/// - Consistent appearance: same visual style, metadata, and interactions everywhere
/// - Depth-aware: proper indentation and styling for nested items
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
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../editors/product_instance_components_editor_dialog.dart';
import '../editors/product_instance_editor_dialog.dart';
import '../editors/recipe_instance_dialog.dart';
import '../main_screen_providers.dart';

/// Configuration for metadata display in list items
class EntryListItemConfig {
  final bool showDate;
  final bool showTime;
  final bool showStaticFlag;

  const EntryListItemConfig({
    this.showDate = true,
    this.showTime = true,
    this.showStaticFlag = true,
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
  /// Recursively builds a list item for any entry type with support for
  /// arbitrary nesting depth and expand/collapse behavior.
  ///
  /// This single method handles:
  /// - Simple kinds (leaf nodes)
  /// - Products containing kinds (expandable)
  /// - Recipes containing products and/or kinds (expandable, with nested expansion)
  /// - Future: recipes containing recipes, products containing products, etc.
  ///
  /// Parameters:
  /// - [depth]: Current nesting level (0 = top-level, 1+ = nested)
  /// - [childrenByParent]: Map for looking up children of any entry
  /// - [config]: Controls which metadata to display (date, time, static flag)
  static Widget buildEntry({
    required BuildContext context,
    required WidgetRef ref,
    required EntryRecord entry,
    required Map<String, List<EntryRecord>> childrenByParent,
    required WidgetRegistry registry,
    EntryListItemConfig config = const EntryListItemConfig(),
    int depth = 0,
  }) {
    final children = childrenByParent[entry.id] ?? [];
    final hasChildren = children.isNotEmpty;

    // Extract entry-specific data
    final isProduct = entry.widgetKind == 'product';
    final isRecipe = entry.widgetKind == 'recipe';

    // Determine color, icon, and title
    final Color color;
    final IconData icon;
    final String title;

    if (isProduct) {
      color = Colors.purple;
      icon = Icons.shopping_basket;
      title = _extractProductTitle(entry);
    } else if (isRecipe) {
      color = Colors.brown;
      icon = Icons.restaurant_menu;
      title = _extractRecipeTitle(entry, children, childrenByParent, registry);
    } else {
      final kind = registry.byId(entry.widgetKind);
      color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
      icon = kind?.icon ?? Icons.circle;
      // For nested entries (depth > 0), only show display name without amount
      // For top-level entries (depth == 0), show display name with amount
      title = _extractKindTitle(entry, kind, depth);
    }

    final metadata = depth == 0 ? _buildMetadata(entry, config, context) : null;

    // Check expand state
    final expandedSet = ref.watch(expandedEntriesProvider);
    final isExpanded = expandedSet.contains(entry.id);

    // Build trailing widget based on depth and entry type
    final Widget? trailing;
    if (depth > 0) {
      // Nested entries: show amount for kinds
      trailing = _buildKindAmount(entry, registry, context);
    } else {
      // Top-level entries: show action buttons
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit button (for all entry types)
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context, entry, isProduct, isRecipe, registry),
          ),
          // Delete button (for all entry types)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteEntry(context, ref, entry, isProduct, isRecipe),
          ),
          // Edit components button (only for products)
          if (isProduct)
            IconButton(
              tooltip: 'Edit components',
              icon: const Icon(Icons.tune),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => InstanceComponentsEditorDialog(parentEntryId: entry.id),
              ),
            ),
          // Expand/collapse icon (if has children) or chevron (if no children)
          if (hasChildren)
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: const Icon(Icons.expand_more),
            )
          else
            const Icon(Icons.chevron_right),
        ],
      );
    }

    // Build the list tile
    final listTile = ListTile(
      dense: depth > 0,
      contentPadding: EdgeInsets.only(
        left: depth > 0 ? 0 : 12,
        right: depth > 0 ? 0 : 12,
      ),
      onTap: hasChildren
          ? () {
              final set = {...expandedSet};
              if (isExpanded) {
                set.remove(entry.id);
              } else {
                set.add(entry.id);
              }
              ref.read(expandedEntriesProvider.notifier).state = set;
            }
          : null,
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: Icon(icon, color: Colors.white, size: depth > 0 ? 16 : null),
      ),
      title: Text(title),
      subtitle: metadata,
      trailing: trailing,
    );

    // If no children, return simple item
    if (!hasChildren) {
      return depth == 0
          ? Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: listTile,
            )
          : listTile;
    }

    // If has children, return expandable item with recursive children
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        listTile,
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 8, bottom: 8),
            child: Column(
              children: children
                  .map((child) => buildEntry(
                        context: context,
                        ref: ref,
                        entry: child,
                        childrenByParent: childrenByParent,
                        registry: registry,
                        config: config,
                        depth: depth + 1,
                      ))
                  .toList(),
            ),
          ),
      ],
    );

    return depth == 0
        ? Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: content,
          )
        : content;
  }

  /// Extracts product title from payload (name • grams g)
  static String _extractProductTitle(EntryRecord entry) {
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Product';
      final grams = (map['grams'] as num?)?.toInt();
      return grams != null ? '$name • $grams g' : name;
    } catch (_) {
      return 'Product';
    }
  }

  /// Extracts recipe title from payload
  static String _extractRecipeTitle(
    EntryRecord entry,
    List<EntryRecord> children,
    Map<String, List<EntryRecord>> childrenByParent,
    WidgetRegistry registry,
  ) {
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Recipe';

      // Sum up component weights recursively
      double totalProductGrams = 0.0;
      final kindSummaries = <String, double>{};

      // Recursive helper to aggregate nutrients from nested products
      void aggregateNutrients(List<EntryRecord> entries) {
        for (final child in entries) {
          if (child.widgetKind == 'product') {
            try {
              final childMap = jsonDecode(child.payloadJson) as Map<String, dynamic>;
              final grams = (childMap['grams'] as num?)?.toDouble() ?? 0.0;
              totalProductGrams += grams;
            } catch (_) {}
            // Recursively aggregate nutrients from this product's children
            final grandchildren = childrenByParent[child.id] ?? const <EntryRecord>[];
            aggregateNutrients(grandchildren);
          } else {
            // It's a kind - aggregate by kind
            try {
              final childMap = jsonDecode(child.payloadJson) as Map<String, dynamic>;
              final amount = (childMap['amount'] as num?)?.toDouble() ?? 0.0;
              kindSummaries[child.widgetKind] = (kindSummaries[child.widgetKind] ?? 0.0) + amount;
            } catch (_) {}
          }
        }
      }

      aggregateNutrients(children);

      // Build summary string
      final parts = <String>[];
      if (totalProductGrams > 0) {
        final formatted = totalProductGrams < 1
            ? totalProductGrams.toStringAsFixed(2)
            : totalProductGrams.toStringAsFixed(0);
        parts.add('${formatted}g');
      }

      // Add top kind amounts (limit to avoid clutter)
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
            case 'µg':
              normalized = entry.value / 1000000;
              break;
            default:
              normalized = entry.value;
          }
          normalizedForSort[entry.key] = normalized;
        }

        // Sort by normalized amount descending
        final sorted = normalizedForSort.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Show top 2 kinds
        for (int i = 0; i < sorted.length && i < 2; i++) {
          final kindId = sorted[i].key;
          final kind = registry.byId(kindId);
          final rawAmount = kindSummaries[kindId]!;
          final unit = kind?.unit ?? '';

          final formatted = rawAmount < 1
              ? rawAmount.toStringAsFixed(2)
              : rawAmount.toStringAsFixed(0);
          final kindLabel = kind?.displayName ?? kindId;
          parts.add('$formatted$unit $kindLabel');
        }
      }

      return parts.isEmpty ? name : '$name • ${parts.join(' • ')}';
    } catch (_) {
      return 'Recipe';
    }
  }

  /// Extracts kind title with amount (displayName • amount unit)
  /// For nested entries (depth > 0), only returns displayName (amount shown in trailing)
  static String _extractKindTitle(EntryRecord entry, WidgetKind? kind, int depth) {
    final displayName = kind?.displayName ?? entry.widgetKind;

    // Nested entries show amount in trailing, not in title
    if (depth > 0) {
      return displayName;
    }

    // Top-level entries show amount in title
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

    return summary.isEmpty ? displayName : '$displayName • $summary';
  }

  /// Builds amount widget for nested kind entries (shown in trailing)
  static Widget? _buildKindAmount(EntryRecord entry, WidgetRegistry registry, BuildContext context) {
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      double? amount = (map['amount'] as num?)?.toDouble();
      final unitFromPayload = map['unit'] as String?;

      if (amount == null) return Text('—', style: Theme.of(context).textTheme.bodyMedium);

      final kind = registry.byId(entry.widgetKind);
      final unit = unitFromPayload ?? kind?.unit ?? '';

      String text;
      if (amount < 1) {
        text = amount.toStringAsFixed(2);
        // Only trim zeros after decimal point: "0.30" → "0.3", but keep "30" as "30"
        if (text.contains('.')) {
          text = text.replaceFirst(RegExp(r'0+$'), ''); // Remove trailing zeros
          text = text.replaceFirst(RegExp(r'\.$'), '');  // Remove trailing decimal point
        }
      } else {
        // For amounts >= 1, show as integer: "30.0" → "30"
        text = amount.toStringAsFixed(0);
      }
      final value = unit.isEmpty ? text : '$text $unit';

      return Text(value, style: Theme.of(context).textTheme.bodyMedium);
    } catch (_) {
      return Text('—', style: Theme.of(context).textTheme.bodyMedium);
    }
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

    return parts.isEmpty ? null : Row(children: parts);
  }

  /// Shows appropriate edit dialog based on entry type
  static void _showEditDialog(
    BuildContext context,
    EntryRecord entry,
    bool isProduct,
    bool isRecipe,
    WidgetRegistry registry,
  ) {
    if (isProduct) {
      showDialog(
        context: context,
        builder: (_) => ProductEditorDialog(entryId: entry.id),
      );
    } else if (isRecipe) {
      showDialog(
        context: context,
        builder: (_) => RecipeInstantiateDialog(entryId: entry.id),
      );
    } else {
      final kind = registry.byId(entry.widgetKind);
      if (kind != null) {
        showDialog(
          context: context,
          builder: (_) => KindInstanceEditorDialog(kind: kind, entryId: entry.id),
        );
      }
    }
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

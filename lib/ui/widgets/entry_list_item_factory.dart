/// Centralized recursive factory for creating consistent entry list items across all app sections.
///
/// This factory ensures that all entry types (kinds, products, recipes) are displayed
/// identically regardless of which page renders them (day details, weekly overview, etc.).
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
import '../../data/repo/kind_service.dart';
import '../../data/repo/kinds_repository.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipe_service.dart';
import '../../data/repo/recipes_repository.dart';
import '../../domain/widgets/registry.dart';
import '../../domain/widgets/widget_kind.dart';
import '../../utils/formatters.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../editors/kind_template_editor_dialog.dart';
import '../editors/product_instance_components_editor_dialog.dart';
import '../editors/product_instance_editor_dialog.dart';
import '../editors/product_template_editor_dialog.dart';
import '../editors/recipe_instance_dialog.dart';
import '../editors/recipe_template_editor_dialog.dart';
import '../main_screen_providers.dart';

/// Display mode for entry list items
enum EntryDisplayMode {
  /// Normal mode: shows edit/delete buttons, full interactivity
  normal,

  /// Checkbox mode: shows checkbox for selection, expand works but no edit/delete
  checkbox,

  /// Selection mode: shows both checkboxes and actions
  selection,
}

/// Represents a component within a template (Product or Recipe)
class ComponentItem {
  final dynamic definition; // KindDef or ProductDef
  final double? amount;
  final String? unit;

  ComponentItem({
    required this.definition,
    this.amount,
    this.unit,
  });
}

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

  /// For weekly overview and all entries: full date + time
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
  /// - [displayMode]: normal (edit/delete buttons) or checkbox (selection mode)
  /// - [selectedIds]: Set of selected entry IDs (only for checkbox mode)
  /// - [onSelectionChanged]: Callback when checkbox state changes (only for checkbox mode)
  static Widget buildEntry({
    required BuildContext context,
    required WidgetRef ref,
    required dynamic entry, // EntryRecord, KindDef, ProductDef, RecipeDef, or ComponentItem
    required Map<String, List> childrenByParent,
    required WidgetRegistry registry,
    EntryListItemConfig config = const EntryListItemConfig(),
    int depth = 0,
    EntryDisplayMode displayMode = EntryDisplayMode.normal,
    void Function(dynamic entry, bool selected)? onSelectionChanged,
  }) {
    final dynamic realEntry = entry is ComponentItem ? entry.definition : entry;
    final String entryId = _getEntryId(realEntry);
    final children = childrenByParent[entryId] ?? [];
    final hasChildren = children.isNotEmpty;

    // Determine type
    final isProduct = realEntry is ProductDef || (realEntry is EntryRecord && realEntry.widgetKind == 'product');
    final isRecipe = realEntry is RecipeDef || (realEntry is EntryRecord && realEntry.widgetKind == 'recipe');
    final isKind = realEntry is KindDef || (realEntry is EntryRecord && realEntry.widgetKind != 'product' && realEntry.widgetKind != 'recipe');

    // Determine color, icon, and title
    final Color color;
    final IconData icon;
    final String title;

    if (isProduct) {
      color = _getEntryColor(realEntry, Colors.purple);
      icon = _getEntryIcon(realEntry, Icons.shopping_basket);
      title = _extractProductTitle(realEntry);
    } else if (isRecipe) {
      color = _getEntryColor(realEntry, Colors.brown);
      icon = _getEntryIcon(realEntry, Icons.restaurant_menu);
      title = _extractRecipeTitle(realEntry, children, childrenByParent, registry);
    } else {
      final kindId = _getEntryKindId(realEntry);
      final kind = registry.byId(kindId);
      color = _getEntryColor(realEntry, kind?.accentColor ?? Theme.of(context).colorScheme.primary);
      icon = _getEntryIcon(realEntry, kind?.icon ?? Icons.circle);
      title = _extractKindTitle(realEntry, kind, depth, registry);
    }

    final metadata = (depth == 0 && realEntry is EntryRecord) ? _buildMetadata(realEntry, config, context) : null;
    final subtitle = realEntry is KindDef ? _buildKindDefSubtitle(realEntry) : metadata;

    // Check expand state
    final expandedSet = ref.watch(expandedEntriesProvider);
    final isExpanded = expandedSet.contains(entryId);

    // Selection state
    final isSelectionMode = ref.watch(selectionModeProvider);
    final selectedIds = ref.watch(bulkSelectionProvider);
    final isSelected = selectedIds.containsKey(entryId);
    final effectiveDisplayMode =
        isSelectionMode ? EntryDisplayMode.selection : displayMode;

    // Build trailing widget
    final List<Widget> trailingActions = [];

    if (effectiveDisplayMode == EntryDisplayMode.checkbox ||
        effectiveDisplayMode == EntryDisplayMode.selection) {
      if (depth == 0 || effectiveDisplayMode == EntryDisplayMode.checkbox) {
        trailingActions.add(
          Checkbox(
            value: isSelected,
            onChanged: (val) {
              if (onSelectionChanged != null) {
                onSelectionChanged(realEntry, val ?? false);
              } else {
                final newSelected = {...selectedIds};
                if (val == true) {
                  newSelected[entryId] = _getEntryCategory(realEntry);
                } else {
                  newSelected.remove(entryId);
                }
                ref.read(bulkSelectionProvider.notifier).state = newSelected;
                if (newSelected.isEmpty) {
                  ref.read(selectionModeProvider.notifier).state = false;
                } else {
                  ref.read(selectionModeProvider.notifier).state = true;
                }
              }
            },
          ),
        );
      }
    }

    if (effectiveDisplayMode == EntryDisplayMode.normal || effectiveDisplayMode == EntryDisplayMode.selection) {
      if (depth == 0) {
        // Edit button
        trailingActions.add(
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context, entry, isProduct, isRecipe, registry),
          ),
        );
        // Delete button
        trailingActions.add(
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteEntry(context, ref, entry, isProduct, isRecipe),
          ),
        );
        // Edit components button (only for product instances)
        if (isProduct && entry is EntryRecord) {
          trailingActions.add(
            IconButton(
              tooltip: 'Edit components',
              icon: const Icon(Icons.tune),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => InstanceComponentsEditorDialog(parentEntryId: entry.id),
              ),
            ),
          );
        }
      } else if (realEntry is EntryRecord && isKind) {
        // Nested kind instances show amount
        trailingActions.add(_buildKindAmount(realEntry, registry, context));
      } else if (entry is ComponentItem) {
        // Template components show amount
        final text = entry.amount != null
            ? (entry.amount! < 1
                ? entry.amount!.toStringAsFixed(2)
                : entry.amount!.toStringAsFixed(0))
            : '—';
        final unit = entry.unit ?? '';
        trailingActions.add(
          Text(
            unit.isEmpty ? text : '$text $unit',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      }
    }

    // Expand/collapse icon
    if (hasChildren) {
      trailingActions.add(
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: isExpanded ? 'Collapse' : 'Expand',
          onPressed: () {
            final set = {...expandedSet};
            if (isExpanded) {
              set.remove(entryId);
            } else {
              set.add(entryId);
            }
            ref.read(expandedEntriesProvider.notifier).state = set;
          },
          icon: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 120),
            child: const Icon(Icons.expand_more),
          ),
        ),
      );
    } else if (depth == 0 && effectiveDisplayMode != EntryDisplayMode.checkbox) {
      trailingActions.add(const Icon(Icons.chevron_right));
    }

    final listTile = StandardListItem(
      isNested: depth > 0,
      isSelected: isSelected,
      onTap: hasChildren
          ? () {
              final set = {...expandedSet};
              if (isExpanded) {
                set.remove(entryId);
              } else {
                _expandRecursively(entryId, childrenByParent, set);
              }
              ref.read(expandedEntriesProvider.notifier).state = set;
            }
          : (effectiveDisplayMode == EntryDisplayMode.selection ||
                  effectiveDisplayMode == EntryDisplayMode.checkbox
              ? () {
                  if (onSelectionChanged != null) {
                    onSelectionChanged(realEntry, !isSelected);
                  } else {
                    final newSelected = {...selectedIds};
                    if (isSelected) {
                      newSelected.remove(entryId);
                    } else {
                      newSelected[entryId] = _getEntryCategory(realEntry);
                    }
                    ref.read(bulkSelectionProvider.notifier).state = newSelected;
                    if (newSelected.isEmpty) {
                      ref.read(selectionModeProvider.notifier).state = false;
                    }
                  }
                }
              : null),
      onLongPress: depth == 0
          ? () {
              ref.read(selectionModeProvider.notifier).state = true;
              final newSelected = {...selectedIds};
              newSelected[entryId] = _getEntryCategory(realEntry);
              ref.read(bulkSelectionProvider.notifier).state = newSelected;
            }
          : null,
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: Icon(icon, color: Colors.white, size: depth > 0 ? 16 : null),
      ),
      title: Text(title, style: depth > 0 ? Theme.of(context).textTheme.bodyMedium : null),
      subtitle: subtitle,
      trailing: trailingActions.isEmpty ? null : Row(
        mainAxisSize: MainAxisSize.min,
        children: trailingActions,
      ),
    );

    // Recursive children
    if (!hasChildren) {
      return listTile;
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        listTile,
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 8, bottom: 8),
            child: Column(
              children: children
                  .map(
                    (child) => buildEntry(
                      context: context,
                      ref: ref,
                      entry: child,
                      childrenByParent: childrenByParent,
                      registry: registry,
                      config: config,
                      depth: depth + 1,
                      displayMode: displayMode,
                      onSelectionChanged: onSelectionChanged,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );

    return content;
  }

  static String _getEntryId(dynamic entry) {
    if (entry is EntryRecord) return entry.id;
    if (entry is KindDef) return entry.id;
    if (entry is ProductDef) return entry.id;
    if (entry is RecipeDef) return entry.id;
    return '';
  }

  /// Recursively expands all entries in the hierarchy
  static void _expandRecursively(
    String id,
    Map<String, List> childrenByParent,
    Set<String> expandedSet,
  ) {
    expandedSet.add(id);
    final children = childrenByParent[id] ?? [];
    for (final child in children) {
      final realChild = child is ComponentItem ? child.definition : child;
      final childId = _getEntryId(realChild);
      if (childId.isNotEmpty) {
        _expandRecursively(childId, childrenByParent, expandedSet);
      }
    }
  }

  static SelectionCategory _getEntryCategory(dynamic entry) {
    final dynamic realEntry = entry is ComponentItem ? entry.definition : entry;
    if (realEntry is EntryRecord) return SelectionCategory.entries;
    if (realEntry is KindDef) return SelectionCategory.kinds;
    if (realEntry is ProductDef) return SelectionCategory.products;
    if (realEntry is RecipeDef) return SelectionCategory.recipes;
    return SelectionCategory.entries;
  }

  static String _getEntryKindId(dynamic entry) {
    if (entry is EntryRecord) return entry.widgetKind;
    if (entry is KindDef) return entry.id;
    return '';
  }

  static Color _getEntryColor(dynamic entry, Color defaultColor) {
    if (entry is KindDef) return entry.color != null ? Color(entry.color!) : defaultColor;
    if (entry is ProductDef) return entry.color != null ? Color(entry.color!) : defaultColor;
    if (entry is RecipeDef) return entry.color != null ? Color(entry.color!) : defaultColor;
    return defaultColor;
  }

  static IconData _getEntryIcon(dynamic entry, IconData defaultIcon) {
    if (entry is KindDef) return resolveIcon(entry.icon, defaultIcon);
    if (entry is ProductDef) return resolveIcon(entry.icon, defaultIcon);
    if (entry is RecipeDef) return resolveIcon(entry.icon, defaultIcon);
    return defaultIcon;
  }

  static Widget _buildKindDefSubtitle(KindDef k) {
    return Text(
      '${k.unit}  •  min ${k.min}  •  max ${k.max}${k.defaultShowInCalendar ? '  •  calendar' : ''}',
    );
  }

  /// Extracts product title from payload or definition
  static String _extractProductTitle(dynamic entry) {
    if (entry is ProductDef) return entry.name;
    if (entry is EntryRecord) {
      try {
        final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
        final name = (map['name'] as String?) ?? 'Product';
        final grams = (map['grams'] as num?)?.toInt();
        return grams != null ? '$name • $grams g' : name;
      } catch (_) {
        return 'Product';
      }
    }
    return 'Product';
  }

  /// Extracts recipe title from payload or definition
  static String _extractRecipeTitle(
    dynamic entry,
    List<dynamic> children,
    Map<String, List<dynamic>> childrenByParent,
    WidgetRegistry registry,
  ) {
    if (entry is RecipeDef) return entry.name;
    if (entry is! EntryRecord) return 'Recipe';

    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Recipe';

      // Sum up component weights recursively
      double totalProductGrams = 0.0;
      final kindSummaries = <String, double>{};

      // Recursive helper to aggregate kinds from nested products
      void aggregateKinds(List<dynamic> entries) {
        for (final child in entries) {
          if (child is! EntryRecord) continue;
          if (child.widgetKind == 'product') {
            try {
              final childMap =
                  jsonDecode(child.payloadJson) as Map<String, dynamic>;
              final grams = (childMap['grams'] as num?)?.toDouble() ?? 0.0;
              totalProductGrams += grams;
            } catch (_) {}
            // Recursively aggregate kinds from this product's children
            final grandchildren =
                childrenByParent[child.id] ?? const <EntryRecord>[];
            aggregateKinds(grandchildren);
          } else {
            // It's a kind - aggregate by kind
            try {
              final childMap =
                  jsonDecode(child.payloadJson) as Map<String, dynamic>;
              final amount = (childMap['amount'] as num?)?.toDouble() ?? 0.0;
              kindSummaries[child.widgetKind] =
                  (kindSummaries[child.widgetKind] ?? 0.0) + amount;
            } catch (_) {}
          }
        }
      }

      aggregateKinds(children);
      // ... same summary logic as before ...

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
  static String _extractKindTitle(
    dynamic entry,
    WidgetKind? kind,
    int depth,
    WidgetRegistry registry,
  ) {
    if (entry is KindDef) return entry.name;
    if (entry is! EntryRecord) return 'Kind';

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
  static Widget _buildKindAmount(
    EntryRecord entry,
    WidgetRegistry registry,
    BuildContext context,
  ) {
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      double? amount = (map['amount'] as num?)?.toDouble();
      final unitFromPayload = map['unit'] as String?;

      if (amount == null) {
        return Text('—', style: Theme.of(context).textTheme.bodyMedium);
      }

      final kind = registry.byId(entry.widgetKind);
      final unit = unitFromPayload ?? kind?.unit ?? '';

      String text;
      if (amount < 1) {
        text = amount.toStringAsFixed(2);
        // Only trim zeros after decimal point: "0.30" → "0.3", but keep "30" as "30"
        if (text.contains('.')) {
          text = text.replaceFirst(RegExp(r'0+$'), ''); // Remove trailing zeros
          text = text.replaceFirst(
            RegExp(r'\.$'),
            '',
          ); // Remove trailing decimal point
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
      parts.add(
        Text(
          '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}  ${fmtTime(localTime)}',
        ),
      );
    } else if (config.showTime) {
      parts.add(Text(fmtTime(localTime)));
    } else if (config.showDate) {
      parts.add(
        Text(
          '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}',
        ),
      );
    }

    // Static flag
    if (config.showStaticFlag && entry.isStatic) {
      if (parts.isNotEmpty) {
        parts.add(const SizedBox(width: 8));
      }
      parts.add(
        Icon(
          Icons.lock,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
      parts.add(const SizedBox(width: 4));
      parts.add(Text('Static', style: Theme.of(context).textTheme.labelSmall));
    }

    return parts.isEmpty ? null : Row(children: parts);
  }

  /// Shows appropriate edit dialog based on entry type
  static void _showEditDialog(
    BuildContext context,
    dynamic entry,
    bool isProduct,
    bool isRecipe,
    WidgetRegistry registry,
  ) {
    if (entry is EntryRecord) {
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
            builder: (_) =>
                KindInstanceEditorDialog(kind: kind, entryId: entry.id),
          );
        }
      }
    } else if (entry is ProductDef) {
      showDialog(
        context: context,
        builder: (_) => ProductTemplateEditorDialog(existing: entry),
      );
    } else if (entry is RecipeDef) {
      showDialog(
        context: context,
        builder: (_) => RecipeEditorDialog(existing: entry),
      );
    } else if (entry is KindDef) {
      showDialog(
        context: context,
        builder: (_) => KindTemplateEditorDialog(existing: entry),
      );
    }
  }

  /// Handles entry deletion
  static Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    dynamic entry,
    bool isProduct,
    bool isRecipe,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    if (entry is EntryRecord) {
      final repo = ref.read(entriesRepositoryProvider);
      if (repo == null) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete entry?'),
          content: Text(
            isProduct
                ? 'This will remove the product entry and its components.'
                : isRecipe
                ? 'This will remove the recipe entry and its components.'
                : 'This will remove the entry.',
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

      if (isProduct || isRecipe) {
        await repo.deleteChildrenOfParent(entry.id);
      }
      await repo.delete(entry.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${isProduct ? 'Product' : isRecipe ? 'Recipe' : 'Entry'} deleted')),
      );
    } else if (entry is ProductDef) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete product?'),
          content: const Text('Instances will be converted: parent rows removed, kind entries kept.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
          ],
        ),
      );
      if (confirm != true) return;
      final svc = ref.read(productServiceProvider);
      await svc?.deleteProductTemplate(entry.id);
      messenger.showSnackBar(SnackBar(content: Text('Deleted ${entry.name}; instances converted')));
    } else if (entry is RecipeDef) {
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
      );
      if (confirm != true) return;
      final svc = ref.read(recipeServiceProvider);
      final repo = ref.read(recipesRepositoryProvider);
      if (svc != null && repo != null) {
        await svc.deleteRecipeTemplate(entry.id);
        await repo.deleteRecipe(entry.id);
        messenger.showSnackBar(const SnackBar(content: Text('Recipe deleted')));
      }
    } else if (entry is KindDef) {
      final svc = ref.read(kindServiceProvider);
      if (svc == null) return;
      final usage = await svc.getUsage(entry.id);
      if (usage == null) return;
      if (!context.mounted) return;

      bool removeFromProducts = usage.productsUsing.isNotEmpty;
      bool deleteDirectEntries = usage.directEntriesCount > 0;

      final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) {
              return StatefulBuilder(
                builder: (ctx, setState) {
                  return AlertDialog(
                    title: const Text('Delete kind'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('"${entry.name}"'),
                        const SizedBox(height: 8),
                        if (usage.productsUsing.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Used by ${usage.productsUsing.length} product(s): ${usage.productsUsing.map((p) => p.name).join(', ')}',
                            ),
                          ),
                        if (usage.directEntriesCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${usage.directEntriesCount} direct calendar instance(s)',
                            ),
                          ),
                        if (usage.productsUsing.isEmpty && usage.directEntriesCount == 0)
                          const Text('This kind is not used.'),
                        const Divider(),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Remove from product templates and update existing entries'),
                          value: removeFromProducts,
                          onChanged: (v) => setState(() => removeFromProducts = v ?? false),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Delete direct calendar instances of this kind'),
                          value: deleteDirectEntries,
                          onChanged: (v) => setState(() => deleteDirectEntries = v ?? false),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      FilledButton(
                        onPressed: ((usage.productsUsing.isNotEmpty || usage.directEntriesCount > 0) &&
                                !(removeFromProducts || deleteDirectEntries))
                            ? null
                            : () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );
            },
          ) ??
          false;

      if (!confirmed) return;
      try {
        await svc.deleteKindWithSideEffects(
          kindId: entry.id,
          removeFromProducts: removeFromProducts,
          deleteDirectEntries: deleteDirectEntries,
        );
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Deleted ${entry.name}')));
      } catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Could not delete kind: ${e.toString()}')));
      }
    }
  }
}

/// A standardized list item widget that follows the application's visual style.
/// It uses a Card + ListTile pattern for top-level items and a plain ListTile for nested items.
class StandardListItem extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isNested;
  final bool isSelected;
  final Color? tileColor;

  const StandardListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.isNested = false,
    this.isSelected = false,
    this.tileColor,
  });

  @override
  Widget build(BuildContext context) {
    final listTile = ListTile(
      dense: isNested,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isNested ? 0 : 12,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      selected: isSelected,
      tileColor: tileColor,
    );

    if (isNested) {
      return listTile;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: listTile,
    );
  }
}

/// Resolves icon names to IconData.
/// Used across all pages for consistent icon handling.
IconData resolveIcon(String? name, IconData fallback) {
  switch (name) {
    case 'fitness_center':
      return Icons.fitness_center;
    case 'opacity':
      return Icons.opacity;
    case 'rice_bowl':
      return Icons.rice_bowl;
    case 'battery_charging_full':
      return Icons.battery_charging_full;
    case 'blur_on':
      return Icons.blur_on;
    case 'bolt':
      return Icons.bolt;
    case 'circle':
      return Icons.circle;
    case 'hexagon':
      return Icons.hexagon;
    case 'science':
      return Icons.science;
    case 'visibility':
      return Icons.visibility;
    case 'medical_information':
      return Icons.medical_information;
    case 'local_florist':
      return Icons.local_florist;
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'eco':
      return Icons.eco;
    case 'grass':
      return Icons.grass;
    default:
      return fallback;
  }
}

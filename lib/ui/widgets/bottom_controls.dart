import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kind_service.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/recipe_service.dart';
import '../../navigation/nav_models.dart';
import '../../navigation/nav_registry.dart';
import '../main_screen_providers.dart';

class BottomControls extends ConsumerStatefulWidget {
  const BottomControls({super.key});

  @override
  ConsumerState<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends ConsumerState<BottomControls> {
  final Map<String, MenuController> _menuControllers = {};

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = ref.watch(selectionModeProvider);
    if (isSelectionMode) {
      return const BulkActionsToolbar();
    }

    final registry = ref.watch(navRegistryProvider);
    final activeId = ref.watch(currentSectionIdProvider);
    final selectedIndex = registry.findTopLevelIndex(activeId);

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index < 0 || index >= registry.items.length) return;
        final item = registry.items[index];
        if (item is NavPageItem) {
          ref.read(currentSectionIdProvider.notifier).state = item.id;
        } else if (item is NavActionItem) {
          item.onTrigger(context, ref);
        } else if (item is NavGroupItem) {
          final controller =
              _menuControllers.putIfAbsent(item.id, () => MenuController());
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }
      },
      destinations: registry.items.map((item) {
        if (item is NavGroupItem) {
          final controller =
              _menuControllers.putIfAbsent(item.id, () => MenuController());
          final hasActiveChild = _hasActiveChild(item, activeId);

          return NavigationDestination(
            icon: MenuAnchor(
              controller: controller,
              menuChildren: item.children
                  .map((child) =>
                      _buildMenuItem(context, ref, child, activeId))
                  .toList(),
              child: Icon(
                hasActiveChild && item.selectedIcon != null
                    ? item.selectedIcon!
                    : item.icon,
              ),
            ),
            label: item.label,
          );
        }

        return NavigationDestination(
          icon: Icon(item.icon),
          selectedIcon:
              item.selectedIcon != null ? Icon(item.selectedIcon!) : null,
          label: item.label,
        );
      }).toList(),
    );
  }

  bool _hasActiveChild(NavGroupItem group, String activeId) {
    for (final child in group.children) {
      if (child.id == activeId) return true;
      if (child is NavGroupItem && _hasActiveChild(child, activeId)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildMenuItem(
    BuildContext context,
    WidgetRef ref,
    NavItem item,
    String activeId,
  ) {
    if (item is NavGroupItem) {
      return SubmenuButton(
        leadingIcon: Icon(item.icon),
        menuChildren: item.children
            .map((child) => _buildMenuItem(context, ref, child, activeId))
            .toList(),
        child: Text(item.label),
      );
    }

    final isSelected = item.id == activeId;
    return MenuItemButton(
      leadingIcon: Icon(
        item.icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      trailingIcon: isSelected
          ? Icon(
              Icons.check,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onPressed: () {
        if (item is NavPageItem) {
          ref.read(currentSectionIdProvider.notifier).state = item.id;
        } else if (item is NavActionItem) {
          item.onTrigger(context, ref);
        }
      },
      child: Text(item.label),
    );
  }
}

class BulkActionsToolbar extends ConsumerWidget {
  const BulkActionsToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelectionMode = ref.watch(selectionModeProvider);
    final selectedIds = ref.watch(bulkSelectionProvider);
    final activeCategory = ref.watch(activeCategoryProvider);

    if (!isSelectionMode) return const SizedBox.shrink();

    final totalCount = selectedIds.length;
    final categories = selectedIds.values.toSet();
    final pageCount = categories.length;

    String statusText = '$totalCount selected';
    if (pageCount > 1) {
      statusText = '$totalCount selected across $pageCount pages';
    }

    return Material(
      elevation: 8,
      child: Container(
        height: Theme.of(context).appBarTheme.toolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
              crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      statusText,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                ]
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pageCount > 1)
                    TextButton(
                      onPressed: () {
                        final newSelected = Map<String, SelectionCategory>.fromEntries(
                          selectedIds.entries.where((e) => e.value == activeCategory),
                        );
                        ref.read(bulkSelectionProvider.notifier).state = newSelected;
                        if (newSelected.isEmpty) {
                          ref.read(selectionModeProvider.notifier).state = false;
                        }
                      },
                      child: const Text('Keep current page only'),
                    ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    onPressed: () {
                      ref.read(selectionModeProvider.notifier).state = false;
                      ref.read(bulkSelectionProvider.notifier).state = {};
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    onPressed: totalCount == 0
                        ? null
                        : () => _handleBulkDelete(context, ref, selectedIds),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBulkDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, SelectionCategory> selectedIds,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ids = selectedIds.keys.toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${ids.length} items?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Group by category for efficient deletion
      final trackingIds = selectedIds.entries
          .where((e) => e.value == SelectionCategory.entries)
          .map((e) => e.key)
          .toList();
      final kindIds = selectedIds.entries
          .where((e) => e.value == SelectionCategory.kinds)
          .map((e) => e.key)
          .toList();
      final productIds = selectedIds.entries
          .where((e) => e.value == SelectionCategory.products)
          .map((e) => e.key)
          .toList();
      final recipeIds = selectedIds.entries
          .where((e) => e.value == SelectionCategory.recipes)
          .map((e) => e.key)
          .toList();

      // Delete entries/instances
      if (trackingIds.isNotEmpty) {
        final repo = ref.read(entriesRepositoryProvider);
        if (repo != null) {
          for (final id in trackingIds) {
            await repo.deleteChildrenOfParent(id);
            await repo.delete(id);
          }
        }
      }

      // Delete kind templates
      if (kindIds.isNotEmpty) {
        final svc = ref.read(kindServiceProvider);
        if (svc != null) {
          for (final id in kindIds) {
            await svc.deleteKindWithSideEffects(
              kindId: id,
              removeFromProducts: true,
              deleteDirectEntries: true,
            );
          }
        }
      }

      // Delete product templates
      if (productIds.isNotEmpty) {
        final svc = ref.read(productServiceProvider);
        if (svc != null) {
          for (final id in productIds) {
            await svc.deleteProductTemplate(id);
          }
        }
      }

      // Delete recipe templates
      if (recipeIds.isNotEmpty) {
        final svc = ref.read(recipeServiceProvider);
        final repo = ref.read(recipesRepositoryProvider);
        if (svc != null && repo != null) {
          for (final id in recipeIds) {
            await svc.deleteRecipeTemplate(id);
            await repo.deleteRecipe(id);
          }
        }
      }

      ref.read(selectionModeProvider.notifier).state = false;
      ref.read(bulkSelectionProvider.notifier).state = {};
      messenger.showSnackBar(
          SnackBar(content: Text('Deleted ${ids.length} items')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }
}
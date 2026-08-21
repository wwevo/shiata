import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/kind_service.dart';
import '../../data/repo/product_service.dart';
import '../../data/repo/recipe_service.dart';
import '../main_screen_providers.dart';

class BottomControls extends ConsumerStatefulWidget {
  const BottomControls({super.key});

  @override
  ConsumerState<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends ConsumerState<BottomControls> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = ref.watch(selectionModeProvider);
    if (isSelectionMode) {
      return const BulkActionsToolbar();
    }

    final section = ref.watch(currentSectionProvider);

    int selectedIndex = 0;
    if (section == AppSection.activeWeek) {
      selectedIndex = 0;
    } else if ([AppSection.recipes, AppSection.products, AppSection.kinds]
        .contains(section)) {
      selectedIndex = 1;
    } else {
      selectedIndex = 2;
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            ref.read(currentSectionProvider.notifier).state =
                AppSection.activeWeek;
            break;
          case 1:
            if (_menuController.isOpen) {
              _menuController.close();
            } else {
              _menuController.open();
            }
            break;
          case 2:
            ref.read(currentSectionProvider.notifier).state =
                AppSection.database;
            break;
        }
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.format_list_bulleted_outlined),
          selectedIcon: Icon(Icons.format_list_bulleted),
          label: 'Tracking',
        ),
        NavigationDestination(
          icon: MenuAnchor(
            controller: _menuController,
            menuChildren: [
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.restaurant_menu_outlined,
                  color: section == AppSection.recipes
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                trailingIcon: section == AppSection.recipes
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onPressed: () {
                  ref.read(currentSectionProvider.notifier).state =
                      AppSection.recipes;
                },
                child: const Text('Recipes'),
              ),
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.shopping_basket_outlined,
                  color: section == AppSection.products
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                trailingIcon: section == AppSection.products
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onPressed: () {
                  ref.read(currentSectionProvider.notifier).state =
                      AppSection.products;
                },
                child: const Text('Products'),
              ),
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.category_outlined,
                  color: section == AppSection.kinds
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                trailingIcon: section == AppSection.kinds
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onPressed: () {
                  ref.read(currentSectionProvider.notifier).state =
                      AppSection.kinds;
                },
                child: const Text('Kinds'),
              ),
            ],
            child: Icon(
              selectedIndex == 1 ? Icons.fastfood : Icons.fastfood_outlined,
            ),
          ),
          label: 'Food',
        ),
        const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      statusText,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
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
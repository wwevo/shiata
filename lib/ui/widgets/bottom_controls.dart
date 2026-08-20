import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main_screen_providers.dart';
import 'bulk_actions_toolbar.dart';

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
    } else if (section == AppSection.database) {
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
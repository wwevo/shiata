import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main_screen_providers.dart';

class BottomControls extends ConsumerStatefulWidget {
  const BottomControls({super.key});

  @override
  ConsumerState<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends ConsumerState<BottomControls> {
  @override
  Widget build(BuildContext context) {
    final section = ref.watch(currentSectionProvider);

    return BottomAppBar(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Active Week button (new, placed first)
          IconButton(
            tooltip: 'Active Week',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.activeWeek;
            },
            icon: Text(
              '7',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: section == AppSection.activeWeek
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).iconTheme.color,
              ),
            ),
          ),
          IconButton(
            tooltip: 'All Entries',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.allEntries;
            },
            icon: Icon(
              Icons.view_list,
              color: section == AppSection.allEntries
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          MenuAnchor(
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
            builder: (ctx, controller, child) {
              final isRegistryActive = [
                AppSection.recipes,
                AppSection.products,
                AppSection.kinds,
              ].contains(section);
              return IconButton(
                tooltip: 'Registry',
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: Icon(
                  Icons.widgets_outlined,
                  color: isRegistryActive
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Database',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.database;
            },
            icon: Icon(
              Icons.storage,
              color: section == AppSection.database
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
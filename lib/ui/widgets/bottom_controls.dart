import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main_screen_providers.dart';

class BottomControls extends ConsumerStatefulWidget {
  const BottomControls({super.key});

  @override
  ConsumerState<BottomControls> createState() => _BottomControlsState();
}

class _BottomControlsState extends ConsumerState<BottomControls> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(currentSectionProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    // Sync controller with provider (only if different to avoid cursor jumps)
    if (_searchController.text != searchQuery) {
      _searchController.text = searchQuery;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }

    return BottomAppBar(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Overview button
          IconButton(
            tooltip: 'Overview',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.overview;
            },
            icon: Icon(
              Icons.bar_chart,
              color: section == AppSection.overview
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          // Calendar button
          IconButton(
            tooltip: 'Calendar',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.calendar;
            },
            icon: Icon(
              Icons.calendar_month,
              color: section == AppSection.calendar
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          IconButton(
            tooltip: 'Products',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.products;
            },
            icon: Icon(
              Icons.shopping_basket_outlined,
              color: section == AppSection.products
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          IconButton(
            tooltip: 'Kinds',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.kinds;
            },
            icon: Icon(
              Icons.category_outlined,
              color: section == AppSection.kinds
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          IconButton(
            tooltip: 'Recipes',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state =
                  AppSection.recipes;
            },
            icon: Icon(
              Icons.restaurant_menu_outlined,
              color: section == AppSection.recipes
                  ? Theme.of(context).colorScheme.primary
                  : null,
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
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                    ref.read(middleModeProvider.notifier).state =
                        MiddleMode.main;
                  },
                )
                    : null,
              ),
              onChanged: (q) {
                ref.read(searchQueryProvider.notifier).state = q;
                ref.read(middleModeProvider.notifier).state = q.trim().isEmpty
                    ? MiddleMode.main
                    : MiddleMode.search;
              },
            ),
          ),
        ],
      ),
    );
  }
}
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
    final handedness = ref.watch(handednessProvider);
    final viewMode = ref.watch(viewModeProvider);
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
          // Calendar/Overview toggle
          // When in calendar section: toggle between overview and calendar views
          // When in other sections: return to calendar section (remembers last view)
          IconButton(
            tooltip: section == AppSection.calendar
                ? (viewMode == ViewMode.overview ? 'Switch to Calendar' : 'Switch to Overview')
                : 'Go to Calendar',
            onPressed: () {
              if (section == AppSection.calendar) {
                // Toggle between overview and calendar within calendar section
                ref.read(viewModeProvider.notifier).state =
                    viewMode == ViewMode.overview ? ViewMode.calendar : ViewMode.overview;
              } else {
                // Return to calendar section (uses current viewMode)
                ref.read(currentSectionProvider.notifier).state = AppSection.calendar;
              }
            },
            icon: Icon(
              viewMode == ViewMode.overview ? Icons.calendar_month : Icons.bar_chart,
            ),
          ),
          IconButton(
            tooltip: 'Swap handedness',
            onPressed: () {
              ref.read(handednessProvider.notifier).state =
                  handedness == Handedness.left ? Handedness.right : Handedness.left;
            },
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Products',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state = AppSection.products;
            },
            icon: const Icon(Icons.shopping_basket_outlined),
          ),
          IconButton(
            tooltip: 'Kinds',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state = AppSection.kinds;
            },
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Recipes',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state = AppSection.recipes;
            },
            icon: const Icon(Icons.restaurant_menu_outlined),
          ),
          IconButton(
            tooltip: 'All Entries',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state = AppSection.allEntries;
            },
            icon: const Icon(Icons.view_list),
          ),
          IconButton(
            tooltip: 'Database',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state = AppSection.database;
            },
            icon: const Icon(Icons.storage),
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
                ref.read(middleModeProvider.notifier).state =
                    q.trim().isEmpty ? MiddleMode.main : MiddleMode.search;
              },
            ),
          ),
        ],
      ),
    );
  }
}

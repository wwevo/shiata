import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main_screen_providers.dart';

class BottomControls extends ConsumerWidget {
  const BottomControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handedness = ref.watch(handednessProvider);
    final viewMode = ref.watch(viewModeProvider);
    final section = ref.watch(currentSectionProvider);

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
            tooltip: 'Database',
            onPressed: () {
              ref.read(currentSectionProvider.notifier).state = AppSection.database;
            },
            icon: const Icon(Icons.storage),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
              ),
              onChanged: (q) {
                ref.read(searchQueryProvider.notifier).state = q;
                ref.read(middleModeProvider.notifier).state = q.trim().isEmpty ? MiddleMode.main : MiddleMode.search;
              },
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              final q = ref.read(searchQueryProvider);
              ref.read(middleModeProvider.notifier).state = q.trim().isEmpty ? MiddleMode.main : MiddleMode.search;
            },
            icon: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';


// Visible calendar anchor (e.g. start of week). Used by calendar navigation.
final calendarAnchorProvider = StateProvider<DateTime>((_) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Default to start of current week (Monday)
  return today.subtract(Duration(days: today.weekday - 1));
});

// Selected day (local date at midnight) for Day Details panel
final selectedDayProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  // Initialize selected day to today. Do not mutate other providers here to
  // avoid Riverpod initialization side-effects.
  return DateTime(now.year, now.month, now.day);
});

// App section navigation (main sections of the app)
enum AppSection {
  activeWeek,
  products,
  kinds,
  recipes,
  allEntries,
  database
}

final currentSectionProvider = StateProvider<AppSection>(
      (_) => AppSection.activeWeek,
);

// Expanded product parents in Day Details (by parent entry id)
final expandedProductsProvider = StateProvider<Set<String>>((_) => <String>{});
// Global expanded entries (for recursive list items across all pages)
final expandedEntriesProvider = StateProvider<Set<String>>((_) => <String>{});

// All Entries page filters
enum EntrySortMode { newest, oldest }

final entrySortModeProvider = StateProvider<EntrySortMode>(
      (_) => EntrySortMode.newest,
);

// Entry type filter: empty = show all, non-empty = show only selected types
// Valid types: 'kind' (direct nutrient entries), 'product', 'recipe'
final entryTypeFilterProvider = StateProvider<Set<String>>((_) => <String>{});
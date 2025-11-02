import 'package:flutter_riverpod/flutter_riverpod.dart';

// Handedness toggle for split-gesture control in the middle section.
enum Handedness { left, right }

final handednessProvider = StateProvider<Handedness>((_) => Handedness.left);

// Visible month anchor (first day of month, local). Used by calendar navigation.
final visibleMonthProvider = StateProvider<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// Selected day (local date at midnight) for Day Details panel
final selectedDayProvider = StateProvider<DateTime?>((ref) {
  final now = DateTime.now();
  // Initialize selected day to today. Do not mutate other providers here to
  // avoid Riverpod initialization side-effects.
  return DateTime(now.year, now.month, now.day);
});

// Middle content mode
enum MiddleMode { main, search }
final middleModeProvider = StateProvider<MiddleMode>((_) => MiddleMode.main);

// Search query
final searchQueryProvider = StateProvider<String>((_) => '');

// Expanded product parents in Day Details (by parent entry id)
final expandedProductsProvider = StateProvider<Set<String>>((_) => <String>{});
// CAS: whether the Nutrients grid is expanded (session-scoped)
final nutrientsExpandedProvider = StateProvider<bool>((_) => false);

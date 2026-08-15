import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
// Note: keep local date formatting within this file; no external date helpers needed here.
import '../main_screen_providers.dart';
import '../ux_config.dart';
import '../widgets/action_sheet_helpers.dart';
import '../widgets/entry_list_item_factory.dart';
import '../widgets/weekly_calendar.dart';

// Tri-state filtering per chip
enum ChipMode { off, include, exclude }

// Per-week selection state for the ActiveWeek chart
class _WeekSelectionState {
  final Map<String, ChipMode> kindModes; // kindId -> mode
  final bool isCustomized;
  const _WeekSelectionState({required this.kindModes, required this.isCustomized});

  _WeekSelectionState copyWith({Map<String, ChipMode>? kindModes, bool? isCustomized}) =>
      _WeekSelectionState(
        kindModes: kindModes ?? this.kindModes,
        isCustomized: isCustomized ?? this.isCustomized,
      );
}

class _WeekKindSelectionController extends StateNotifier<Map<String, _WeekSelectionState>> {
  _WeekKindSelectionController() : super(const {});

  void _set(String weekKey, _WeekSelectionState value) {
    state = {
      ...state,
      weekKey: value,
    };
  }

  // Set a chip to an exact mode (used by platform-specific UIs)
  void setKindMode(
    String weekKey,
    String kindId,
    ChipMode mode, {
    required Map<String, ChipMode> current,
  }) {
    final next = Map<String, ChipMode>.from(current);
    next[kindId] = mode;
    final cur = state[weekKey];
    _set(
      weekKey,
      (cur ?? const _WeekSelectionState(kindModes: {}, isCustomized: false))
          .copyWith(kindModes: next, isCustomized: true),
    );
  }

  // Initialize with all provided kind ids set to off (neutral)
  void initializeIfNeeded(String weekKey, Set<String> defaults) {
    if (!state.containsKey(weekKey)) {
      final modes = <String, ChipMode>{ for (final k in defaults) k: ChipMode.off };
      _set(weekKey, _WeekSelectionState(kindModes: modes, isCustomized: false));
    }
  }

  void syncWithDefaultsIfNotCustomized(String weekKey, Set<String> defaults) {
    final current = state[weekKey];
    if (current == null) return initializeIfNeeded(weekKey, defaults);
    if (!current.isCustomized) {
      // Reset to off for all defaults
      final desired = <String, ChipMode>{ for (final k in defaults) k: ChipMode.off };
      if (!_mapEquals(current.kindModes, desired)) {
        _set(weekKey, current.copyWith(kindModes: desired));
      }
    }
  }

  // Cycle a chip's mode: off -> include -> exclude -> off
  void cycleKindMode(String weekKey, String kindId, {required Map<String, ChipMode> current}) {
    final next = Map<String, ChipMode>.from(current);
    final curMode = next[kindId] ?? ChipMode.off;
    final ChipMode nxt = switch (curMode) {
      ChipMode.off => ChipMode.include,
      ChipMode.include => ChipMode.exclude,
      ChipMode.exclude => ChipMode.off,
    };
    next[kindId] = nxt;
    final cur = state[weekKey];
    _set(
      weekKey,
      (cur ?? const _WeekSelectionState(kindModes: {}, isCustomized: false))
          .copyWith(kindModes: next, isCustomized: true),
    );
  }

  void setModes(String weekKey, Map<String, ChipMode> modes, {bool customized = true}) {
    final cur = state[weekKey];
    _set(
      weekKey,
      (cur ?? const _WeekSelectionState(kindModes: {}, isCustomized: false))
          .copyWith(kindModes: {...modes}, isCustomized: customized),
    );
  }

  void resetToDefaults(String weekKey, Set<String> defaults) {
    final cur = state[weekKey];
    final desired = <String, ChipMode>{ for (final k in defaults) k: ChipMode.off };
    if (cur == null || !_mapEquals(cur.kindModes, desired) || cur.isCustomized) {
      _set(weekKey, _WeekSelectionState(kindModes: desired, isCustomized: false));
    }
  }

  static bool _mapEquals(Map<String, ChipMode> a, Map<String, ChipMode> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  // Convenience helpers
  static Set<String> includesOf(Map<String, ChipMode> modes) =>
      modes.entries.where((e) => e.value == ChipMode.include).map((e) => e.key).toSet();
  static Set<String> excludesOf(Map<String, ChipMode> modes) =>
      modes.entries.where((e) => e.value == ChipMode.exclude).map((e) => e.key).toSet();
}

final weekKindSelectionProvider =
    StateNotifierProvider<_WeekKindSelectionController, Map<String, _WeekSelectionState>>(
  (ref) => _WeekKindSelectionController(),
);

/// ActiveWeekPage: A new page that combines calendar week navigation with
/// a weekly list grouped by day and an inline add control.
///
/// This page is additive and does not alter existing Overview/Calendar pages.
class ActiveWeekPage extends ConsumerWidget {
  const ActiveWeekPage({super.key});
  static bool _coachShown = false; // one-time per app run

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(uxConfigProvider);
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final anchor = ref.watch(calendarAnchorProvider); // Monday of current week
    final selectedDay = ref.watch(selectedDayProvider);

    if (repo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final monday = anchor; // already a Monday per provider
    final nextMonday = monday.add(const Duration(days: 7));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));

    final stream = repo.watchByDayRange(
      monday,
      nextMonday,
      onlyShowInCalendar: false,
    );

    DateTime targetForAdd() {
      if (selectedDay != null) return selectedDay;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }

    // One-time Android coach-mark via SnackBar
    if (defaultTargetPlatform == TargetPlatform.android && !_coachShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _coachShown = true;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Tip: Long-press a chip to Exclude.')),
          );
        }
      });
    }

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekly calendar row (reused)
          SizedBox(
            height: 120,
            child: WeeklyCalendar(grid: config.calendarGrid),
          ),
          const Divider(height: 1),

          // Inline Add control (same flow as Overview plus action)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Add',
                  onPressed: () => showCreateActionSheet(context, ref, targetForAdd()),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                Text(
                  'Add to ${_fmtYmd(targetForAdd())}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),

          // Week list grouped by day with headers
          Expanded(
            child: StreamBuilder<dynamic>(
              stream: stream,
              builder: (context, snapshot) {
                // Normalize incoming data shape
                final mapByDay = <DateTime, List<EntryRecord>>{};
                final allEntries = <EntryRecord>[];

                if (snapshot.data is Map<DateTime, List<EntryRecord>>) {
                  final m = snapshot.data as Map<DateTime, List<EntryRecord>>;
                  for (final e in m.entries) {
                    final k = DateTime(e.key.year, e.key.month, e.key.day);
                    mapByDay[k] = [...(mapByDay[k] ?? const []), ...e.value];
                    allEntries.addAll(e.value);
                  }
                } else if (snapshot.data is List<EntryRecord>) {
                  final list = snapshot.data as List<EntryRecord>;
                  for (final e in list) {
                    final d = DateTime.fromMillisecondsSinceEpoch(
                      e.targetAt,
                      isUtc: true,
                    ).toLocal();
                    final k = DateTime(d.year, d.month, d.day);
                    (mapByDay[k] ??= []).add(e);
                    allEntries.add(e);
                  }
                }

                // Children map for nested rendering
                final childrenByParent = <String, List<EntryRecord>>{};
                for (final c in allEntries) {
                  final pid = c.sourceEntryId;
                  if (pid != null) {
                    (childrenByParent[pid] ??= []).add(c);
                  }
                }

                // Build caches of leaf kind sets per product/recipe DEFINITION for the current week.
                // This lets us resolve container contents even if a particular instance has no
                // materialized children in the stream for any reason.
                final Map<String, Set<String>> _productLeafKindsByProductId = {};
                final Map<String, Set<String>> _recipeLeafKindsByRecipeId = {};

                Set<String> _dfsLeafKinds(EntryRecord root) {
                  final leafKinds = <String>{};
                  final visited = <String>{};
                  void dfs(EntryRecord node) {
                    if (visited.contains(node.id)) return;
                    visited.add(node.id);
                    final isContainer = (node.widgetKind == 'product' || node.widgetKind == 'recipe');
                    if (!isContainer) {
                      leafKinds.add(node.widgetKind);
                      return;
                    }
                    final kids = childrenByParent[node.id] ?? const <EntryRecord>[];
                    if (kids.isEmpty) return;
                    for (final k in kids) {
                      dfs(k);
                    }
                  }
                  dfs(root);
                  return leafKinds;
                }

                // Populate caches from instances that do have children
                for (final e in allEntries) {
                  if (e.widgetKind == 'product' && (childrenByParent[e.id]?.isNotEmpty ?? false)) {
                    final pid = e.productId;
                    if (pid != null && !_productLeafKindsByProductId.containsKey(pid)) {
                      _productLeafKindsByProductId[pid] = _dfsLeafKinds(e);
                    }
                  } else if (e.widgetKind == 'recipe' && (childrenByParent[e.id]?.isNotEmpty ?? false)) {
                    final rid = e.recipeId;
                    if (rid != null && !_recipeLeafKindsByRecipeId.containsKey(rid)) {
                      _recipeLeafKindsByRecipeId[rid] = _dfsLeafKinds(e);
                    }
                  }
                }

                // Build a quick parent lookup and a set of ancestor ids that must be hidden due to excludes.
                // This guarantees that when a leaf kind is excluded, all its ancestor containers
                // (product/recipe) are also filtered out, even if their leaf kinds are not yet
                // materialized in childrenByParent for any reason.
                final Map<String, String> parentOf = {
                  for (final e in allEntries)
                    if (e.sourceEntryId != null) e.id: e.sourceEntryId!,
                };

                Set<String> _collectHiddenAncestors(Set<String> excludes) {
                  if (excludes.isEmpty) return const <String>{};
                  final hidden = <String>{};
                  // Start from any non-container entry that matches an excluded kind
                  final leavesToHide = allEntries.where((e) =>
                      e.sourceEntryId != null && e.widgetKind != 'product' && e.widgetKind != 'recipe' && excludes.contains(e.widgetKind));
                  for (final leaf in leavesToHide) {
                    String? cur = leaf.id;
                    // Climb up to the root parent, marking all ancestors hidden
                    while (cur != null) {
                      final p = parentOf[cur];
                      if (p == null) break;
                      if (!hidden.add(p)) {
                        // already visited this ancestor chain
                        cur = p;
                        continue;
                      }
                      cur = p;
                    }
                  }
                  return hidden;
                }

                // ================= Pie chart aggregation and per-week selection =================
                // Week key based on Monday local date for stable identity across navigation
                String _weekKey(DateTime d) =>
                    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                final weekKey = _weekKey(monday);

                // Aggregate ALL amounts (regardless of selection) to determine which kinds have data
                final allAmounts = <String, double>{};
                for (final e in allEntries) {
                  if (e.widgetKind == 'product' || e.widgetKind == 'recipe') continue;
                  try {
                    final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
                    final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
                    allAmounts[e.widgetKind] = (allAmounts[e.widgetKind] ?? 0.0) + amount;
                  } catch (_) {}
                }

                // Only show filter chips for kinds that actually have data in this week
                final availableKindIds = allAmounts.keys.toSet();

                // Determine defaults: all kinds available this week
                final defaultKinds = availableKindIds;

                // Read any customized selection for this week (no mutations during build)
                final selectionState = ref.watch(weekKindSelectionProvider)[weekKey];
                // Current modes map; if absent and not customized, we treat defaults as off (neutral)
                final currentModes = selectionState?.kindModes ??
                    { for (final k in defaultKinds) k: ChipMode.off };
                final includedKinds = _WeekKindSelectionController.includesOf(currentModes);
                final excludedKinds = _WeekKindSelectionController.excludesOf(currentModes);

                // Determine visible kinds for chart:
                // If any includes exist, use them; otherwise use all available minus excludes
                final bool allIncludedNoExcludes =
                    includedKinds.length == availableKindIds.length && excludedKinds.isEmpty;
                final Set<String> visibleKindsForChart = includedKinds.isNotEmpty
                    ? (allIncludedNoExcludes ? availableKindIds : includedKinds)
                    : (availableKindIds.difference(excludedKinds));
                // Aggregate visible kinds for pie chart
                final selectedAmounts = <String, double>{};
                for (final kindId in visibleKindsForChart) {
                  if (allAmounts.containsKey(kindId)) {
                    selectedAmounts[kindId] = allAmounts[kindId]!;
                  }
                }

                // Normalize values for pie chart (convert mg→g, µg→g)
                final normalizedAmounts = <String, double>{};
                for (final entry in selectedAmounts.entries) {
                  final kind = registry.byId(entry.key);
                  final unit = kind?.unit ?? '';
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
                  normalizedAmounts[entry.key] = normalized;
                }

                final total = normalizedAmounts.values.fold(0.0, (sum, v) => sum + v);

                // Compute normalized totals across ALL kinds to indicate how much of the week
                // the currently selected kinds represent. Keep the same normalization rules.
                final normalizedAllAmounts = <String, double>{};
                for (final entry in allAmounts.entries) {
                  final kind = registry.byId(entry.key);
                  final unit = kind?.unit ?? '';
                  double v = entry.value;
                  switch (unit) {
                    case 'mg':
                      v = v / 1000;
                      break;
                    case 'µg':
                      v = v / 1000000;
                      break;
                    default:
                      v = v;
                  }
                  normalizedAllAmounts[entry.key] = v;
                }

                final totalAll = normalizedAllAmounts.values.fold(0.0, (s, v) => s + v);
                final totalSelected = total;
                final displayedPct = totalAll == 0 ? 0.0 : (totalSelected / totalAll * 100);

                // Helper: collect all leaf kinds contained in an entry (recursively through
                // product/recipe -> product -> kind chains). Direct entries return their own kind.
                Set<String> _collectLeafKinds(
                  EntryRecord root,
                  Map<String, List<EntryRecord>> children,
                ) {
                  final leafKinds = <String>{};
                  final visited = <String>{};

                  void dfs(EntryRecord node) {
                    // Protect against accidental cycles
                    if (visited.contains(node.id)) return;
                    visited.add(node.id);

                    final isContainer = (node.widgetKind == 'product' || node.widgetKind == 'recipe');
                    if (!isContainer) {
                      leafKinds.add(node.widgetKind);
                      return;
                    }
                    final kids = children[node.id] ?? const <EntryRecord>[];
                    if (kids.isEmpty) {
                      // Fallback to definition-based cache if available
                      if (node.widgetKind == 'product') {
                        final pid = node.productId;
                        final cached = (pid != null) ? _productLeafKindsByProductId[pid] : null;
                        if (cached != null && cached.isNotEmpty) {
                          leafKinds.addAll(cached);
                        }
                      } else if (node.widgetKind == 'recipe') {
                        final rid = node.recipeId;
                        final cached = (rid != null) ? _recipeLeafKindsByRecipeId[rid] : null;
                        if (cached != null && cached.isNotEmpty) {
                          leafKinds.addAll(cached);
                        }
                      }
                      return; // nothing more to traverse
                    }
                    for (final k in kids) {
                      dfs(k);
                    }
                  }

                  dfs(root);
                  return leafKinds;
                }

                // Helper: whether a parent entry should be visible for current tri-state selection
                bool _entryMatchesKinds(
                  EntryRecord e,
                  Set<String> includes,
                  Set<String> excludes,
                  Map<String, List<EntryRecord>> children,
                ) {
                  // Fast path: if this entry (a parent) is marked hidden due to excluded
                  // descendants, drop it immediately.
                  final hiddenAncestors = _collectHiddenAncestors(excludedKinds);
                  if (hiddenAncestors.contains(e.id)) return false;

                  final isContainer = (e.widgetKind == 'product' || e.widgetKind == 'recipe');
                  final Set<String> kindsInEntry = isContainer
                      ? _collectLeafKinds(e, children)
                      : {e.widgetKind};

                  // Excludes always win
                  if (kindsInEntry.intersection(excludes).isNotEmpty) return false;

                  if (includes.isEmpty) {
                    // Exclusive-only mode: allow anything that doesn't contain excluded kinds
                    return true;
                  }

                  // If everything is included and nothing excluded, treat as no filtering
                  if (includes.length == availableKindIds.length && excludes.isEmpty) {
                    return true;
                  }

                  if (isContainer) {
                    // Subset match for containers: all includes must be present somewhere in the tree;
                    // extra kinds are allowed. Excludes are already handled above.
                    return includes.every(kindsInEntry.contains);
                  } else {
                    // Direct entries visible only if includes has exactly that one kind
                    return includes.length == 1 && includes.contains(e.widgetKind);
                  }
                }

                // Build a flattened list of rows: headers and entries.
                // Skip days that have no entries (as requested).
                final rows = <_RowItem>[];
                for (final day in days) {
                  final key = DateTime(day.year, day.month, day.day);
                  final list = (mapByDay[key] ?? const <EntryRecord>[]).toList();
                  list.sort((a, b) => a.targetAt.compareTo(b.targetAt)); // time asc

                  // Parents only at top level; children are rendered by factory
                  final parents = list.where((e) => e.sourceEntryId == null).toList();
                  final filteredParents = parents
                      .where((p) => _entryMatchesKinds(p, includedKinds, excludedKinds, childrenByParent))
                      .toList();
                  if (filteredParents.isEmpty) {
                    // Do not render empty days
                    continue;
                  }

                  rows.add(_RowItem.header(day));
                  for (final p in filteredParents) {
                    rows.add(_RowItem.entry(p));
                  }
                }

                // Build the combined UI: chart + weekly list
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Chart + filters block
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          // Filter chips
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                ...registry.kinds
                                    .where((kind) => availableKindIds.contains(kind.id))
                                    .map((kind) {
                                  final mode = currentModes[kind.id] ?? ChipMode.include;
                                  // Dot avatar color by mode
                                  final Color dotColor = switch (mode) {
                                    ChipMode.include => Colors.green,
                                    ChipMode.exclude => Colors.orange,
                                    ChipMode.off => Theme.of(context).colorScheme.surface,
                                  };
                                  final avatar = Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: mode == ChipMode.off
                                          ? Theme.of(context).colorScheme.surface
                                          : dotColor,
                                      border: Border.all(
                                        color: mode == ChipMode.off
                                            ? Theme.of(context).colorScheme.outline
                                            : dotColor,
                                        width: 1.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                  // Platform-specific chip rendering
                                  if (defaultTargetPlatform == TargetPlatform.linux) {
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TriStateChipSimple(
                                          mode: mode,
                                          onChanged: (m) => ref
                                              .read(weekKindSelectionProvider.notifier)
                                              .setKindMode(weekKey, kind.id, m, current: currentModes),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(kind.displayName, style: Theme.of(context).textTheme.bodySmall),
                                      ],
                                    );
                                  } else {
                                    // Android & others: tap toggles Off<->Include, long-press opens bottom sheet
                                    return GestureDetector(
                                      onLongPress: () async {
                                        final choice = await showModalBottomSheet<ChipMode>(
                                          context: context,
                                          builder: (ctx) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  title: const Text('Include'),
                                                  onTap: () => Navigator.pop(ctx, ChipMode.include),
                                                ),
                                                ListTile(
                                                  title: const Text('Exclude'),
                                                  onTap: () => Navigator.pop(ctx, ChipMode.exclude),
                                                ),
                                                ListTile(
                                                  title: const Text('Off'),
                                                  onTap: () => Navigator.pop(ctx, ChipMode.off),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                        if (choice != null) {
                                          ref
                                              .read(weekKindSelectionProvider.notifier)
                                              .setKindMode(weekKey, kind.id, choice, current: currentModes);
                                        }
                                      },
                                      child: FilterChip(
                                        avatar: avatar,
                                        label: Text(kind.displayName),
                                        selected: mode != ChipMode.off,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                        labelStyle: Theme.of(context).textTheme.bodySmall,
                                        onSelected: (_) {
                                          final next = (mode == ChipMode.off) ? ChipMode.include : ChipMode.off;
                                          ref
                                              .read(weekKindSelectionProvider.notifier)
                                              .setKindMode(weekKey, kind.id, next, current: currentModes);
                                        },
                                      ),
                                    );
                                  }
                                }),
                                // Reset control as the last item
                                _ResetChip(
                                  enabled: (selectionState?.isCustomized ?? false) &&
                                      !_WeekKindSelectionController._mapEquals(
                                        currentModes,
                                        { for (final k in defaultKinds) k: ChipMode.off },
                                      ),
                                  onPressed: () {
                                    ref
                                        .read(weekKindSelectionProvider.notifier)
                                        .resetToDefaults(weekKey, defaultKinds);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Pie chart or empty message
                          if (normalizedAmounts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                includedKinds.isEmpty
                                    ? 'Select kinds above to see chart'
                                    : 'No data for selected kinds',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  // Pie chart with center indicator of share of week
                                  SizedBox(
                                    width: 140,
                                    height: 140,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PieChart(
                                          PieChartData(
                                            sections: normalizedAmounts.entries.map((entry) {
                                              final kind = registry.byId(entry.key);
                                              final color =
                                                  kind?.accentColor ?? theme.colorScheme.primary;
                                              return PieChartSectionData(
                                                value: entry.value,
                                                title: '', // keep center clean
                                                color: color,
                                                radius: 50,
                                              );
                                            }).toList(),
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 28, // create donut
                                            centerSpaceColor: theme.colorScheme.surface,
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${displayedPct.toStringAsFixed(0)}%',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              'of week',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // Legend
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: normalizedAmounts.entries.map((entry) {
                                          final kind = registry.byId(entry.key);
                                          final color =
                                              kind?.accentColor ?? theme.colorScheme.primary;
                                          final unit = kind?.unit ?? '';
                                          // Display original value (not normalized)
                                          final originalValue = selectedAmounts[entry.key]!;
                                          final formattedValue = originalValue < 1
                                              ? originalValue.toStringAsFixed(2)
                                              : originalValue.toStringAsFixed(0);
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${kind?.displayName ?? entry.key}: $formattedValue$unit',
                                                    style: theme.textTheme.bodyMedium,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // The weekly list itself
                    Expanded(
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (ctx, i) {
                          final item = rows[i];
                          switch (item.type) {
                            case _RowType.header:
                              return _DayHeader(date: item.date!);
                            case _RowType.entry:
                              return EntryListItemFactory.buildEntry(
                                context: context,
                                ref: ref,
                                entry: item.entry!,
                                childrenByParent: childrenByParent,
                                registry: registry,
                                config: EntryListItemConfig.dayDetails,
                              );
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Linux: simple 3-segment color-only chip [Off | Include | Exclude]
class TriStateChipSimple extends StatelessWidget {
  final ChipMode mode;
  final ValueChanged<ChipMode> onChanged;
  const TriStateChipSimple({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color segColor(ChipMode m) {
      switch (m) {
        case ChipMode.include:
          return Colors.green.withValues(alpha: m == mode ? 0.35 : 0.18);
        case ChipMode.exclude:
          return Colors.orange.withValues(alpha: m == mode ? 0.35 : 0.18);
        case ChipMode.off:
          return theme.colorScheme.surface;
      }
    }

    return Container(
      height: 28,
      width: 60,
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: theme.colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              // Off segment: always switches to neutral (white). If already off, no-op visually.
              onTap: () => onChanged(ChipMode.off),
              child: Container(color: segColor(ChipMode.off)),
            ),
          ),
          Expanded(
            child: InkWell(
              // Include segment: toggle behavior — clicking the active segment disables it (goes Off)
              onTap: () => onChanged(mode == ChipMode.include ? ChipMode.off : ChipMode.include),
              child: Container(color: segColor(ChipMode.include)),
            ),
          ),
          Expanded(
            child: InkWell(
              // Exclude segment: toggle behavior — clicking the active segment disables it (goes Off)
              onTap: () => onChanged(mode == ChipMode.exclude ? ChipMode.off : ChipMode.exclude),
              child: Container(color: segColor(ChipMode.exclude)),
            ),
          ),
        ],
      ),
    );
  }
}

// Reset chip widget appended at the end of kinds list
class _ResetChip extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  const _ResetChip({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall;
    final chip = ActionChip(
      avatar: Icon(
        Icons.restart_alt,
        size: 16,
        color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withValues(alpha: 0.38),
      ),
      label: Text('Reset', style: labelStyle),
      onPressed: enabled ? onPressed : null,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Tooltip(
      message: 'Reset to week\'s kinds',
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Reset to week\'s kinds',
        child: chip,
      ),
    );
  }
}

enum _RowType { header, entry }

class _RowItem {
  final _RowType type;
  final DateTime? date;
  final EntryRecord? entry;
  const _RowItem._(this.type, {this.date, this.entry});
  factory _RowItem.header(DateTime d) => _RowItem._(_RowType.header, date: d);
  factory _RowItem.entry(EntryRecord e) => _RowItem._(_RowType.entry, entry: e);
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = date; // single day
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Text(
        '${_weekdayShort(date.weekday)} ${_fmtYmd(end)}',
        style: theme.textTheme.titleSmall,
      ),
    );
  }

  String _weekdayShort(int w) {
    switch (w) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }
}

// Local date formatter (YYYY-MM-DD) to avoid dependency on non-existent fmtYmd
String _fmtYmd(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

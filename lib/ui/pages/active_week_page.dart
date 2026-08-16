import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import '../ux_config.dart';
import '../widgets/action_sheet_helpers.dart';
import '../widgets/entry_list_item_factory.dart';
import '../widgets/weekly_calendar.dart';

enum ChipMode { off, include, exclude }

// Per-week selection state for the ActiveWeek chart
class _WeekSelectionState {
  final Map<String, ChipMode> kindModes; // kindId -> mode
  final bool isCustomized;

  const _WeekSelectionState({
    required this.kindModes,
    required this.isCustomized,
  });

  _WeekSelectionState copyWith({
    Map<String, ChipMode>? kindModes,
    bool? isCustomized,
  }) => _WeekSelectionState(
    kindModes: kindModes ?? this.kindModes,
    isCustomized: isCustomized ?? this.isCustomized,
  );
}

class _WeekKindSelectionController
    extends StateNotifier<Map<String, _WeekSelectionState>> {
  _WeekKindSelectionController() : super(const {});

  void _set(String weekKey, _WeekSelectionState value) {
    state = {...state, weekKey: value};
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
      final modes = <String, ChipMode>{
        for (final k in defaults) k: ChipMode.off,
      };
      _set(weekKey, _WeekSelectionState(kindModes: modes, isCustomized: false));
    }
  }

  void setModes(
    String weekKey,
    Map<String, ChipMode> modes, {
    bool customized = true,
  }) {
    final cur = state[weekKey];
    _set(
      weekKey,
      (cur ?? const _WeekSelectionState(kindModes: {}, isCustomized: false))
          .copyWith(kindModes: {...modes}, isCustomized: customized),
    );
  }

  void resetToDefaults(String weekKey, Set<String> defaults) {
    final cur = state[weekKey];
    final desired = <String, ChipMode>{
      for (final k in defaults) k: ChipMode.off,
    };
    if (cur == null ||
        !_mapEquals(cur.kindModes, desired) ||
        cur.isCustomized) {
      _set(
        weekKey,
        _WeekSelectionState(kindModes: desired, isCustomized: false),
      );
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

  static Set<String> includesOf(Map<String, ChipMode> modes) => modes.entries
      .where((e) => e.value == ChipMode.include)
      .map((e) => e.key)
      .toSet();

}

final weekKindSelectionProvider =
    StateNotifierProvider<
      _WeekKindSelectionController,
      Map<String, _WeekSelectionState>
    >((ref) => _WeekKindSelectionController());

String _weekKeyOf(DateTime monday) =>
    '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

double _normalizeByUnit(double v, String unit) {
  switch (unit) {
    case 'mg':
      return v / 1000;
    case 'µg':
      return v / 1000000;
    default:
      return v;
  }
}

Set<String> _visibleKinds(Set<String> available, Set<String> inc, Set<String> exc) {
  if (inc.isNotEmpty) {
    if (inc.length == available.length && exc.isEmpty) return available;
    return inc;
  }
  return available.difference(exc);
}

Set<String> _collectLeafKindsHelper(
  EntryRecord root,
  Map<String, List<EntryRecord>> children, {
  Map<String, Set<String>>? productCache,
  Map<String, Set<String>>? recipeCache,
}) {
  final leafKinds = <String>{};
  final visited = <String>{};
  void dfs(EntryRecord n) {
    if (visited.contains(n.id)) return; visited.add(n.id);
    final isContainer = (n.widgetKind == 'product' || n.widgetKind == 'recipe');
    if (!isContainer) { leafKinds.add(n.widgetKind); return; }
    final kids = children[n.id] ?? const <EntryRecord>[];
    if (kids.isEmpty) {
      if (n.widgetKind == 'product') {
        final pid = n.productId;
        final s = (pid != null && productCache != null) ? productCache[pid] : null;
        if (s != null) leafKinds.addAll(s);
      } else if (n.widgetKind == 'recipe') {
        final rid = n.recipeId;
        final s = (rid != null && recipeCache != null) ? recipeCache[rid] : null;
        if (s != null) leafKinds.addAll(s);
      }
      return;
    }
    for (final k in kids) {
      dfs(k);
    }
  }
  dfs(root);
  return leafKinds;
}

Set<String> _collectHiddenAncestorsHelper(
  Set<String> excludes,
  List<EntryRecord> all,
  Map<String, String> parentOf,
) {
  if (excludes.isEmpty) return const <String>{};
  final hidden = <String>{};
  final leavesToHide = all.where(
    (e) => e.sourceEntryId != null && e.widgetKind != 'product' && e.widgetKind != 'recipe' && excludes.contains(e.widgetKind),
  );
  for (final leaf in leavesToHide) {
    String? cur = leaf.id;
    while (cur != null) {
      final p = parentOf[cur];
      if (p == null) break;
      if (!hidden.add(p)) { cur = p; continue; }
      cur = p;
    }
  }
  return hidden;
}

//  Providers
final weekEntriesProvider = StreamProvider.family<List<EntryRecord>, DateTime>((ref, monday) {
  final repo = ref.watch(entriesRepositoryProvider);
  if (repo == null) {
    return Stream<List<EntryRecord>>.value(const <EntryRecord>[]);
  }
  final nextMonday = monday.add(const Duration(days: 7));
  return repo
      .watchByDayRange(monday, nextMonday, onlyShowInCalendar: false)
      .map((raw) {
        if (raw is List) {
          return List<EntryRecord>.from(raw as List);
        }
        return raw.values.expand((e) => e).toList();
      })
      .cast<List<EntryRecord>>();
});

final weekChildrenByParentProvider = Provider.family<Map<String, List<EntryRecord>>, DateTime>((ref, monday) {
  final all = ref.watch(weekEntriesProvider(monday)).asData?.value ?? const <EntryRecord>[];
  final map = <String, List<EntryRecord>>{};
  for (final e in all) {
    final p = e.sourceEntryId;
    if (p != null) (map[p] ??= []).add(e);
  }
  return map;
});

final weekParentOfProvider = Provider.family<Map<String, String>, DateTime>((ref, monday) {
  final all = ref.watch(weekEntriesProvider(monday)).asData?.value ?? const <EntryRecord>[];
  return {
    for (final e in all)
      if (e.sourceEntryId != null) e.id: e.sourceEntryId!,
  };
});

final weekAllAmountsProvider = Provider.family<Map<String, double>, DateTime>((ref, monday) {
  final all = ref.watch(weekEntriesProvider(monday)).asData?.value ?? const <EntryRecord>[];
  final map = <String, double>{};
  for (final e in all) {
    if (e.widgetKind == 'product' || e.widgetKind == 'recipe') continue;
    try {
      final payload = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
      map[e.widgetKind] = (map[e.widgetKind] ?? 0.0) + amount;
    } catch (_) {}
  }
  return map;
});

final weekAvailableKindsProvider = Provider.family<Set<String>, DateTime>((ref, monday) {
  return ref.watch(weekAllAmountsProvider(monday)).keys.toSet();
});

final weekNormalizedAllProvider = Provider.family<Map<String, double>, DateTime>((ref, monday) {
  final registry = ref.watch(widgetRegistryProvider);
  final src = ref.watch(weekAllAmountsProvider(monday));
  final out = <String, double>{};
  for (final e in src.entries) {
    final unit = registry.byId(e.key)?.unit ?? '';
    out[e.key] = _normalizeByUnit(e.value, unit);
  }
  return out;
});

final weekSelectionForKeyProvider = Provider.family<_WeekSelectionState?, DateTime>((ref, monday) {
  final key = _weekKeyOf(monday);
  return ref.watch(weekKindSelectionProvider.select((m) => m[key]));
});

final weekVisibleKindsProvider = Provider.family<Set<String>, DateTime>((ref, monday) {
  final available = ref.watch(weekAvailableKindsProvider(monday));
  final modes = ref.watch(weekSelectionForKeyProvider(monday))?.kindModes ?? {for (final k in available) k: ChipMode.off};
  final inc = modes.entries.where((e) => e.value == ChipMode.include).map((e) => e.key).toSet();
  final exc = modes.entries.where((e) => e.value == ChipMode.exclude).map((e) => e.key).toSet();
  return _visibleKinds(available, inc, exc);
});

final weekSelectedAmountsProvider = Provider.family<Map<String, double>, DateTime>((ref, monday) {
  final all = ref.watch(weekAllAmountsProvider(monday));
  final visible = ref.watch(weekVisibleKindsProvider(monday));
  return {for (final k in visible) if (all.containsKey(k)) k: all[k]!};
});

final weekNormalizedSelectedProvider = Provider.family<Map<String, double>, DateTime>((ref, monday) {
  final registry = ref.watch(widgetRegistryProvider);
  final src = ref.watch(weekSelectedAmountsProvider(monday));
  final out = <String, double>{};
  for (final e in src.entries) {
    final unit = registry.byId(e.key)?.unit ?? '';
    out[e.key] = _normalizeByUnit(e.value, unit);
  }
  return out;
});

final weekTotalsProvider = Provider.family<(double totalAll, double totalSelected, double pct), DateTime>((ref, monday) {
  final allN = ref.watch(weekNormalizedAllProvider(monday));
  final selN = ref.watch(weekNormalizedSelectedProvider(monday));
  final totalAll = allN.values.fold(0.0, (a, b) => a + b);
  final totalSel = selN.values.fold(0.0, (a, b) => a + b);
  final pct = totalAll == 0 ? 0.0 : (totalSel / totalAll * 100);
  return (totalAll, totalSel, pct);
});

final weekHiddenAncestorsProvider = Provider.family<Set<String>, DateTime>((ref, monday) {
  final all = ref.watch(weekEntriesProvider(monday)).asData?.value ?? const <EntryRecord>[];
  final parentOf = ref.watch(weekParentOfProvider(monday));
  final modes = ref.watch(weekSelectionForKeyProvider(monday))?.kindModes ?? const <String, ChipMode>{};
  final exc = modes.entries.where((e) => e.value == ChipMode.exclude).map((e) => e.key).toSet();
  return _collectHiddenAncestorsHelper(exc, all, parentOf);
});

bool _entryMatchesKindsProviderHelper(
  EntryRecord e,
  Set<String> includes,
  Set<String> excludes,
  Map<String, List<EntryRecord>> children,
  Set<String> hiddenAncestors,
  Set<String> availableKindIds,
  Map<String, Set<String>> productCache,
  Map<String, Set<String>> recipeCache,
) {
  if (hiddenAncestors.contains(e.id)) return false;
  final isContainer = (e.widgetKind == 'product' || e.widgetKind == 'recipe');
  final kindsIn = isContainer
      ? _collectLeafKindsHelper(e, children, productCache: productCache, recipeCache: recipeCache)
      : {e.widgetKind};
  if (kindsIn.intersection(excludes).isNotEmpty) return false;
  if (includes.isEmpty) return true;
  if (includes.length == availableKindIds.length && excludes.isEmpty) return true;
  return isContainer ? includes.every(kindsIn.contains) : (includes.length == 1 && includes.contains(e.widgetKind));
}

final weekRowsProvider = Provider.family<List<_RowItem>, DateTime>((ref, monday) {
  final days = List.generate(7, (i) => monday.add(Duration(days: i)));
  final mapByDay = <DateTime, List<EntryRecord>>{};
  final all = ref.watch(weekEntriesProvider(monday)).asData?.value ?? const <EntryRecord>[];
  for (final e in all) {
    final d = DateTime.fromMillisecondsSinceEpoch(e.targetAt, isUtc: true).toLocal();
    final k = DateTime(d.year, d.month, d.day);
    (mapByDay[k] ??= []).add(e);
  }
  final children = ref.watch(weekChildrenByParentProvider(monday));
  final hiddenAncestors = ref.watch(weekHiddenAncestorsProvider(monday));
  final availableKindIds = ref.watch(weekAvailableKindsProvider(monday));

  final productCache = <String, Set<String>>{};
  final recipeCache = <String, Set<String>>{};
  for (final e in all) {
    final kids = children[e.id];
    if ((kids?.isNotEmpty ?? false) && e.widgetKind == 'product' && e.productId != null) {
      productCache.putIfAbsent(e.productId!, () => _collectLeafKindsHelper(e, children));
    } else if ((kids?.isNotEmpty ?? false) && e.widgetKind == 'recipe' && e.recipeId != null) {
      recipeCache.putIfAbsent(e.recipeId!, () => _collectLeafKindsHelper(e, children));
    }
  }

  final modes = ref.watch(weekSelectionForKeyProvider(monday))?.kindModes ?? {for (final k in availableKindIds) k: ChipMode.off};
  final inc = modes.entries.where((e) => e.value == ChipMode.include).map((e) => e.key).toSet();
  final exc = modes.entries.where((e) => e.value == ChipMode.exclude).map((e) => e.key).toSet();

  final rows = <_RowItem>[];
  for (final day in days) {
    final key = DateTime(day.year, day.month, day.day);
    final list = (mapByDay[key] ?? const <EntryRecord>[]).toList()
      ..sort((a, b) => a.targetAt.compareTo(b.targetAt));
    final parents = list.where((e) => e.sourceEntryId == null).toList();
    final filtered = parents.where((p) => _entryMatchesKindsProviderHelper(
      p, inc, exc, children, hiddenAncestors, availableKindIds, productCache, recipeCache,
    )).toList();
    if (filtered.isEmpty) continue;
    rows.add(_RowItem.header(day));
    for (final p in filtered) {
      rows.add(_RowItem.entry(p));
    }
  }
  return rows;
});

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
          // Weekly calendar row
          SizedBox(
            height: 80,
            child: WeeklyCalendar(grid: config.calendarGrid),
          ),

          const Divider(height: 1),

          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final entriesAsync = ref.watch(weekEntriesProvider(monday));
                return entriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                  data: (_) {
                    final weekKey = _weekKeyOf(monday);
                    final availableKindIds = ref.watch(weekAvailableKindsProvider(monday));
                    final defaultKinds = availableKindIds;
                    final selectionState = ref.watch(weekSelectionForKeyProvider(monday));
                    final currentModes = selectionState?.kindModes ?? {for (final k in defaultKinds) k: ChipMode.off};
                    final includedKinds = _WeekKindSelectionController.includesOf(currentModes);
                    final normalizedSelected = ref.watch(weekNormalizedSelectedProvider(monday));
                    final totals = ref.watch(weekTotalsProvider(monday));
                    final selectedAmounts = ref.watch(weekSelectedAmountsProvider(monday));
                    final rows = ref.watch(weekRowsProvider(monday));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WeekFiltersBar(
                          theme: theme,
                          registry: registry,
                          availableKindIds: availableKindIds,
                          weekKey: weekKey,
                          currentModes: currentModes,
                          defaultKinds: defaultKinds,
                          selectionState: selectionState,
                        ),

                        _WeekSummarySection(
                          theme: theme,
                          registry: registry,
                          normalizedSelected: normalizedSelected,
                          pctOfWeek: totals.$3,
                          selectedAmounts: selectedAmounts,
                          includedKinds: includedKinds,
                        ),

                        const Divider(height: 1),

                        _InlineAddControl(
                          theme: theme,
                          onAdd: () => showCreateActionSheet(
                            context,
                            ref,
                            targetForAdd(),
                          ),
                          label: 'Add to ${_fmtYmd(targetForAdd())}',
                        ),

                        const Divider(height: 1),

                        // The weekly list itself
                        Expanded(
                          child: _WeeklyRowsList(
                            monday: monday,
                            rows: rows,
                            registry: registry,
                          ),
                        ),
                      ],
                    );
                  },
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

  const TriStateChipSimple({super.key, required this.mode, required this.onChanged});

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
              onTap: () => onChanged(
                mode == ChipMode.include ? ChipMode.off : ChipMode.include,
              ),
              child: Container(color: segColor(ChipMode.include)),
            ),
          ),
          Expanded(
            child: InkWell(
              // Exclude segment: toggle behavior — clicking the active segment disables it (goes Off)
              onTap: () => onChanged(
                mode == ChipMode.exclude ? ChipMode.off : ChipMode.exclude,
              ),
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

// Filters bar (kinds chips + Reset) extracted as a leaf widget
class _WeekFiltersBar extends ConsumerWidget {
  const _WeekFiltersBar({
    required this.theme,
    required this.registry,
    required this.availableKindIds,
    required this.weekKey,
    required this.currentModes,
    required this.defaultKinds,
    required this.selectionState,
  });

  final ThemeData theme;
  final WidgetRegistry registry;
  final Set<String> availableKindIds;
  final String weekKey;
  final Map<String, ChipMode> currentModes;
  final Set<String> defaultKinds;
  final _WeekSelectionState? selectionState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...registry.kinds
                    .where((kind) => availableKindIds.contains(kind.id))
                    .map((kind) {
                  final mode = currentModes[kind.id] ?? ChipMode.include;
                  return _KindModeChip(
                    label: kind.displayName,
                    mode: mode,
                    onChanged: (next) => ref.read(weekKindSelectionProvider.notifier).setKindMode(
                          weekKey,
                          kind.id,
                          next,
                          current: currentModes,
                        ),
                  );
                }),
                _ResetChip(
                  enabled: (selectionState?.isCustomized ?? false) &&
                      !_WeekKindSelectionController._mapEquals(
                        currentModes,
                        {for (final k in defaultKinds) k: ChipMode.off},
                      ),
                  onPressed: () {
                    ref.read(weekKindSelectionProvider.notifier).resetToDefaults(weekKey, defaultKinds);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Platform-agnostic kind mode chip: wraps Linux tri-state and mobile FilterChip interactions
class _KindModeChip extends StatelessWidget {
  const _KindModeChip({
    required this.label,
    required this.mode,
    required this.onChanged,
  });

  final String label;
  final ChipMode mode;
  final ValueChanged<ChipMode> onChanged;

  @override
  Widget build(BuildContext context) {
    // Compute small avatar dot to match previous UI for non-Linux path
    final Color dotColor = switch (mode) {
      ChipMode.include => Colors.green,
      ChipMode.exclude => Colors.orange,
      ChipMode.off => Theme.of(context).colorScheme.surface,
    };
    final avatar = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: mode == ChipMode.off ? Theme.of(context).colorScheme.surface : dotColor,
        border: Border.all(
          color: mode == ChipMode.off ? Theme.of(context).colorScheme.outline : dotColor,
          width: 1.2,
        ),
        shape: BoxShape.circle,
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.linux) {
      // Preserve Linux behavior: tri-state control + text label
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TriStateChipSimple(
            mode: mode,
            onChanged: onChanged,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    // Non-Linux: FilterChip that toggles off/include on tap and supports long-press modal for all modes
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
          onChanged(choice);
        }
      },
      child: FilterChip(
        avatar: avatar,
        label: Text(label),
        selected: mode != ChipMode.off,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        labelStyle: Theme.of(context).textTheme.bodySmall,
        onSelected: (_) {
          final next = (mode == ChipMode.off) ? ChipMode.include : ChipMode.off;
          onChanged(next);
        },
      ),
    );
  }
}

// Summary section (empty state or pie + legend), logic preserved
class _WeekSummarySection extends StatelessWidget {
  const _WeekSummarySection({
    required this.theme,
    required this.registry,
    required this.normalizedSelected,
    required this.pctOfWeek,
    required this.selectedAmounts,
    required this.includedKinds,
  });

  final ThemeData theme;
  final WidgetRegistry registry;
  final Map<String, double> normalizedSelected;
  final double pctOfWeek;
  final Map<String, double> selectedAmounts;
  final Set<String> includedKinds;

  @override
  Widget build(BuildContext context) {
    final Widget content = normalizedSelected.isEmpty
        ? Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
        : Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: normalizedSelected.entries.map((entry) {
                            final kind = registry.byId(entry.key);
                            final color = kind?.accentColor ?? theme.colorScheme.primary;
                            return PieChartSectionData(
                              value: entry.value,
                              title: '',
                              color: color,
                              radius: 50,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 28,
                          centerSpaceColor: theme.colorScheme.surface,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${pctOfWeek.toStringAsFixed(0)}%',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'of week',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Builder(
                      builder: (context) {
                        // Keep original sorting and interleaving (longest, shortest, ...) to preserve intent.
                        String labelFor(String id) => registry.byId(id)?.displayName ?? id;
                        String unitFor(String id) => registry.byId(id)?.unit ?? '';
                        String valueTextFor(String id) {
                          final v = selectedAmounts[id] ?? 0;
                          return v < 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(0);
                        }

                        final sorted = normalizedSelected.entries
                            .map((e) {
                              final label = labelFor(e.key);
                              final txt = valueTextFor(e.key) + unitFor(e.key);
                              final len = label.length + 1 + txt.length;
                              return (entry: e, len: len, label: label);
                            })
                            .toList()
                          ..sort((a, b) {
                            final c = b.len.compareTo(a.len);
                            if (c != 0) return c;
                            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
                          });

                        final ordered = <MapEntry<String, double>>[];
                        int i = 0, j = sorted.length - 1;
                        var takeLongest = true;
                        while (i <= j) {
                          if (takeLongest) {
                            ordered.add(sorted[i].entry);
                            i++;
                          } else {
                            ordered.add(sorted[j].entry);
                            j--;
                          }
                          takeLongest = !takeLongest;
                        }

                        if (ordered.isEmpty) return const SizedBox.shrink();

                        final textStyle = theme.textTheme.bodyMedium ?? const TextStyle();
                        final items = ordered.map((e) {
                          final kind = registry.byId(e.key);
                          final unit = kind?.unit ?? '';
                          final originalValue = selectedAmounts[e.key] ?? 0;
                          final formattedValue = originalValue < 1
                              ? originalValue.toStringAsFixed(2)
                              : originalValue.toStringAsFixed(0);
                          final label = kind?.displayName ?? e.key;
                          final color = kind?.accentColor ?? theme.colorScheme.primary;
                          return (
                            label: label,
                            value: formattedValue,
                            unit: unit,
                            color: color,
                          );
                        }).toList();

                        // Simplified, adaptive legend grid: no TextPainter/layout math.
                        return GridView.builder(
                          primary: false,
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisExtent: 28,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 16,
                          ),
                          itemCount: items.length,
                          itemBuilder: (ctx, idx) {
                            final it = items[idx];
                            return Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: it.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${it.label}: ${it.value}${it.unit}',
                                    style: textStyle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );

    return Column(
      children: [
        const Divider(height: 1),
        content,
      ],
    );
  }
}

class _InlineAddControl extends StatelessWidget {
  const _InlineAddControl({
    required this.theme,
    required this.onAdd,
    required this.label,
  });

  final ThemeData theme;
  final VoidCallback onAdd;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Add',
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _WeeklyRowsList extends ConsumerWidget {
  const _WeeklyRowsList({
    required this.monday,
    required this.rows,
    required this.registry,
  });

  final DateTime monday;
  final List<_RowItem> rows;
  final WidgetRegistry registry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
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
              childrenByParent: ref.watch(weekChildrenByParentProvider(monday)),
              registry: registry,
              config: EntryListItemConfig.dayDetails,
            );
        }
      },
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

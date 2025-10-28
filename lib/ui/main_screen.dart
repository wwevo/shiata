import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'ux_config.dart';
import 'editors/protein_editor.dart';
import 'editors/fat_editor.dart';
import '../data/providers.dart';
import '../domain/widgets/registry.dart';
import '../data/repo/entries_repository.dart';
import 'dart:convert';

// Handedness toggle for split-gesture control in the middle section.
enum Handedness { left, right }

final handednessProvider = StateProvider<Handedness>((_) => Handedness.left);

// Selected day (local date at midnight) for Day Details panel
final selectedDayProvider = StateProvider<DateTime?>((_) => null);

// Hosts the top calendar sheet and overlaps it above the middle content using a Stack.
class TopSheetHost extends StatefulWidget {
  const TopSheetHost({super.key, required this.childBelow, required this.config});
  final Widget childBelow; // Middle panel under the sheet
  final UXConfig config;

  @override
  State<TopSheetHost> createState() => _TopSheetHostState();
}

class _TopSheetHostState extends State<TopSheetHost> with SingleTickerProviderStateMixin {
  // Drag state for visual guidance & haptics.
  bool _isDragging = false;
  bool _hasCrossed = false; // crossed threshold upwards during current drag

  late final AnimationController _controller;
  // t in [0..1], 0=collapsed, 1=expanded
  double get t => _controller.value;
  double get _expanded => widget.config.topSheet.expandedHeight;
  double get _collapsed => widget.config.topSheet.collapsedHeight;
  double get height => lerpDouble(_collapsed, _expanded, t)!;
  bool get isExpanded => t >= 0.999;
  bool get isCollapsed => t <= 0.001;

  Thresholds get _thresholds => widget.config.thresholds;
  AnimationsConfig get _anim => widget.config.animations;
  HapticsConfig get _haptics => widget.config.haptics;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _anim.controllerBaseDuration,
      value: 0.0, // start collapsed
    );
  }

  void expand() {
    if (isExpanded) return;
    if (_controller.isAnimating && _controller.status == AnimationStatus.forward) return;
    _controller.fling(velocity: 2.2);
  }

  void collapse() {
    if (isCollapsed) return;
    if (_controller.isAnimating && _controller.status == AnimationStatus.reverse) return;
    _controller.fling(velocity: -2.2);
  }

  void toggle() {
    if (_controller.isAnimating) return; // ignore rapid taps while animating
    (t >= 0.5) ? collapse() : expand();
  }

  // Called when a user starts dragging the overlay control area.
  void onUserDragStart() {
    if (_controller.isAnimating) {
      _controller.stop(); // give direct control to the finger
    }
    // Begin dragging visual guidance & reset crossing state baseline.
    _isDragging = true;
    _hasCrossed = t >= _thresholds.openKeepFraction;
    setState(() {});
  }

  // Drag by pixel delta; positive delta means finger moved down (expand), negative = up (collapse).
  void dragBy(double delta) {
    // If at a boundary and dragging further into it, ignore to avoid re-triggering animations.
    if (isExpanded && delta > 0) {
      // Already fully open and dragging further down → ignore.
      return;
    }
    if (isCollapsed && delta < 0) {
      // Already fully collapsed and dragging further up → ignore.
      return;
    }

    final range = (_expanded - _collapsed).clamp(1, double.infinity);
    final wasCrossed = t >= _thresholds.openKeepFraction;
    final newT = (t + (delta / range)).clamp(0.0, 1.0);
    if (newT == t) return; // no change
    _controller.value = newT;

    // Threshold crossing detection for haptic feedback
    final nowCrossed = _controller.value >= _thresholds.openKeepFraction;
    if (!_hasCrossed && nowCrossed) {
      // Crossed upward for the first time in this drag → optional haptic
      if (_haptics.enableThresholdHaptic) {
        switch (_haptics.onDownwardCrossing) {
          case HapticType.selectionClick:
            HapticFeedback.selectionClick();
            break;
          case HapticType.lightImpact:
            HapticFeedback.lightImpact();
            break;
          case HapticType.mediumImpact:
            HapticFeedback.mediumImpact();
            break;
          case HapticType.heavyImpact:
            HapticFeedback.heavyImpact();
            break;
        }
      }
      _hasCrossed = true;
    } else if (_hasCrossed && !nowCrossed && wasCrossed) {
      // Fell back below; reset gate (no haptic on downward by default)
      if (!_haptics.fireOnUpwardOnly && _haptics.enableThresholdHaptic) {
        // Optional haptic on downward crossing
        switch (_haptics.onDownwardCrossing) {
          case HapticType.selectionClick:
            HapticFeedback.selectionClick();
            break;
          case HapticType.lightImpact:
            HapticFeedback.lightImpact();
            break;
          case HapticType.mediumImpact:
            HapticFeedback.mediumImpact();
            break;
          case HapticType.heavyImpact:
            HapticFeedback.heavyImpact();
            break;
        }
      }
      _hasCrossed = false;
    }

    // Update visuals tied to dragging
    if (_isDragging) setState(() {});
  }

  void settle(double velocity) {
    // Drag finished; hide guide visuals.
    if (_isDragging) {
      _isDragging = false;
      setState(() {});
    }
    // Slider-style settle: ignore velocity. Open only if the threshold is reached; otherwise close.
    if (t >= _thresholds.openKeepFraction) {
      if (!isExpanded) {
        _controller.animateTo(1.0, duration: _anim.settleOpenDuration, curve: _anim.expandCurve);
      }
    } else {
      if (!isCollapsed) {
        _controller.animateTo(0.0, duration: _anim.settleCloseDuration, curve: _anim.collapseCurve);
      }
    }
    // Reset haptic gate for next drag sequence.
    _hasCrossed = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            // Middle content underneath
            Positioned.fill(child: widget.childBelow),

            // Top calendar sheet that overlaps
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: height,
              child: RepaintBoundary(
                child: _CalendarSheet(
                t: t,
                config: widget.config,
                isActive: _isDragging && t >= _thresholds.openKeepFraction,
                onHandleTap: toggle,
              ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthCalendar extends ConsumerWidget {
  const _MonthCalendar({Key? key, required this.grid}) : super(key: key);
  final CalendarGridConfig grid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch selected day so selection highlight updates immediately
    final selectedDay = ref.watch(selectedDayProvider);
    // Compute current month range (local time)
    final now = DateTime.now();
    // Start of current month in local time
    final firstOfMonthLocal = DateTime(now.year, now.month, 1);
    // Offset so that the first calendar cell is a Sunday
    final offsetToSunday = firstOfMonthLocal.weekday % 7; // Mon=1..Sun=7
    final firstCellLocal = firstOfMonthLocal.subtract(Duration(days: offsetToSunday));
    // Use UTC for day iteration to avoid DST-related duplicate/missing local dates
    final firstCellUtc = DateTime.utc(firstCellLocal.year, firstCellLocal.month, firstCellLocal.day);
    final daysToShow = grid.columns * grid.rows; // 42

    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);

    if (repo == null) {
      return const SizedBox.shrink();
    }

    // Build responsive grid with aspect ratio matching available space
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - grid.padding * 2;
        final gridHeight = constraints.maxHeight - grid.padding * 2;
        if (gridWidth <= 0 || gridHeight <= grid.paintMinHeightPx) {
          return const SizedBox.shrink();
        }
        final totalSpacingW = grid.crossAxisSpacing * (grid.columns - 1);
        final totalSpacingH = grid.mainAxisSpacing * (grid.rows - 1);
        final cellWidth = (gridWidth - totalSpacingW) / grid.columns;
        final cellHeight = (gridHeight - totalSpacingH) / grid.rows;
        if (cellWidth <= grid.paintMinCellPx || cellHeight <= grid.paintMinCellPx) {
          return const SizedBox.shrink();
        }
        final aspect = cellWidth / cellHeight;

        // Stream for entries within the visible calendar window (local dates)
        final startLocal = firstCellLocal;
        final endLocal = firstCellLocal.add(Duration(days: daysToShow));

        return StreamBuilder<Map<DateTime, List<dynamic>>>(
          // We'll map EntryRecord type dynamically (avoid import cycles in this file)
          stream: repo.watchByDayRange(startLocal, endLocal, onlyShowInCalendar: true).cast<Map<DateTime, List<dynamic>>>(),
          builder: (context, snapshot) {
            final byDay = snapshot.data ?? const <DateTime, List<dynamic>>{};

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.all(grid.padding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: grid.columns,
                mainAxisSpacing: grid.mainAxisSpacing,
                crossAxisSpacing: grid.crossAxisSpacing,
                childAspectRatio: aspect,
              ),
              itemCount: daysToShow,
              itemBuilder: (context, i) {
                final date = firstCellUtc.add(Duration(days: i)).toLocal();
                final isCurrentMonth = date.month == now.month;
                final dayKey = DateTime(date.year, date.month, date.day);
                final items = byDay[dayKey] ?? const [];

                // Map widget kinds to accent colors
                final colors = <Color>[];
                for (final rec in items) {
                  final kindId = (rec as dynamic).widgetKind as String? ?? 'unknown';
                  final kind = registry.byId(kindId);
                  if (kind != null) {
                    colors.add(kind.accentColor);
                  }
                }
                // Cap visible dots at 4
                final maxDots = 4;
                final showDots = colors.take(maxDots).toList();
                final overflow = (colors.length - maxDots).clamp(0, 999);

                return LayoutBuilder(
                  builder: (cellCtx, cellConstraints) {
                    final cellH = cellConstraints.maxHeight;
                    final cellW = cellConstraints.maxWidth;
                    // Guard: when cells are very small during animation, avoid laying out text/rows
                    const minContentH = 28.0; // safe minimum to render text + dots
                    final canRenderContent = cellH >= minContentH && cellW >= minContentH;

                    final selected = ref.read(selectedDayProvider);
                    final isSelected = selected != null &&
                        selected.year == date.year && selected.month == date.month && selected.day == date.day;
                    return GestureDetector(
                      onTap: () {
                        ref.read(selectedDayProvider.notifier).state = DateTime(date.year, date.month, date.day);
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: isCurrentMonth ? 0.4 : 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: canRenderContent
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${date.day}',
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: isCurrentMonth
                                                ? Theme.of(context).colorScheme.onSurface
                                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                    ),
                                    const Spacer(),
                                    if (showDots.isNotEmpty)
                                      Wrap(
                                        spacing: 2,
                                        runSpacing: 2,
                                        children: [
                                          for (final c in showDots)
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                                            ),
                                          if (overflow > 0)
                                            Text('+$overflow', style: Theme.of(context).textTheme.labelSmall),
                                        ],
                                      ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _DayDetailsPanel extends ConsumerWidget {
  const _DayDetailsPanel({super.key});

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    if (selected == null || repo == null) {
      // Hint area
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Tap a day to see details',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ),
      );
    }

    return StreamBuilder<List<EntryRecord>>(
      stream: repo.watchByDay(selected),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <EntryRecord>[];
        if (entries.isEmpty) {
          // Empty state with Add actions (temporary until CAS in Step 8)
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final now = DateTime.now();
                        final initial = DateTime(selected.year, selected.month, selected.day, now.hour, now.minute);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProteinEditorScreen(initialTargetAt: initial)),
                        );
                      },
                      icon: const Icon(Icons.fitness_center),
                      label: const Text('Add Protein'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final now = DateTime.now();
                        final initial = DateTime(selected.year, selected.month, selected.day, now.hour, now.minute);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => FatEditorScreen(initialTargetAt: initial)),
                        );
                      },
                      icon: const Icon(Icons.opacity),
                      label: const Text('Add Fat'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final e = entries[i];
                  final localTime = DateTime.fromMillisecondsSinceEpoch(e.targetAt, isUtc: true).toLocal();
                  final kind = registry.byId(e.widgetKind);
                  final color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
                  final icon = kind?.icon ?? Icons.circle;
                  // Derive short summary from payload
                  String summary = '';
                  try {
                    final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
                    final grams = (map['grams'] as num?)?.toInt();
                    if (grams != null) summary = '$grams g';
                  } catch (_) {}
                  return ListTile(
                    onTap: () {
                      // Open editor in edit mode based on kind id
                      if (e.widgetKind == 'protein') {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProteinEditorScreen(entryId: e.id)));
                      } else if (e.widgetKind == 'fat') {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => FatEditorScreen(entryId: e.id)));
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Icon(icon, size: 18),
                    ),
                    title: Text('${kind?.displayName ?? e.widgetKind} • ${summary.isEmpty ? '—' : summary}'),
                    subtitle: Row(
                      children: [
                        Text(_fmtTime(localTime)),
                        if (!e.showInCalendar) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.event_busy, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text('Hidden', style: Theme.of(context).textTheme.labelSmall),
                        ]
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarSheet extends StatelessWidget {
  const _CalendarSheet({required this.t, required this.config, required this.isActive, required this.onHandleTap});
  final double t;
  final UXConfig config;
  final bool isActive; // true while dragging and past threshold
  final VoidCallback onHandleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visuals = config.visuals;
    final elevation = lerpDouble(visuals.elevationCollapsed, visuals.elevationExpanded, t)!;
    return Material(
      color: theme.colorScheme.surface,
      elevation: elevation,
      shadowColor: theme.colorScheme.shadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Calendar area (visible proportionally as t grows)
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                // Reduce the painted height proportionally to t to avoid
                // painting extremely tiny text that can trigger Impeller glyph errors.
                heightFactor: (t <= 0.0 ? 0.0 : t.clamp(0.0, 1.0)),
                child: Opacity(
                  opacity: config.visuals.opacityCurve.transform(t),
                  // Stop painting the grid when nearly collapsed to avoid
                  // text layout at near-zero sizes. Maintain state to keep
                  // calendar widgets alive.
                  child: Visibility(
                    visible: t >= config.thresholds.paintVisibleMinT,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: false,
                    child: Column(
                                          children: [
                                            // Calendar grid takes top portion
                                            Flexible(flex: 3, child: _MonthCalendar(grid: config.calendarGrid)),
                                            // Day details panel uses remaining portion
                                            Flexible(flex: 2, child: _DayDetailsPanel()),
                                          ],
                                        ),
                  ),
                ),
              ),
            ),
          ),
          // Handle (always visible; thin bar at the bottom you can tap)
          GestureDetector(
            onTap: onHandleTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: config.handle.touchAreaHeight,
              child: Center(
                child: _HandleBar(isActive: isActive, handle: config.handle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HandleBar extends StatelessWidget {
  const _HandleBar({required this.isActive, required this.handle});
  final bool isActive;
  final HandleConfig handle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactive = theme.colorScheme.onSurface.withValues(alpha: 0.32);
    final active = theme.colorScheme.primaryContainer;
    final color = isActive ? active : inactive;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: isActive ? handle.barWidthActive : handle.barWidthInactive,
      height: handle.barHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(handle.barHeight / 2),
      ),
    );
  }
}

class MiddlePanel extends ConsumerStatefulWidget {
  const MiddlePanel({super.key});
  @override
  ConsumerState<MiddlePanel> createState() => _MiddlePanelState();
}

class _MiddlePanelState extends ConsumerState<MiddlePanel> {
  final _scrollController = ScrollController();
  double _lastDy = 0;
  double _velocity = 0;

  _TopSheetHostState? get _host => context.findAncestorStateOfType<_TopSheetHostState>();

  void _onDragStart(DragStartDetails d) {
    _lastDy = d.localPosition.dy;
    _velocity = 0;
    _host?.onUserDragStart();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dy = d.localPosition.dy;
    final delta = dy - _lastDy;
    _lastDy = dy;
    _host?.dragBy(delta);
    _velocity = d.primaryDelta ?? 0;
  }

  void _onDragEnd(DragEndDetails d) {
    _host?.settle(d.primaryVelocity ?? _velocity * 1000);
  }

  @override
  Widget build(BuildContext context) {
    final handedness = ref.watch(handednessProvider);

    // Content underlay: regular list (acts as widgets list or search results)
    final content = ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.indigo,
                child: const Icon(Icons.fitness_center, color: Colors.white),
              ),
              title: const Text('Protein'),
              subtitle: const Text('Tap to open'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProteinEditorScreen()),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.amber,
                child: const Icon(Icons.opacity, color: Colors.white),
              ),
              title: const Text('Fat'),
              subtitle: const Text('Tap to open'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FatEditorScreen()),
                );
              },
            ),
          ),
        ),
      ],
    );

    // Overlay: 50/50 split. One half captures vertical drags to control Top; the other is pass-through.
    final overlay = Positioned.fill(
      child: Row(
        children: [
          // Left half
          Expanded(
            child: handedness == Handedness.left
                ? GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                  )
                : const IgnorePointer(ignoring: true, child: SizedBox.expand()),
          ),
          // Right half
          Expanded(
            child: handedness == Handedness.right
                ? GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                  )
                : const IgnorePointer(ignoring: true, child: SizedBox.expand()),
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        overlay,
      ],
    );
  }
}

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(uxConfigProvider);
    return TopSheetHost(
      config: config,
      childBelow: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(child: MiddlePanel()),
        ],
      ),
    );
  }
}

class BottomControls extends ConsumerWidget {
  const BottomControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handedness = ref.watch(handednessProvider);
    return BottomAppBar(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Swap handedness',
            onPressed: () {
              ref.read(handednessProvider.notifier).state =
                  handedness == Handedness.left ? Handedness.right : Handedness.left;
            },
            icon: const Icon(Icons.swap_horiz),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
              ),
              onChanged: (q) {
                // TODO: swap MiddlePanel to search-results mode
              },
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
        ],
      ),
    );
  }
}


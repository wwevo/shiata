import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../data/repo/import_export_service.dart';
import '../data/repo/recipe_service.dart';
import 'ux_config.dart';
import 'editors/protein_editor.dart';
import 'editors/fat_editor.dart';
import 'editors/carbohydrate_editor.dart';
import 'editors/generic_nutrient_editor.dart';
import 'main_actions_list.dart';
import 'editors/product_editor.dart';
import 'products/product_templates_page.dart';
import 'kinds/kinds_page.dart';
import 'recipes/recipes_page.dart';
import 'editors/instance_components_editor.dart';
import '../data/providers.dart';
import '../data/db/db_handle.dart';
import '../domain/widgets/registry.dart';
import '../domain/widgets/widget_kind.dart';
import '../domain/widgets/create_action.dart';
import '../data/repo/entries_repository.dart';
import '../data/repo/product_service.dart';
import 'dart:convert';

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
  const _MonthCalendar({required this.grid});
  final CalendarGridConfig grid;

  void _changeMonth(WidgetRef ref, DateTime current, int delta) {
    final next = DateTime(current.year, current.month + delta, 1);
    ref.read(visibleMonthProvider.notifier).state = next;
    // Keep a selected day always; if selection falls outside new month, pick a sensible default.
    final sel = ref.read(selectedDayProvider);
    if (sel == null || sel.year != next.year || sel.month != next.month) {
      final today = DateTime.now();
      if (today.year == next.year && today.month == next.month) {
        ref.read(selectedDayProvider.notifier).state = DateTime(today.year, today.month, today.day);
      } else {
        ref.read(selectedDayProvider.notifier).state = DateTime(next.year, next.month, 1);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch selected day so selection highlight updates immediately
    final selectedDay = ref.watch(selectedDayProvider);
    final visibleMonth = ref.watch(visibleMonthProvider);
    // Start of visible month in local time
    final firstOfMonthLocal = DateTime(visibleMonth.year, visibleMonth.month, 1);
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

    String monthLabel(DateTime m) {
      final monthNames = const [
        'January','February','March','April','May','June','July','August','September','October','November','December'
      ];
      return '${monthNames[m.month - 1]} ${m.year}';
    }

    // Build responsive grid with aspect ratio matching available space
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - grid.padding * 2;
        final gridHeight = constraints.maxHeight - grid.padding * 2 - 36; // reserve header height
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

        final header = Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(ref, visibleMonth, -1),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthLabel(visibleMonth),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(ref, visibleMonth, 1),
              ),
            ],
          ),
        );

        final gridWidget = StreamBuilder<Map<DateTime, List<dynamic>>>(
          // We'll map EntryRecord type dynamically (avoid import cycles in this file)
          stream: repo
              .watchByDayRange(startLocal, endLocal, onlyShowInCalendar: true)
              .cast<Map<DateTime, List<dynamic>>>(),
          builder: (context, snapshot) {
            final byDay = snapshot.data ?? const <DateTime, List<dynamic>>{};
            final hasAny = byDay.values.any((l) => l.isNotEmpty);

            final gridView = GridView.builder(
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
                final isCurrentMonth = date.month == visibleMonth.month && date.year == visibleMonth.year;
                final dayKey = DateTime(date.year, date.month, date.day);
                final items = byDay[dayKey] ?? const [];

                // Map entries to accent colors for dot rendering
                final entriesWithColor = <({EntryRecord entry, Color color})>[];
                for (final rec in items.cast<EntryRecord>()) {
                  final kindId = rec.widgetKind;
                  final kind = registry.byId(kindId);
                  if (kind != null) {
                    entriesWithColor.add((entry: rec, color: kind.accentColor));
                  } else if (kindId == 'product') {
                    entriesWithColor.add((entry: rec, color: Colors.purple));
                  }
                }
                // Cap visible dots at 4
                final maxDots = 4;
                final visible = entriesWithColor.take(maxDots).toList();
                final overflow = (entriesWithColor.length - maxDots).clamp(0, 999);

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
                        ref.read(visibleMonthProvider.notifier).state = DateTime(date.year, date.month, 1);
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
                                    if (visible.isNotEmpty)
                                      Wrap(
                                        spacing: 2,
                                        runSpacing: 2,
                                        children: [
                                          for (final v in visible)
                                            GestureDetector(
                                              onTap: () {
                                                final e = v.entry;
                                                // Open editor directly for this entry
                                                if (e.widgetKind == 'protein') {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => ProteinEditorScreen(entryId: e.id)),
                                                  );
                                                } else if (e.widgetKind == 'fat') {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => FatEditorScreen(entryId: e.id)),
                                                  );
                                                } else if (e.widgetKind == 'carbohydrate') {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => CarbohydrateEditorScreen(entryId: e.id)),
                                                  );
                                                } else {
                                                  final k = registry.byId(e.widgetKind);
                                                  if (k != null) {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(builder: (_) => GenericNutrientEditorScreen(kind: k, entryId: e.id)),
                                                    );
                                                  }
                                                }
                                              },
                                              child: Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(color: v.color, shape: BoxShape.circle),
                                              ),
                                            ),
                                          if (overflow > 0)
                                            GestureDetector(
                                              onTap: () {
                                                // Select day to open Day Details
                                                ref.read(selectedDayProvider.notifier).state = DateTime(date.year, date.month, date.day);
                                              },
                                              child: Text('+$overflow', style: Theme.of(context).textTheme.labelSmall),
                                            ),
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
            if (!hasAny) {
              return Stack(
                children: [
                  gridView,
                  Center(
                    child: Text(
                      'No entries this month yet',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                  ),
                ],
              );
            } else {
              return gridView;
            }
          },
        );

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < 0) {
              _changeMonth(ref, visibleMonth, 1); // swipe left → next month
            } else if (v > 0) {
              _changeMonth(ref, visibleMonth, -1); // swipe right → previous month
            }
          },
          child: Column(
            children: [
              header,
              Expanded(child: gridWidget),
            ],
          ),
        );
      },
    );
  }
}

class _AdHocKind extends WidgetKind {
  const _AdHocKind({required this.id, required this.displayName, required this.icon, required this.accentColor, required this.unit, this.precision = 0, required this.minValue, required this.maxValue, required this.defaultShowInCalendar});
  @override
  final String id;
  @override
  final String displayName;
  @override
  final IconData icon;
  @override
  final Color accentColor;
  @override
  final String unit;
  @override
  final int precision;
  @override
  final int minValue;
  @override
  final int maxValue;
  @override
  final bool defaultShowInCalendar;
  @override
  List<CreateAction> createActions(BuildContext context, DateTime targetDate) => const [];
}

class CreateActionSheetContent extends ConsumerWidget {
  const CreateActionSheetContent({super.key, required this.items, required this.targetDate});
  final List<({WidgetKind kind, CreateAction action})> items;
  final DateTime targetDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsRepo = ref.watch(productsRepositoryProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add entry', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (productsRepo != null) ...[
                Text('Products', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                StreamBuilder(
                  stream: productsRepo.watchProducts(),
                  builder: (context, snapshot) {
                    final list = snapshot.data ?? const [];
                    if (list.isEmpty) {
                      return Text('No products yet', style: Theme.of(context).textTheme.bodySmall);
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in list)
                          _productChip(context, p.id, p.name, targetDate),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Divider(height: 16),
                const SizedBox(height: 8),
              ],
              // Recipes section
              Builder(builder: (ctx) {
                final recipesRepo = ref.watch(recipesRepositoryProvider);
                final recipeSvc = ref.watch(recipeServiceProvider);
                if (recipesRepo == null || recipeSvc == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recipes', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    StreamBuilder(
                      stream: recipesRepo.watchRecipes(),
                      builder: (context, snapshot) {
                        final list = snapshot.data ?? const [];
                        if (list.isEmpty) {
                          return Text('No recipes yet', style: Theme.of(context).textTheme.bodySmall);
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final r in list)
                              ActionChip(
                                label: Text(r.name),
                                avatar: const CircleAvatar(backgroundColor: Colors.brown, foregroundColor: Colors.white, child: Icon(Icons.restaurant_menu, size: 16)),
                                onPressed: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (ctx) => RecipeInstantiateDialog(recipeId: r.id, initialTarget: targetDate),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 16),
                    const SizedBox(height: 8),
                  ],
                );
              }),
              Text('Nutrients', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (ctx, cons) {
                  final width = cons.maxWidth;
                  final col = width >= 480 ? 4 : width >= 360 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: col,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.9,
                    ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final it = items[i];
                      final color = it.action.color ?? it.kind.accentColor;
                      return OutlinedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await it.action.run(context, targetDate);
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(it.action.icon, size: 18)),
                            const SizedBox(width: 12),
                            Expanded(child: Text('${it.kind.displayName}: ${it.action.label}', overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productChip(BuildContext context, String id, String name, DateTime targetDate) {
    return ActionChip(
      label: Text(name),
      avatar: const CircleAvatar(backgroundColor: Colors.purple, foregroundColor: Colors.white, child: Icon(Icons.shopping_basket, size: 16)),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductEditorScreen(productId: id, productName: name, defaultGrams: 100, initialTargetAt: targetDate),
          ),
        );
      },
    );
  }
}

Future<void> _showSideCreateActionSheet(BuildContext context, WidgetRef ref, DateTime targetDate, {required bool fromRight}) async {
  final registry = ref.read(widgetRegistryProvider);
  final items = registry.actionsForDate(context, targetDate);
  final ux = ref.read(uxConfigProvider);
  final cfg = ux.sideSheet;
  final size = MediaQuery.of(context).size;
  final bool isTablet = size.width >= 600;

  double base = size.width * cfg.widthFraction;
  double maxW = isTablet ? cfg.tabletMaxWidth : cfg.maxWidth;
  double width = base.clamp(cfg.minWidth, maxW);
  // Keep some margin to the far edge if possible
  final double maxAllowed = size.width - cfg.horizontalMargin;
  if (width > maxAllowed) width = maxAllowed;

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    pageBuilder: (ctx, _, _) {
      final begin = Offset(fromRight ? 1 : -1, 0);
      return Align(
        alignment: fromRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          elevation: 8,
          color: Theme.of(ctx).colorScheme.surface,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.max,
              children: [
                CreateActionSheetContent(items: items, targetDate: targetDate),
                // Tap any empty space inside the panel to close it
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(ctx).maybePop(),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      final tween = Tween<Offset>(begin: Offset(fromRight ? 1 : -1, 0), end: Offset.zero).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: anim.drive(tween), child: child);
    },
  );
}

Future<void> showCreateActionSheet(BuildContext context, WidgetRef ref, DateTime targetDate) async {
  final ux = ref.read(uxConfigProvider);
  final handed = ref.read(handednessProvider);

  ActionSheetPresentation mode = ux.actionSheetPresentation;
  if (mode == ActionSheetPresentation.auto) {
    final size = MediaQuery.of(context).size;
    mode = size.width >= 600 ? ActionSheetPresentation.side : ActionSheetPresentation.bottom;
  }

  if (mode == ActionSheetPresentation.bottom) {
    final registry = ref.read(widgetRegistryProvider);
    final items = registry.actionsForDate(context, targetDate);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => CreateActionSheetContent(items: items, targetDate: targetDate),
    );
    return;
  }

  // Side sheet: align with handedness. Right-handed → from right (LTR/RTL nuance optional).
  final textDir = Directionality.of(context);
  bool fromRight;
  if (handed == Handedness.right) {
    fromRight = true;
  } else {
    fromRight = false;
  }
  // If in RTL, you may want to flip for conventional expectations; we prioritize handedness per request.
  await _showSideCreateActionSheet(context, ref, targetDate, fromRight: fromRight);
}

class _DayDetailsPanel extends ConsumerWidget {
  const _DayDetailsPanel();

  String _productTitleFromPayload(EntryRecord e) {
    try {
      final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Product';
      final grams = (map['grams'] as num?)?.toInt();
      if (grams != null) {
        return '$name • $grams g';
      }
      return name;
    } catch (_) {
      return 'Product';
    }
  }

  String _recipeTitleFromPayload(EntryRecord e) {
    try {
      final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Recipe';
      return name;
    } catch (_) {
      return 'Recipe';
    }
  }

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
        final all = snapshot.data ?? const <EntryRecord>[];
        // Parents/standalone are entries without a source; children have a source_entry_id
        final entries = all.where((e) => e.sourceEntryId == null).toList();
        final childrenByParent = <String, List<EntryRecord>>{};
        for (final c in all) {
          if (c.sourceEntryId != null) {
            (childrenByParent[c.sourceEntryId!] ??= []).add(c);
          }
        }
        if (entries.isEmpty) {
          // Empty state: show date and a single Add button that opens the Create Action Sheet
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (ctx) {
                    final handed = ref.watch(handednessProvider);
                    final dateText = Expanded(
                      child: Text(
                        '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    );
                    final addBtn = IconButton(
                      tooltip: 'Add',
                      onPressed: () => showCreateActionSheet(context, ref, selected),
                      icon: const Icon(Icons.add_circle_outline),
                    );
                    return Row(
                      children: handed == Handedness.left
                          ? [addBtn, const SizedBox(width: 8), dateText]
                          : [dateText, addBtn],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'No entries for this day yet',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
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
              child: Builder(
                builder: (ctx) {
                  final handed = ref.watch(handednessProvider);
                  final dateText = Expanded(
                    child: Text(
                      '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                  final addBtn = IconButton(
                    tooltip: 'Add',
                    onPressed: () => showCreateActionSheet(context, ref, selected),
                    icon: const Icon(Icons.add_circle_outline),
                  );
                  return Row(
                    children: handed == Handedness.left
                        ? [addBtn, const SizedBox(width: 8), dateText]
                        : [dateText, addBtn],
                  );
                },
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
                  IconData icon;
                  Color bg;
                  if (e.widgetKind == 'product') {
                    icon = Icons.shopping_basket;
                    bg = Colors.purple;
                  } else if (e.widgetKind == 'recipe') {
                    icon = Icons.restaurant_menu;
                    bg = Colors.brown;
                  } else {
                    icon = kind?.icon ?? Icons.circle;
                    bg = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
                  }
                  final isRecipeParent = (e.widgetKind == 'recipe');
                  final isProductParent = (e.widgetKind == 'product');
                  final isParent = isRecipeParent || isProductParent;
                  // Derive short summary from payload
                  String summary = '';
                  try {
                    final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
                    final grams = (map['grams'] as num?)?.toInt();
                    if (grams != null) summary = '$grams g';
                  } catch (_) {}

                  final expandedSet = ref.watch(expandedProductsProvider);
                  final isExpanded = isParent && expandedSet.contains(e.id);
                  Widget parentRow = ListTile(
                    onTap: () {
                      if (isParent) {
                        final set = {...expandedSet};
                        if (isExpanded) {
                          set.remove(e.id);
                        } else {
                          set.add(e.id);
                        }
                        ref.read(expandedProductsProvider.notifier).state = set;
                        return;
                      }
                      // Open editor in edit mode based on kind id (non-parent)
                      if (e.widgetKind == 'protein') {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProteinEditorScreen(entryId: e.id)));
                      } else if (e.widgetKind == 'fat') {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => FatEditorScreen(entryId: e.id)));
                      } else if (e.widgetKind == 'carbohydrate') {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarbohydrateEditorScreen(entryId: e.id)));
                      } else {
                        final k = registry.byId(e.widgetKind);
                        if (k != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => GenericNutrientEditorScreen(kind: k, entryId: e.id)),
                          );
                        }
                      }
                    },
                    leading: CircleAvatar(
                      backgroundColor: bg,
                      foregroundColor: Colors.white,
                      child: Icon(icon, size: 18),
                    ),
                    title: Text(
                      isProductParent
                          ? _productTitleFromPayload(e)
                          : isRecipeParent
                              ? _recipeTitleFromPayload(e)
                              : '${kind?.displayName ?? e.widgetKind} • ${summary.isEmpty ? '—' : summary}',
                    ),
                    subtitle: Row(
                      children: [
                        Text(_fmtTime(localTime)),
                        if (!isProductParent && !e.showInCalendar) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.event_busy, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text('Hidden', style: Theme.of(context).textTheme.labelSmall),
                        ]
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isProductParent)
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProductEditorScreen(entryId: e.id),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete entry?'),
                                content: Text(isProductParent
                                    ? 'This will remove the product entry and its components. You can undo from the snackbar.'
                                    : 'This will remove the entry. You can undo from the snackbar.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                            if (isProductParent) {
                              // Capture data for undo before deleting
                              final original = e;
                              Map<String, Object?> parentPayload = const {};
                              String? productId;
                              int grams = 0;
                              bool staticFlag = false;
                              try {
                                final map = jsonDecode(original.payloadJson) as Map<String, dynamic>;
                                parentPayload = map;
                                productId = map['product_id'] as String?;
                                grams = (map['grams'] as num?)?.toInt() ?? 0;
                              } catch (_) {}
                              staticFlag = original.isStatic;
                              final targetLocal = DateTime.fromMillisecondsSinceEpoch(original.targetAt, isUtc: true).toLocal();
                              final service = ref.read(productServiceProvider);
                              await ref.read(entriesRepositoryProvider)!.deleteChildrenOfParent(original.id);
                              await repo.delete(original.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Product deleted'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () async {
                                      try {
                                        if (service != null && productId != null && grams > 0) {
                                          await service.createProductEntry(
                                            productId: productId,
                                            productGrams: grams,
                                            targetAtLocal: targetLocal,
                                            isStatic: staticFlag,
                                          );
                                        } else {
                                          // Fallback: recreate only the parent row
                                          await repo.create(
                                            widgetKind: original.widgetKind,
                                            targetAtLocal: targetLocal,
                                            payload: parentPayload,
                                            showInCalendar: original.showInCalendar,
                                            schemaVersion: original.schemaVersion,
                                          );
                                        }
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
                            } else if (isRecipeParent) {
                              // Snapshot overrides for Undo
                              String recipeId = '';
                              try {
                                final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
                                recipeId = (map['recipe_id'] as String?) ?? '';
                              } catch (_) {}
                              final kindOverrides = <String, double>{};
                              final productOverrides = <String, int>{};
                              final directChildren = childrenByParent[e.id] ?? const <EntryRecord>[];
                              for (final c in directChildren) {
                                if (c.widgetKind == 'product') {
                                  try {
                                    final pm = jsonDecode(c.payloadJson) as Map<String, dynamic>;
                                    final grams = (pm['grams'] as num?)?.toInt();
                                    if (grams != null) productOverrides[(pm['product_id'] as String?) ?? c.id] = grams;
                                  } catch (_) {}
                                  // Also delete grandchildren (nutrients under this product)
                                  await repo.deleteChildrenOfParent(c.id);
                                  await repo.delete(c.id);
                                } else {
                                  try {
                                    final km = jsonDecode(c.payloadJson) as Map<String, dynamic>;
                                    final amt = (km['amount'] as num?)?.toDouble();
                                    if (amt != null) kindOverrides[c.widgetKind] = amt;
                                  } catch (_) {}
                                  await repo.delete(c.id);
                                }
                              }
                              final targetLocal = DateTime.fromMillisecondsSinceEpoch(e.targetAt, isUtc: true).toLocal();
                              await repo.delete(e.id);
                              if (!context.mounted) return;
                              final recipeSvc = ref.read(recipeServiceProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Recipe deleted'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () async {
                                      try {
                                        if (recipeSvc != null && recipeId.isNotEmpty) {
                                          await recipeSvc.createRecipeEntry(
                                            recipeId: recipeId,
                                            targetAtLocal: targetLocal,
                                            kindOverrides: kindOverrides.isEmpty ? null : kindOverrides,
                                            productGramOverrides: productOverrides.isEmpty ? null : productOverrides,
                                            showParentInCalendar: true,
                                          );
                                        }
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
                            } else {
                              // Single entry delete with simple Undo
                              final original = e;
                              await repo.delete(e.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Entry deleted'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () async {
                                      final local = DateTime.fromMillisecondsSinceEpoch(original.targetAt, isUtc: true).toLocal();
                                      try {
                                        final payload = jsonDecode(original.payloadJson) as Map<String, Object?>;
                                        await repo.create(
                                          widgetKind: original.widgetKind,
                                          targetAtLocal: local,
                                          payload: payload,
                                          showInCalendar: original.showInCalendar,
                                          schemaVersion: original.schemaVersion,
                                        );
                                      } catch (_) {}
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        if (isProductParent)
                          IconButton(
                            tooltip: 'Edit components (make static)'.toString(),
                            icon: const Icon(Icons.tune),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InstanceComponentsEditorPage(parentEntryId: e.id),
                                ),
                              );
                            },
                          ),
                        if (isParent)
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 120),
                            child: const Icon(Icons.expand_more),
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                  );

                  if (!isParent || !isExpanded) {
                    return parentRow;
                  }
                  // Render expanded children under the parent
                  final children = childrenByParent[e.id] ?? const <EntryRecord>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      parentRow,
                      Padding(
                        padding: const EdgeInsets.only(left: 52, right: 8, bottom: 8),
                        child: Column(
                          children: [
                            for (final c in children)
                              if (c.widgetKind == 'product')
                                _NestedProductParentRow(entry: c, registry: registry, children: childrenByParent[c.id] ?? const <EntryRecord>[], expandedSet: ref.watch(expandedProductsProvider))
                              else
                                _ProductChildRow(entry: c, registry: registry),
                          ],
                        ),
                      ),
                    ],
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

class _NestedProductParentRow extends ConsumerWidget {
  const _NestedProductParentRow({required this.entry, required this.registry, required this.children, required this.expandedSet});
  final EntryRecord entry;
  final WidgetRegistry registry;
  final List<EntryRecord> children;
  final Set<String> expandedSet;
  String _productTitleFromPayload(EntryRecord e) {
    try {
      final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
      final name = (map['name'] as String?) ?? 'Product';
      final grams = (map['grams'] as num?)?.toInt();
      if (grams != null) {
        return '$name • $grams g';
      }
      return name;
    } catch (_) {
      return 'Product';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = expandedSet.contains(entry.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 0, right: 0),
          onTap: () {
            final set = {...expandedSet};
            if (isExpanded) {
              set.remove(entry.id);
            } else {
              set.add(entry.id);
            }
            ref.read(expandedProductsProvider.notifier).state = set;
          },
          leading: const CircleAvatar(backgroundColor: Colors.purple, foregroundColor: Colors.white, child: Icon(Icons.shopping_basket, size: 16)),
          title: Text(_productTitleFromPayload(entry)),
          trailing: AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 120),
            child: const Icon(Icons.expand_more),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 52, right: 8, bottom: 8),
            child: Column(
              children: [
                for (final c in children) _ProductChildRow(entry: c, registry: registry),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductChildRow extends ConsumerWidget {
  const _ProductChildRow({required this.entry, required this.registry});
  final EntryRecord entry;
  final WidgetRegistry registry;
  String _formatAmount(Map<String, dynamic> map) {
    int? amount = (map['amount'] as num?)?.toInt();
    final unitFromPayload = map['unit'] as String?; // optional
    if (amount == null) return '—';
    // Prefer payload precision if present; fall back to plain integer display
    final payloadPrecision = (map['precision'] as int?) ?? 0;
    int p = payloadPrecision;
    String fmt(int v) {
      if (p <= 0) return v.toString();
      final s = v.abs().toString().padLeft(p + 1, '0');
      final head = s.substring(0, s.length - p);
      final tail = s.substring(s.length - p);
      final sign = v < 0 ? '-' : '';
      return '$sign$head.$tail';
    }
    // derive a unit from kind registry when absent
    final kind = registry.byId(entry.widgetKind);
    final unit = unitFromPayload ?? kind?.unit ?? '';
    final text = fmt(amount);
    return unit.isEmpty ? text : '$text $unit';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = registry.byId(entry.widgetKind);
    final color = kind?.accentColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = kind?.icon ?? Icons.circle;
    String value = '—';
    try {
      final map = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
      value = _formatAmount(map);
    } catch (_) {}
    // Trim trailing zeros for doubles
    String _trimD(String s) => s.replaceFirst(RegExp(r'\.?0+\$'), '');
    value = _trimD(value);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon, size: 16)),
      title: Text(kind?.displayName ?? entry.widgetKind),
      trailing: Text(value, style: Theme.of(context).textTheme.bodyMedium),
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
    final mode = ref.watch(middleModeProvider);
    final content = mode == MiddleMode.search
        ? _SearchResults(controller: _scrollController)
        : MainActionsList(controller: _scrollController);

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
          IconButton(
            tooltip: 'Products',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductTemplatesPage()),
              );
            },
            icon: const Icon(Icons.shopping_basket_outlined),
          ),
          IconButton(
            tooltip: 'Kinds',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KindsPage()),
              );
            },
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Recipes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecipesPage()),
              );
            },
            icon: const Icon(Icons.restaurant_menu_outlined),
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
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'backup_single':
                  try {
                    final svc = ref.read(importExportServiceProvider);
                    if (svc == null) break;
                    final path = await svc.backupToFile();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved to ${path.split('/').last}')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                    }
                  }
                  break;
                case 'restore_single':
                  final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Restore backup?'),
                          content: const Text('This will wipe current data and restore from the single-slot backup.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Restore')),
                          ],
                        ),
                      ) ??
                      false;
                  if (confirm != true) return;
                  if (!context.mounted) return;
                  try {
                    final svc = ref.read(importExportServiceProvider);
                    if (svc == null) break;
                    final path = await svc.restoreFromFile();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored from ${path.split('/').last}')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                    }
                  }
                  break;
                case 'wipe_db':
                  final first = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Wipe database?'),
                          content: const Text('This will delete all local data and restart with bootstrap demo data.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue')),
                          ],
                        ),
                      ) ??
                      false;
                  if (first != true) return;
                  if (!context.mounted) return;
                  final second = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Are you absolutely sure?'),
                          content: const Text('Wiping the DB cannot be undone. Proceed?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes, wipe')),
                          ],
                        ),
                      ) ??
                      false;
                  if (second != true) return;
                  try {
                    await ref.read(dbHandleProvider.notifier).wipeDb();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database wiped')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to wipe DB: $e')));
                    }
                  }
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'backup_single', child: Text('Backup (single slot)')),
              PopupMenuItem(value: 'restore_single', child: Text('Restore (single slot)')),
              PopupMenuItem(value: 'wipe_db', child: Text('Wipe DB (temporary)')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.controller});
  final ScrollController controller;

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final q = ref.watch(searchQueryProvider);
    if (repo == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<EntryRecord>>(
      stream: repo.watchSearch(q),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const <EntryRecord>[];
        if (q.trim().isEmpty) {
          return const Center(child: Text('Type to search'));
        }
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No results for "$q"', style: Theme.of(context).textTheme.bodyMedium),
            ),
          );
        }
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final e = results[i];
            final kind = registry.byId(e.widgetKind);
            final color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
            final icon = kind?.icon ?? Icons.circle;
            // Basic summary from payload
            String summary = '';
            try {
              final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
              final grams = (map['grams'] as num?)?.toInt();
              if (grams != null) summary = '$grams g';
            } catch (_) {}
            final localTime = DateTime.fromMillisecondsSinceEpoch(e.targetAt, isUtc: true).toLocal();
            return ListTile(
              onTap: () {
                if (e.widgetKind == 'protein') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProteinEditorScreen(entryId: e.id)));
                } else if (e.widgetKind == 'fat') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => FatEditorScreen(entryId: e.id)));
                } else if (e.widgetKind == 'carbohydrate') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarbohydrateEditorScreen(entryId: e.id)));
                }
              },
              leading: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon, size: 18)),
              title: Text('${kind?.displayName ?? e.widgetKind} • ${summary.isEmpty ? '—' : summary}'),
              subtitle: Text('${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}  ${_fmtTime(localTime)}'),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        );
      },
    );
  }
}


class RecipeInstantiateDialog extends ConsumerStatefulWidget {
  const RecipeInstantiateDialog({super.key, required this.recipeId, required this.initialTarget});
  final String recipeId;
  final DateTime initialTarget;
  @override
  ConsumerState<RecipeInstantiateDialog> createState() => RecipeInstantiateDialogState();
}

class RecipeInstantiateDialogState extends ConsumerState<RecipeInstantiateDialog> {
  String _recipeName = '';
  DateTime _targetAt = DateTime.now();
  bool _loading = true;
  List<dynamic> _components = const [];
  final Map<String, TextEditingController> _kindCtrls = {};
  final Map<String, TextEditingController> _productCtrls = {};

  @override
  void initState() {
    super.initState();
    _targetAt = widget.initialTarget;
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(recipesRepositoryProvider);
    if (repo != null) {
      final def = await repo.getRecipe(widget.recipeId);
      final comps = await repo.getComponents(widget.recipeId);
      setState(() {
        _recipeName = def?.name ?? '';
        _components = comps;
        _loading = false;
      });
      for (final c in comps) {
        // type check via toString on enum field
        final typeStr = c.type.toString();
        if (typeStr.endsWith('kind')) {
          _kindCtrls[c.compId] = TextEditingController(text: _fmtD(c.amount ?? 0.0));
        } else {
          _productCtrls[c.compId] = TextEditingController(text: (c.grams ?? 0).toString());
        }
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final c in _kindCtrls.values) {
      c.dispose();
    }
    for (final c in _productCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtD(double v) {
    final s = v.toStringAsFixed(6);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_targetAt),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (time == null) return;
    setState(() {
      _targetAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(widgetRegistryProvider);
    return AlertDialog(
      title: Text('Instantiate: ${_recipeName.isEmpty ? widget.recipeId : _recipeName}'),
      content: _loading
          ? const SizedBox(width: 480, height: 120, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDateTime(context),
                      icon: const Icon(Icons.schedule),
                      label: Text(_targetAt.toLocal().toString()),
                    ),
                    const SizedBox(height: 12),
                    if (_components.isEmpty)
                      const Text('No components in this recipe yet')
                    else ...[
                      for (final c in _components)
                        Builder(builder: (ctx) {
                          final typeStr = c.type.toString();
                          if (typeStr.endsWith('kind')) {
                            final k = registry.byId(c.compId);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextField(
                                controller: _kindCtrls[c.compId],
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                decoration: InputDecoration(
                                  labelText: '${k?.displayName ?? c.compId} (${k?.unit ?? ''})',
                                ),
                              ),
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextField(
                                controller: _productCtrls[c.compId],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Product: ${c.compId} (grams)',
                                ),
                              ),
                            );
                          }
                        }),
                    ],
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final svc = ref.read(recipeServiceProvider);
            if (svc == null) return;
            final kindOverrides = <String, double>{};
            final productOverrides = <String, int>{};
            _kindCtrls.forEach((k, v) {
              final d = double.tryParse(v.text.trim());
              if (d != null) kindOverrides[k] = d;
            });
            _productCtrls.forEach((k, v) {
              final g = int.tryParse(v.text.trim());
              if (g != null) productOverrides[k] = g;
            });
            await svc.createRecipeEntry(
              recipeId: widget.recipeId,
              targetAtLocal: _targetAt,
              kindOverrides: kindOverrides.isEmpty ? null : kindOverrides,
              productGramOverrides: productOverrides.isEmpty ? null : productOverrides,
              showParentInCalendar: true,
            );
            if (mounted) Navigator.of(context).pop();
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

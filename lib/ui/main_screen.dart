import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'ux_config.dart';

// Handedness toggle for split-gesture control in the middle section.
enum Handedness { left, right }

final handednessProvider = StateProvider<Handedness>((_) => Handedness.left);

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

class _MonthGridDummyFit extends StatelessWidget {
  const _MonthGridDummyFit({required this.grid});
  final CalendarGridConfig grid;
  @override
  Widget build(BuildContext context) {
    // Fills the available section exactly (no scroll), computing aspect ratio
    // so [grid.columns] x [grid.rows] fit with padding and spacing.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - grid.padding * 2;
        final gridHeight = constraints.maxHeight - grid.padding * 2;
        if (gridWidth <= 0 || gridHeight <= grid.paintMinHeightPx) {
          // Avoid laying out text at extremely small sizes (Impeller glyph bounds errors).
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

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.all(grid.padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: grid.columns,
            mainAxisSpacing: grid.mainAxisSpacing,
            crossAxisSpacing: grid.crossAxisSpacing,
            childAspectRatio: aspect,
          ),
          itemCount: grid.columns * grid.rows + 1, // pad to a full grid
          itemBuilder: (_, i) => DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${i + 1}', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
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
                    child: _MonthGridDummyFit(grid: config.calendarGrid),
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
    final inactive = theme.colorScheme.onSurface.withOpacity(0.32);
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
    final content = ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      itemCount: 12, // reduce to 5 widgets
      itemBuilder: (_, i) => ListTile(
        title: Text('Widget #$i'),
        subtitle: const Text('Tap to open'),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Open widget #$i (demo)')),
          );
        },
      ),
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


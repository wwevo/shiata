import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ux_config.dart';
import 'calendar_sheet.dart';

// Hosts the top calendar sheet and overlaps it above the middle content using a Stack.
class TopSheetHost extends StatefulWidget {
  const TopSheetHost({super.key, required this.childBelow, required this.config});
  final Widget childBelow; // Middle panel under the sheet
  final UXConfig config;

  @override
  State<TopSheetHost> createState() => TopSheetHostState();
}

class TopSheetHostState extends State<TopSheetHost> with SingleTickerProviderStateMixin {
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
                child: CalendarSheet(
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

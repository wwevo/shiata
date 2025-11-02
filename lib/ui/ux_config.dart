import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized UX configuration for the main layout.
///
/// How to use
/// - Edit values below (or provide your own [UXConfig] via the provider) to tune
///   thresholds, sizes, durations, and haptics without touching UI code.
/// - All values have sensible defaults optimized for a smooth feel.
///
/// Groups and what they control
/// - topSheet: geometry of the collapsible top section (expanded/collapsed heights)
/// - thresholds: drag thresholds for staying open/closed
/// - animations: durations/curves for settle animations and base controller
/// - haptics: whether/when to fire haptics, and which type
/// - handle: handle visuals (touch area and the bar size changes past threshold)
/// - calendarGrid: layout padding/spacing/rows/columns and paint safety guards
/// - visuals: elevation and opacity ranges tied to expansion
/// - actionSheet: default layout mode (wrap/grid) and user preference persistence
/// - sideSheet: sizing constraints for side presentation
///
/// Notes
/// - Increasing [Thresholds.openKeepFraction] makes opening require a longer drag
///   (harder to open accidentally, better for quick peeks).
/// - Expanded/collapsed heights should leave the handle visible and tappable in
///   collapsed state.
/// - The grid safety guards avoid tiny text layouts that can trigger Impeller
///   glyph errors when the sheet is almost collapsed.
class UXConfig {
  const UXConfig({
    this.topSheet = const TopSheetConfig(),
    this.thresholds = const Thresholds(),
    this.animations = const AnimationsConfig(),
    this.haptics = const HapticsConfig(),
    this.handle = const HandleConfig(),
    this.calendarGrid = const CalendarGridConfig(),
    this.visuals = const VisualsConfig(),
    this.actionSheetPresentation = ActionSheetPresentation.side,
    this.sideSheet = const SideSheetConfig(),
    this.actionSheet = const ActionSheetConfig(),
  });

  final TopSheetConfig topSheet;
  final Thresholds thresholds;
  final AnimationsConfig animations;
  final HapticsConfig haptics;
  final HandleConfig handle;
  final CalendarGridConfig calendarGrid;
  final VisualsConfig visuals;
  final ActionSheetPresentation actionSheetPresentation;
  final SideSheetConfig sideSheet;
  final ActionSheetConfig actionSheet;

  UXConfig copyWith({
    TopSheetConfig? topSheet,
    Thresholds? thresholds,
    AnimationsConfig? animations,
    HapticsConfig? haptics,
    HandleConfig? handle,
    CalendarGridConfig? calendarGrid,
    VisualsConfig? visuals,
    ActionSheetPresentation? actionSheetPresentation,
    SideSheetConfig? sideSheet,
    ActionSheetConfig? actionSheet,
  }) {
    return UXConfig(
      topSheet: topSheet ?? this.topSheet,
      thresholds: thresholds ?? this.thresholds,
      animations: animations ?? this.animations,
      haptics: haptics ?? this.haptics,
      handle: handle ?? this.handle,
      calendarGrid: calendarGrid ?? this.calendarGrid,
      visuals: visuals ?? this.visuals,
      actionSheetPresentation: actionSheetPresentation ?? this.actionSheetPresentation,
      sideSheet: sideSheet ?? this.sideSheet,
      actionSheet: actionSheet ?? this.actionSheet,
    );
  }
}

class TopSheetConfig {
  const TopSheetConfig({
    this.expandedHeight = 420.0,
    this.collapsedHeight = 24.0,
  });
  final double expandedHeight; // full calendar height
  final double collapsedHeight; // visible handle area height
}

class Thresholds {
  const Thresholds({
    this.openKeepFraction = 0.75,
    this.paintVisibleMinT = 0.06, // below this, we stop painting the grid
  });
  /// Fraction (0..1). On release, if current expansion >= this threshold,
  /// the sheet completes opening; otherwise collapses.
  final double openKeepFraction;
  /// Minimum t at which the calendar grid will still paint.
  final double paintVisibleMinT;
}

class AnimationsConfig {
  const AnimationsConfig({
    this.controllerBaseDuration = const Duration(milliseconds: 220),
    this.settleOpenDuration = const Duration(milliseconds: 120),
    this.settleCloseDuration = const Duration(milliseconds: 160),
    this.expandCurve = Curves.easeOut,
    this.collapseCurve = Curves.easeOut,
  });
  final Duration controllerBaseDuration; // used by the core AnimationController
  final Duration settleOpenDuration; // small finish to 1.0 when threshold passed
  final Duration settleCloseDuration; // finish to 0.0 when threshold not reached
  final Curve expandCurve;
  final Curve collapseCurve;
}

class HapticsConfig {
  const HapticsConfig({
    this.enableThresholdHaptic = true,
    this.onDownwardCrossing = HapticType.selectionClick,
    this.fireOnUpwardOnly = true,
  });
  final bool enableThresholdHaptic;
  final HapticType onDownwardCrossing;
  /// If true, fire only when crossing upward (below->above threshold). If false,
  /// also fire on the way back down.
  final bool fireOnUpwardOnly;
}

enum HapticType { selectionClick, lightImpact, mediumImpact, heavyImpact }

class HandleConfig {
  const HandleConfig({
    this.touchAreaHeight = 24.0, // full tap target height at the bottom of sheet
    this.barHeight = 4.0, // the small visual bar height
    this.barWidthInactive = 36.0,
    this.barWidthActive = 44.0, // grows past threshold while dragging
  });
  final double touchAreaHeight;
  final double barHeight;
  final double barWidthInactive;
  final double barWidthActive;
}

class CalendarGridConfig {
  const CalendarGridConfig({
    this.padding = 0.0,
    this.crossAxisSpacing = 4.0,
    this.mainAxisSpacing = 4.0,
    this.columns = 7,
    this.rows = 6,
    this.paintMinHeightPx = 40.0, // below this skip painting
    this.paintMinCellPx = 6.0, // below this skip painting
  });
  final double padding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final int columns;
  final int rows;
  final double paintMinHeightPx;
  final double paintMinCellPx;
}

class VisualsConfig {
  const VisualsConfig({
    this.elevationCollapsed = 0.0,
    this.elevationExpanded = 6.0,
    this.opacityCurve = Curves.easeInOut,
  });
  final double elevationCollapsed;
  final double elevationExpanded;
  final Curve opacityCurve;
}

/// Sizing configuration for the side action sheet.
class SideSheetConfig {
  const SideSheetConfig({
    this.minWidth = 320.0,
    this.maxWidth = 420.0,
    this.tabletMaxWidth = 520.0,
    this.widthFraction = 0.86, // fraction of screen width (phones)
    this.horizontalMargin = 16.0, // ensure some margin from the edge on small screens
  });

  /// Minimum panel width regardless of screen size.
  final double minWidth;

  /// Maximum panel width on phones/compact screens.
  final double maxWidth;

  /// Maximum panel width on tablets/large screens (>= 600dp).
  final double tabletMaxWidth;

  /// Fraction of the available width to use as a base before clamping.
  final double widthFraction;

  /// Minimal margin to keep between the panel and the opposite edge.
  final double horizontalMargin;
}

/// Configuration for the action sheet content layout and behavior.
class ActionSheetConfig {
  const ActionSheetConfig({
    this.defaultLayout = SectionLayout.wrap,
    this.rememberUserChoice = true,
  });

  /// Default layout mode for sections (wrap or grid).
  final SectionLayout defaultLayout;

  /// Whether to remember the user's layout choice across sessions.
  /// If false, always starts with [defaultLayout].
  final bool rememberUserChoice;
}

/// Layout modes for action sheet sections.
enum SectionLayout {
  /// Flexible wrap layout that adapts to content (default).
  wrap,
  /// Fixed grid layout with responsive columns.
  grid,
}

/// Provider for the UX configuration. Override this at a scope if you want to
/// A/B test or device-tune values.
final uxConfigProvider = Provider<UXConfig>((ref) => const UXConfig());

/// Presentation options for the Create Action Sheet (CAS).
enum ActionSheetPresentation {
  /// Classic bottom sheet using `showModalBottomSheet`.
  bottom,
  /// Side sheet sliding from the left/right edge (default), width-constrained.
  side,
  /// Pick automatically based on size class (phones bottom, tablets side).
  auto,
}

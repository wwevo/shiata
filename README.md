# shiata

Superior health insights and tracking app

## UX Configuration Outline

This app’s layout/interaction is driven by a centralized configuration in `lib/ui/ux_config.dart`. All knobs are grouped and documented for fast tuning without touching UI code. The `uxConfigProvider` (Riverpod) exposes the active config, so you can override it or A/B test presets.

- TopSheetConfig
  - `expandedHeight` / `collapsedHeight`: Sizes of the top calendar section. Bigger expanded improves legibility; keep collapsed ≥ handle touch target for accessibility.
- Thresholds
  - `openKeepFraction` (default 0.75): Fraction of reveal required to keep the sheet open on release. Higher → easier peeking, harder accidental opens.
  - `paintVisibleMinT` (default 0.06): Below this, the calendar grid stops painting to prevent tiny text/GPU issues while retaining state.
- AnimationsConfig
  - `controllerBaseDuration`: Base duration for the internal controller (applies to programmatic anims; direct drags override).
  - `settleOpenDuration` / `settleCloseDuration`: Snap durations after finger release.
  - `expandCurve` / `collapseCurve`: Easing for the final settle.
- HapticsConfig
  - `enableThresholdHaptic`: Master toggle.
  - `onDownwardCrossing`: Haptic type (`selectionClick`, `lightImpact`, `mediumImpact`, `heavyImpact`).
  - `fireOnUpwardOnly`: If false, also ticks when crossing back below the threshold.
- HandleConfig
  - `touchAreaHeight`: Height of the tap target at the bottom of the sheet.
  - `barHeight`, `barWidthInactive`, `barWidthActive`: Small handle bar visuals; grows/tints when past threshold during drag.
- CalendarGridConfig
  - `padding`, `crossAxisSpacing`, `mainAxisSpacing`, `columns`, `rows`: Grid layout to exactly fill the allocated height; no scroll inside.
  - `paintMinHeightPx`, `paintMinCellPx`: Safety guards to avoid painting degenerate glyph sizes.
- VisualsConfig
  - `elevationCollapsed` / `elevationExpanded`: Surface lift as it opens.
  - `opacityCurve`: Opacity ease for the calendar content.

### Where to tweak
- Edit `lib/ui/ux_config.dart` (or override via `uxConfigProvider`) to adjust thresholds, haptics, durations, sizes, and curves. No UI code changes needed.

### Usage examples
- Make opening easier: set `openKeepFraction` to `0.70`.
- Turn off the haptic: set `enableThresholdHaptic` to `false`.
- More pronounced handle change: increase `barWidthActive`.
- Denser calendar grid: reduce `padding` or spacing, or increase `rows`.

### Architecture recap (context)
- Top section (calendar) overlaps Middle via `Stack` + `Positioned`, never unmounts; slider-style drag with a 75% open threshold, handle tint on crossing, optional haptic.
- Middle section uses a transparent 50/50 overlay: one half captures vertical drags for the top sheet (left/right handed), the other passes through for scrolling/taps.
- Bottom section is a fixed `BottomAppBar` for search and context actions.
- State: Riverpod; `uxConfigProvider` provides UX knobs across the UI.

### Phase Two preview
- Middle modes: `MainList`, `WidgetDetail(widgetId)`, `SearchResults(query)`.
- Keep the top sheet mounted; switch/push the Middle content. If multiple widgets on a day, show a small chooser.
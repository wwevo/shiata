
```
## [0.1.0] - 2025-10-25
### Added
- Centralized UX configuration in `lib/ui/ux_config.dart` with Riverpod provider `uxConfigProvider`.
  - Knobs grouped as: TopSheetConfig, Thresholds, AnimationsConfig, HapticsConfig, HandleConfig, CalendarGridConfig, VisualsConfig.
- Top calendar “top sheet” implemented as an overlapping layer (`Stack` + `Positioned`).
  - Slider-style interaction: direct, continuous drag (peekable); no velocity dependence.
  - Open threshold set to 75% (`openKeepFraction`); release keeps it open only past threshold.
  - Handle guidance: tint/width change when past threshold; optional haptic feedback on first upward crossing.
- Middle section input model: transparent 50/50 overlay.
  - One half captures vertical drags to control the top sheet; the other passes through for normal scrolling/taps.
  - Left/right-handed mode toggle.
- Calendar grid sized to fully fit the top section; no internal scroll; exact aspect computation.
- Material 3 theming enabled; app wrapped in `ProviderScope`.

### Changed
- `MainScreen` refactored to consume `UXConfig` (heights, thresholds, curves, elevation, etc.).
- `BottomControls` provides search input + handedness toggle.

### Fixed
- Guarded against redundant re-open/close animations at bounds.
- Prevented Impeller glyph errors during collapse by clipping/scaling content and avoiding tiny text painting (`ClipRect`/`Align(heightFactor)` + visibility threshold and size guards).
- Android emulator desktop/freeform caption bar overlap prevented by opting out of freeform: `android:resizeableActivity="false"`. Also wrapped `Scaffold.body` in `SafeArea(top: true, bottom: false)` to respect top insets.

### Dependencies
- Added `flutter_riverpod` for lightweight, granular state management.

### Notes
- The top sheet remains mounted at all times; no loading spinners.
- All motion and visuals are driven by a single controller value `t ∈ [0..1]` for smoothness.
- Next phase: Middle-section navigation modes (`MainList`, `WidgetDetail(widgetId)`, `SearchResults(query)`); calendar day taps open widget detail (chooser if multiple entries).
```
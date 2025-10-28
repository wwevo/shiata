
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

```
## [0.1.9] - 2025-10-28
### Added
- Real month calendar in the collapsible top sheet with stacked dot indicators per day (colored by widget kind; overflow as +N).
- Day selection + Day Details panel under the calendar:
  - Streams entries for the selected date (sorted by time, then widget).
  - Tap an item to open the correct editor in edit mode.
  - Empty-day state offers temporary Add actions (Protein/Fat) prefilled for the selected date.
- Two demo widgets with shared base mechanics:
  - Protein (indigo) — integer grams (0–300), minute-precision timestamp, "Show in calendar" toggle.
  - Fat (yellow) — same behavior for multi-kind validation.
- Create/Edit editors for Protein and Fat:
  - Create mode (optional `initialTargetAt` prefill from the Day Details selection).
  - Edit mode by `entryId`; Save updates existing rows.
- Entries repository + schema (Drift, single `entries` table):
  - Fields: `id`, `widget_kind`, `created_at`, `target_at`, `payload_json`, `schema_version`, `show_in_calendar`, `updated_at`, provenance (`source_event_id`, `source_entry_id`, `source_widget_kind`).
  - Streams: `watchByDay`, `watchByDayRange` to power Day Details and calendar indicators.
- Widget framework scaffolding: `WidgetKind`, `WidgetRegistry`, and `CreateAction` (initial actions per kind).
- Central UX configuration in `ux_config.dart` for top sheet geometry, thresholds, animations, grid layout, visuals.

### Changed
- Home cards (Protein/Fat) open Create editors directly (instead of placeholders).
- Top sheet behavior refined to avoid overflow during expand/collapse; tapped day is highlighted.

### Fixed
- Calendar duplicate-day (DST/localtime) by iterating grid cells in UTC, converting per-cell to local.
- Eliminated tiny-layout overflows in calendar cells via minimum paint guards + wrapped dot layout.
- First-insert race (table not yet created) — repository now awaits DB initialization before all ops.

### Deferred
- At-rest DB encryption (SQLCipher) postponed to a later phase; current builds use unencrypted sqlite3 FFI with the same repo API to enable a later drop-in encryption change.

### Dev / Tooling / Docs
- Lifecycle: DB open on resume, close on pause/detached; reduced noisy open/close logs on desktop.
- `IMPLEMENTATION.md` created; will expand alongside the Create Action Sheet and (later) SQLCipher re-introduction.
```

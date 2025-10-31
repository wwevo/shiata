# CHANGELOG.md
## [0.4.0] - 2025-10-31
### Added
- Database-backed Kinds with live `WidgetRegistry` (no hardcoded seeds at runtime).
- Kinds Manager UI (list/create/edit/delete) with unit picker, min/max, icon/color fields.
- Safe Kind deletion with usage-aware dialog and Undo:
  - Remove from product templates and update existing entries.
  - Delete direct calendar instances of the kind.
- Import/Export v1 (JSON) now includes `entries` alongside `kinds` and `products`.
- One‑tap backup/restore (single slot) stored as `backup.json` in the app documents folder.
- Temporary "Wipe DB" action (debug/dev) to reset local database.

### Changed
- App now boots with DB-driven kinds/products only. Demo bootstrap runs once on fresh, empty tables; existing data is never overwritten.
- `widgetRegistryProvider` builds from DB kinds via `DbBackedKind` adapter.
- Import is intentionally destructive by design (per request): it wipes current data before applying the bundle.

### Implementation
- New services/repo helpers:
  - `KindsRepository`, `ProductsRepository`, `EntriesRepository` expanded for dump/import and usage checks.
  - `KindService` orchestrates deletion + Undo and re-propagation of affected products.
  - `ImportExportService` exports/imports bundles and provides single-slot backup/restore.
- DB lifecycle handled by `DbLifecycleObserver` + `DbHandle`; added helper to resolve DB path for wipe/backup.

### Notes
- Icon name resolution has safe fallbacks; unknown names fall back to a generic icon.
- All nutrient values are integers; units are canonical (`g`, `mg`, `ug`, `mL`).

## [0.3.0] - 2025-10-29
### Added
- Product templates page (basket icon) with CRUD for products and per‑100g integer components.
- Dynamic Products section in CAS (side sheet) sourced from repository; newly created products appear instantly.
- Product instantiation flow: parent (visible, purple) + denormalized child nutrients (hidden in calendar by default) using integer math `amount = (per100g × grams) / 100`.
- Day Details composition view: expandable product parents list composed nutrients with icons, colors, units.
- Product parent editing (grams, Static) recalculates children immediately.
- Template‑change propagation (non‑static instances only) with confirmation and Undo (restores prior component set and re‑propagates).
- Per‑instance component overrides from Day Details (“Edit components (Static)”) that mark the instance Static and update only that instance’s child amounts.
- Product template delete → converts existing instances: removes parent rows, keeps nutrient children as standalone entries and sets them visible in the calendar.

### Changed
- CAS: Products shown first and populated dynamically; Nutrients retain the generic editor flow. Side‑sheet behaviors (width, handedness) preserved.
- Product editor titles corrected (no more “null — Add”).

### Fixed
- Product Template Editor list padded so the Add FAB no longer covers the last row.
- Undo for product parent delete now restores all children correctly.

## [0.2.0] - 2025-10-29
### Added
- Third basic kind: Carbohydrate (red). Full create/edit flow mirroring Protein/Fat.
- Create Action Sheet (CAS) side-sheet presentation by default, configurable via `UXConfig.actionSheetPresentation`.
- Handedness-aware Add button placement in Day Details header (left/right), and CAS opens from the same side for spatial consistency.
- Calendar month navigation: header with Previous/Next buttons and horizontal swipe gestures.
- Day Details: delete icon per entry with confirmation dialog and Undo via `SnackBar`.
- Simple Search page: bottom search field switches middle section to live results (`watchSearch(q)`), opening the correct editor on tap.
- Middle section now registry-driven and scalable: dynamically renders one card per `WidgetKind` and triggers the primary action for the selected day.

### Changed
- Always-selected day policy: if no prior selection, today is selected by default so the Day Details header (with Add) is always available.
- CAS content refactored into `CreateActionSheetContent` for reuse between bottom and side presentations.
- Side-sheet width tuned for phones/tablets with `SideSheetConfig` (min/max/fraction, tablet max, horizontal margin). Added ability to close by tapping empty space inside the panel.

### Fixed
- Riverpod initialization side-effect: stopped mutating providers during provider initialization (removed cross-write from `selectedDayProvider` init). Resolves `StateNotifierListenerError` about modifying providers during build.

### Deferred
- At-rest DB encryption (SQLCipher) remains postponed to a later phase; repository API unchanged to enable drop-in later.

### Dev / Tooling / Docs
- Extracted the dynamic middle list to `lib/ui/main_actions_list.dart` for better modularity.
- Updated README and IMPLEMENTATION notes to reflect new UX options and flows.

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


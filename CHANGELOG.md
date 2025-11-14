# CHANGELOG.md

## [0.6.7] - 2025-11-14
### Added
- **Weekly Overview Panel**: New 7-day summary view with pie chart and entry list
  - Filter chips to select which nutrient kinds appear in pie chart
  - Pie chart shows aggregated values for selected nutrients over last 7 days (including today)
  - Scrollable list of all entries from last 7 days with proper product/recipe names
  - Smart date range handling (includes entries from today)
- **Section-based navigation**: Complete redesign of app navigation architecture
  - Calendar, Products, Kinds, and Recipes are now sections instead of stacked pages
  - Instant section switching with no navigation stack buildup
  - Bottom toolbar always visible across all sections
- **Smart Calendar/Overview toggle**: First button in bottom bar now context-aware
  - When in calendar section: toggles between overview and calendar views
  - When in other sections: returns to calendar section (remembers last view mode)
- **Save & Close buttons**: Edit dialogs now offer two save options
  - "Save": saves changes but keeps dialog open for multiple edits
  - "Save & Close": saves changes and closes the dialog
  - Applied to both kind and product instance editors

### Changed
- **List styles standardized**: Products and Recipes pages now match Kinds page design
  - Card wrapper with consistent spacing
  - Leading CircleAvatar icons (purple basket for products, brown menu for recipes)
  - Non-clickable list items with explicit Edit/Delete buttons
  - ListView.builder instead of ListView.separated
- **Search functionality restored**: Works in both overview and calendar modes
  - Proper product/recipe name extraction from JSON payload
  - Shows in calendar view when user types in search field
- **Pie chart units**: Now displays correct units (mg, ug, g) instead of hardcoded 'g'
  - Extracts unit from kind metadata

### Fixed
- Products and recipes now show actual names in all lists (weekly overview, search results, day details)
- Filter chips in weekly overview now properly update pie chart when toggled
- Date range calculation includes today's entries (previously only showed yesterday and before)
- Bottom navigation bar visible on all pages instead of just main screen

### Technical
- Added `AppSection` enum (calendar, products, kinds, recipes) for section-based navigation
- Added `currentSectionProvider` for tracking active section
- Removed duplicate Scaffold wrappers that caused navigation stack buildup
- BottomControls now uses section state instead of Navigator.push
- Added `fl_chart` dependency (^0.69.0) for pie chart visualization
- ViewMode provider persists between section switches

---

## [0.5.5] - 2025-11-14
### Changed
- Harmonized all 7 dialog editors to consistent code style:
  - Standardized helper method names: `_fmtDouble` (no abbreviations like `_fmtD` or inline `fmt`).
  - Added structure comments (`// Helper methods`, `// State variables`) to all dialogs.
  - Unified DateTime label format: `Text('${_targetAt.toLocal()}')`.
  - Improved mounted checks after async operations.
  - Consistent method ordering across all dialog editors.

---

## [0.5.1] - 2025-11-02
### Added
- `kinds.json` and `products.json` seed files to bootstrap DB with initial data on fresh installations.

---

## [0.5.0] - 2025-11-02
### Added
- Doubles-based amounts everywhere (no fixed-point scaling):
    - Direct entries and product children store `amount` as double.
    - Product components `amount_per_gram` now REAL (double); math uses `amount = per100 × grams / 100`.
- Recipes (templates) with mixed components:
    - `recipes` + `recipe_components` tables.
    - Recipes can include Kinds (double amounts) and Products (grams int).
    - CAS integration: Recipe section.
    - Instantiation dialog: set date/time and per-component overrides; creates a static recipe parent.
- Day Details nesting for any parent:
    - Recipes display as parents; expanding reveals kind children and nested product parents (which expand to their nutrient children).
- Delete + Undo (Recipes):
    - Deleting a recipe instance removes the parent and children; UNDO restores the full instance (parent, kind children, nested product parents, and their children).

##### Changed
- Editors and displays accept and render decimal values; trimming of trailing zeros in UI.
- Product instance recomputation uses doubles consistently.

##### Fixed
- Recipe component saving (SQL string literal quoting for `type`).
- Recipe instantiation dialog build errors (constructor/state wiring).
- Several `use_build_context_synchronously` lints guarded.

##### Known gaps / not completed
- Precision model not fully purged from code/schema:
    - `kinds.precision` column and `WidgetKind.precision` remain; some UI still shows a precision selector—should be removed.
    - Some older code paths still try to read/write `precision` in payloads (e.g., `payloadPrecision` reference appeared during migration). These should be deleted.
- Decimal UX inconsistencies previously observed (values flipping 6 ↔ 0.06) were addressed by moving to doubles, but all editors should be retested end-to-end; any lingering scaler logic must be removed.
- Automated tests not delivered:
    - Missing repo tests for Kinds/Products/Entries/Recipes.
    - Missing service tests (ProductService, KindService, RecipeService) including propagate/update/undo scenarios.
    - No import/export/backup round‑trip test.
- Import/Export bundle remains at version 1 conceptually; no explicit v2 schema for recipes documented. JSON includes entries but recipes export/import scaffolding may be incomplete depending on the path you used.
- Documentation not updated for 0.5.0 (README/IMPLEMENTATION/CHANGELOG still reflect 0.4.0 as latest release).
- Analyzer hygiene: a full `flutter analyze` pass and cleanup wasn’t completed after all recipe and doubles changes.
- Instantiation polish: no servings field; only per-component overrides; advanced "flairs" feature not implemented.

##### Migration/compat
- Existing integer data remains valid; SQLite treats ints as numeric. New writes use doubles for amounts and product component coefficients.

---

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

---

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

---

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

---

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

---

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


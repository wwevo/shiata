# shiata

Superior health insights and tracking app

## What's new in 0.5.5

### Code Quality Improvements
- **Harmonized Dialog Editors**: All 7 dialog editors now follow a consistent code style:
  - Standardized method naming (`_fmtDouble`, `_parseDouble`)
  - Clear code organization with structure comments
  - Unified DateTime formatting
  - Consistent state management patterns
  - Same method ordering across all dialogs

This makes the codebase easier to maintain and understand - all editors feel like they're "from the same developer."

## What's new in 0.5.0

### Doubles-Based Amounts
- All nutrient amounts now use doubles (no fixed-point scaling)
- Direct entries and product children store `amount` as double
- Product components use `amount_per_gram` (REAL/double)
- Math: `amount = (per100 × grams) / 100`

### Recipes (Templates)
- New `recipes` + `recipe_components` tables
- Recipes can include:
  - **Kinds** (with double amounts)
  - **Products** (with gram amounts as integers)
- CAS integration: new Recipe section
- **Instantiation Dialog**: Set date/time and per-component overrides; creates a static recipe parent

### Day Details Nesting
- Recipes display as parents in Day Details
- Expanding reveals:
  - Kind children (direct nutrients)
  - Nested product parents (which expand to their nutrient children)

### Delete + Undo (Recipes)
- Deleting a recipe instance removes the parent and all children
- **UNDO** restores the full instance (parent, kind children, nested product parents, and their children)

### Changed
- Editors accept and render decimal values
- Trailing zeros trimmed in UI
- Product instance recomputation uses doubles consistently

### Known Gaps
- Precision model not fully purged (some `precision` fields/UI remain)
- Automated tests not yet delivered
- Documentation being updated

## What's new in 0.4.0
- Database-backed Kinds; dynamic `WidgetRegistry` sourced from DB (no hardcoded seeds at runtime).
- Kinds Manager (list/create/edit/delete) with unit picker, min/max, icon/color, default calendar visibility.
- Safe Kind deletion with usage-aware dialog and Undo (removes from templates and/or deletes direct instances).
- Import/Export v1 bundle now includes `entries` in addition to `kinds` and `products`.
- One‑tap Backup/Restore (single slot): writes/reads `backup.json` in the app documents folder.
- Temporary “Wipe DB” action in the bottom bar More (⋮) menu (for testing).

### Managing kinds and products
- Kinds: Bottom bar → Kinds → “+” to create. Fields: id, name, unit (`g`,`mg`,`ug`,`mL`), min/max (integers), optional icon name and ARGB color, default Show in calendar.
- Products: Bottom bar → Products → “+” to create → add components (per‑100g integer coefficients) using existing kinds.
- CAS/Create: Once at least one kind exists, use the Add button to create direct nutrient entries or instantiate a product.

### Backup and Restore (single slot)
- Bottom bar → More (⋮) → Backup (single slot): saves a full JSON bundle (kinds, products, components, entries) to `backup.json` in the app’s documents directory.
- Bottom bar → More (⋮) → Restore (single slot): wipes current data and restores from `backup.json`.

### Import and Export (JSON)
- Kinds/Products pages have an AppBar menu with Export/Import.
- Export shows a pretty‑printed JSON bundle (version 1) that you can copy to clipboard.
- Import is destructive by design: it wipes existing data, then imports `kinds` → `products`+`components` → `entries`.

### Wipe DB (temporary)
- Bottom bar → More (⋮) → Wipe DB (temporary). Deletes the local DB file and reboots with demo bootstrap if tables are empty. Intended for testing only.

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

## What’s new in 0.3.0
- Product templates (CRUD) with per‑100g integer components; Products page (basket icon).
- Dynamic Products section in CAS; create instances from templates; day‑details expansion shows composed nutrients.
- Edit product instances (grams, Static), delete with Undo; template‑change propagation for non‑static instances with Undo; per‑instance overrides (make Static).
- Template deletion converts instances: removes parents, keeps child nutrients visible.

## What’s new in 0.2.0
- Three macronutrient kinds are available: Protein (indigo), Fat (amber), Carbohydrate (red).
- Create/Edit editors for each kind with grams, date/time picker, and "Show in calendar" toggle.
- Create Action Sheet (CAS) now defaults to a side sheet that slides in from the same side as the Add button (handedness‑aware). Bottom sheet remains available.
- Calendar is navigable via header arrows and horizontal swipes.
- Day Details supports deletion with confirmation and an Undo snackbar.
- Simple search: type in the bottom field to see live results; tap to open the correct editor.
- Middle section list is generated from the `WidgetRegistry` and launches the primary action for each kind.

## New UX config options (0.2.0)
- `ActionSheetPresentation` (in `ux_config.dart`):
  - `bottom` | `side` (default) | `auto` (phones bottom, tablets side).
- `SideSheetConfig` (in `ux_config.dart`):
  - `minWidth`, `maxWidth`, `tabletMaxWidth`: clamp panel width per device size.
  - `widthFraction`: base fraction of screen width (phones) before clamping.
  - `horizontalMargin`: keeps a margin to the far edge on compact screens.

### Example: forcing bottom sheet temporarily
```dart
final ux = const UXConfig(
  actionSheetPresentation: ActionSheetPresentation.bottom,
);
```

### Example: tuning side sheet width
```dart
final ux = const UXConfig(
  actionSheetPresentation: ActionSheetPresentation.side,
  sideSheet: SideSheetConfig(
    minWidth: 320,
    maxWidth: 440,
    tabletMaxWidth: 560,
    widthFraction: 0.88,
    horizontalMargin: 16,
  ),
);
```

### Handedness
- The Add button in Day Details appears on the left for left‑handed mode and on the right for right‑handed. Use the existing toggle in the bottom bar to switch. The side CAS opens from the same side for spatial consistency.
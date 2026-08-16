### Changelog

#### [0.9.5] – 2026-08-16
##### Changed
- Pie chart layout refined for better use of space.

---
#### [0.9.4] – 2026-08-16
##### Added
- Unified Seven‑Day view replacing separate Calendar and Overview pages.

##### Changed
- Calendar shows a compact single‑row weekly strip.
- Weekly Overview displays the current calendar week (Mon–Sun).
- Navigation simplified with fewer, evenly spaced bottom buttons; Calendar and Overview merged into Seven‑Day.
- Seven‑Day chips drive the visible item list; include/exclude filters (WIP).

##### Removed
- Handedness UI and logic.
- Legacy migration artifacts and old `recipe_id` payload fallback.

---
#### [0.9.3] – 2026-08-09
##### Changed
- Bottom bar spacing unified.
- Kinds/Products/Recipes lists now stream directly from repositories.

##### Removed
- Global Search (service and UI integrations).

---
#### [0.9.2] – 2026-04-16
##### Changed
- Editors allow changing IDs for recipes, kinds, and products.
- Terminology: “nutrient” renamed to “kind” across the app.
- Kind/Product dropdowns unified across dialogs for consistent UX.

---
#### [0.9.1] – 2026-04-15
##### Added
- Data model: `is_protected` flag and `units` table; updated Kind/Product/Recipe models.
- Shared `EditorDialogShell` with consistent validation and loading/saving states.
- Template editors: icon/color fields, dynamic unit dropdown, `showInCalendar` toggle.

---
#### [0.9.0] – 2026-04-14
##### Fixed
- Template propagation dialog appears only when instances exist.
- Product lists update correctly after create/update/delete.
- Editors accept dot/comma for fraction input.

##### Changed
- Deletions are now permanent with confirmation (UNDO removed).

##### Migration/Schema
- Automatic DB migration on app start; backward‑compatible with old backups.

---
#### [0.8.8] – 2025-11-18
##### Added
- Central `ValidationRules` for editor dialogs and persistent inline error UI.

##### Changed
- All editor dialogs use dual‑layer validation (UI + Repository); repository errors shown inline.

##### Removed
- UNDO snackbar flows from product and recipe template editors (use confirmations instead).

---
#### [0.8.7] – 2025-11-18
##### Added
- Repository‑level input validation for kinds, products, recipes, and entries.
- Referential integrity checks prevent deleting kinds/products used by entries.

---
#### [0.8.6] – 2025-11-18
##### Added
- Validation test suite documenting expected error handling and edge cases.

---
#### [0.8.5] – 2025-11-18
##### Fixed
- Recipe template summaries now update reactively after component changes.

##### Added
- `watchComponents(recipeId)` stream for live recipe component updates.

---
#### [0.8.4] – 2025-11-18
##### Added
- “All Entries” page: filtering, sorting, selection, bulk delete, and expand/collapse hierarchy.
- Repository streams for all entries with children to power reactive hierarchical lists.

##### Changed
- Database page made fully reactive; expand works across full hierarchy.

##### Fixed
- Database and All Entries lists update reliably on create/update/delete.

---
#### [0.8.3] – 2025-11-17
##### Added
- Checkbox selection mode for lists and fine‑grained export with auto‑dependency selection.

##### Changed
- Export UI improved with per‑category Select/Deselect and clear summaries.

---
#### [0.8.2] – 2025-11-17
##### Added
- Recursive entry list item factory for consistent, nestable rendering across pages; expand state persists across navigation.

##### Changed
- Day details, weekly overview, search results, and All Entries refactored to the unified factory for identical UX and reduced duplication.

---
#### [0.8.1] – 2025-11-17
##### Added
- Calendar day‑specific search and 7‑day range search in weekly overview, both preserving existing aggregations and UI.

##### Changed
- Calendar screen simplifies to always show Day Details with integrated search filtering.

---
#### [0.8.0] – 2025-11-17
##### Added
- Centralized Search Service for Kinds, Products, Recipes, and a dedicated “All Entries” section.

##### Changed
- Bottom navigation updated to include “All Entries.”

---
#### [0.7.9] – 2025-11-17
##### Fixed
- Pie chart readability: labels outside sections with a detailed legend.
- Export page usability: per‑category Select/Deselect buttons.

##### Changed
- Static flag behavior simplified for recipe/product instances (direct user control).

---
#### [0.7.8] – 2025-11-17
##### Added
- Full recipe instance editing (CRUD) with static/dynamic toggle and visual indicators.
- Centralized template→instance propagation system for products and recipes.

##### Fixed
- Small nutrient values preserved (decimal math fix); undo safety with mounted checks.

##### Migration/Schema
- DB: `recipe_id` column and index added to support instance hierarchies and propagation.

---
#### [0.7.7] – 2025-11-16
##### Fixed
- Pie chart proportions normalized across units (g/mg/µg); adaptive precision for small values.
- Calendar day details show kind values with units.
- Recipe instances display recursive component summaries in all views.

---
#### [0.7.6] – 2025-11-15
##### Changed
- Unified inline editing and save‑to‑commit patterns across all editors; creation occurs on first Save.
- Recipe template editor switched from popup to inline value editing.

##### Fixed
- Product instance components editor now stages changes locally; Save commits; Cancel reverts.

---
#### [0.7.5] – 2025-11-15
##### Changed
- Explicit Edit/Delete buttons across list pages (no implicit row taps).
- Weekly overview expands products/recipes to show children; kind rows non‑clickable.
- Pie chart section height balanced with chips and calendar layout.

---
#### [0.7.0] – 2025-11-15
##### Added
- Database section with export/import (JSON), quick backup/restore, and wipe.

##### Changed
- All database operations consolidated into the Database section (removed from individual pages).

---
#### [0.6.7] – 2025-11-14
##### Added
- Weekly Overview panel with pie chart and 7‑day entry list.
- Section‑based navigation with a smart Calendar/Overview toggle.
- “Save” and “Save & Close” options in editors.

##### Changed
- Products/Recipes pages restyled to match Kinds.
- Search restored across overview and calendar.
- Pie chart displays correct units.

##### Fixed
- Correct names for products/recipes across lists; filters and date range behave as expected; bottom bar visible everywhere.

---
#### [0.5.5] – 2025-11-14
##### Changed
- Editor dialogs harmonized for consistent labels, validation flow, and mounted‑checks.

---
#### [0.5.1] – 2025-11-02
##### Added
- Seed data files (`kinds.json`, `products.json`) to bootstrap fresh installs.

---
#### [0.5.0] – 2025-11-02
##### Added
- Doubles‑based amount model throughout (replaces fixed‑point scaling).
- Recipes with mixed components (kinds + products) and an instantiation dialog.
- Day Details shows nested parents/children with expand support.
- Delete with Undo restores full recipe instance hierarchy.

##### Changed
- Editors and displays accept/render decimals; product recomputation uses doubles.

##### Fixed
- Recipe component saving and instantiation dialog stability.

##### Migration/Schema
- Existing integer data remains valid; new writes use doubles for amounts and per‑100g coefficients.

---
#### [0.4.0] – 2025-10-31
##### Added
- Database‑backed Kinds with a Kinds Manager (unit/min/max/icon/color), and safe deletion with Undo.
- Import/Export v1 (JSON) covers kinds, products, and entries; one‑tap backup/restore; wipe DB (dev).

##### Changed
- App boots from DB data; demo bootstrap only on empty tables.

---
#### [0.3.0] – 2025-10-29
##### Added
- Product templates with per‑100g components and instant appearance in Create Action Sheet.
- Product instantiation with parent + denormalized child nutrients; template changes propagate (with Undo).
- Per‑instance component overrides (mark instance Static) from Day Details.
- Product template deletion converts existing instances into standalone child entries.

---
#### [0.2.0] – 2025-10-29
##### Added
- Third kind: Carbohydrate; Create Action Sheet as a side‑sheet; handedness‑aware Add placement.
- Calendar header navigation and swipe; per‑entry delete with confirmation + Undo.
- Simple Search page; registry‑driven middle section that scales to kinds/products/recipes.

##### Changed
- “Always‑selected today” policy to keep Day Details readily available.

---
#### [0.1.9] – 2025-10-28
##### Added
- Real month calendar in a collapsible top sheet with color‑coded daily dots.
- Day selection with reactive Day Details; tap to edit; empty‑day quick‑add actions.
- Two demo widgets: Protein and Fat with integer grams and minute timestamps.
- Create/Edit editors for both widgets; entries repository + streams (`watchByDay`, `watchByDayRange`).
- Widget framework scaffolding and centralized UX configuration.

##### Changed
- Home cards open Create editors; calendar top sheet interaction refined.

##### Fixed
- Calendar DST day duplication; tiny‑layout overflows; DB init race on first insert.

---
#### [0.1.0] – 2025-10-25
##### Added
- Centralized UX configuration (`ux_config`) and Material 3 theming.
- Collapsible calendar “top sheet” with thresholded open behavior and optional haptics.
- Middle section input model with left/right‑handed mode.
- Calendar grid sized to the top section without internal scroll.

##### Changed
- `MainScreen` adopts `UXConfig`; `BottomControls` adds search + handedness toggle.

##### Fixed
- Animation guards at bounds; Impeller glyph collapse fix; Android caption overlap avoided with `SafeArea`.

##### Dependencies
- Introduced `flutter_riverpod` for granular state management.

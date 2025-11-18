# CHANGELOG.md

## [0.8.4] - 2025-11-18
### Changed
- **All Entries Page**: Complete redesign with filtering, sorting, and bulk operations
    - Now shows all instance entries by default (no search required)
    - **Reactive updates**: Page updates automatically on any database change
    - **Full expand support**: Products/Recipes show nested children when expanded
    - Filter chips for entry type (Nutrients/Products/Recipes)
    - Sort modes: Newest First / Oldest First (persists across navigation)
    - Type filters persist across navigation
    - Checkbox selection mode with bulk delete
    - Scroll position restoration when navigating away and back
    - Bulk delete with confirmation dialog showing breakdown by type
    - Undo support for bulk deletions
    - Search integration: filters work alongside search query
- **Database Page**: Fixed critical reactivity bug
    - **Was using FutureBuilder** (loaded once, never updated)
    - **Now uses StreamBuilder** with reactive updates
    - List updates automatically when entries are created/deleted/modified
    - Expand functionality now works correctly with full hierarchy

### Added
- **EntriesRepository**: `watchAllEntriesWithChildren()` - reactive stream for ALL entries including children
    - Use this for pages that need expand functionality (Database, AllEntries)
    - Automatically updates on any entry change (create/update/delete)
    - Pattern documented in method docstring for reusability
- **EntriesRepository**: `watchAllInstanceEntries()` - reactive stream for top-level instances only
- **Filter state providers**: `entrySortModeProvider`, `entryTypeFilterProvider` for reusable filtering
- **Entry sort modes**: Newest/Oldest sort options (enum `EntrySortMode`)

### Fixed
- **Database Page**: Critical bug where list didn't update after creating/deleting entries
- **All Entries Page**: Expand functionality now works (products/recipes show children)

### Technical
- **Reactive list pattern**: StreamBuilder + watchAllEntriesWithChildren()
    - Build childrenByParent map from ALL entries
    - Filter to top-level entries for display
    - Pass childrenByParent to EntryListItemFactory for expand support
- All Entries Page now ConsumerStatefulWidget for scroll and selection state
- Filter logic consolidated: Type → Search → Sort pipeline
- FilterChip and ChoiceChip patterns following WeeklyOverviewPanel design
- Bulk delete follows DatabasePage patterns (no FAB, regular button with conditional visibility)
- Removed obsolete `_getAllEntries()` Future method from DatabasePage

---

## [0.8.3] - 2025-11-17
### Added
- **Checkbox mode for entry lists**: EntryListItemFactory now supports selection mode
    - New `EntryDisplayMode.checkbox` enum value
    - `selectedIds` parameter for tracking selection
    - `onSelectionChanged` callback for selection updates
    - Used in Database page for fine-grained export selection

### Changed
- **Database page**: Enhanced export capabilities
    - Fine-grained export: select specific kinds, products, recipes, and entries
    - "Select All / Deselect All" buttons for each category
    - Auto-dependency selection: selecting entries automatically includes referenced kinds/products/recipes
    - Export summary shows counts by category

### Fixed
- Export service now correctly handles fine-grained exports with dependency resolution
- Database page entry list now uses checkbox mode from EntryListItemFactory

### Technical
- Automatic code reformatting across all files for consistency
- Added tests for import/export operations
- ImportExportService enhanced with `exportSelected()` method

---

## [0.8.2] - 2025-11-17
### Added
- **Recursive entry list item factory**: Universal solution for consistent, nestable list items
    - Single buildEntry() method handles all entry types at arbitrary depth
    - Expandable/collapsible behavior built-in for products and recipes
    - Support for future nesting: recipes→recipes, products→products, etc.
    - Global expandedEntriesProvider for unified expand state management
    - EntryListItemConfig for configurable metadata display (date, time, static flag)

### Changed
- **DayDetailsPanel**: Complete refactor using recursive factory (681→131 lines, 81% reduction)
- **WeeklyOverviewPanel**: Complete refactor using recursive factory (735→300 lines, 59% reduction)
- **AllEntriesPage**: Added date grouping with headers, uses recursive factory
- **SearchResults**: Refactored to use recursive factory
- **List item consistency**: All entry types display identically across ALL pages
    - Day details: Time-only metadata (date implied by selected day)
    - Weekly/Search/All Entries: Full date+time metadata
    - Nested entries: Proper indentation and compact display
    - Edit/delete buttons: Consistent placement and behavior

### Fixed
- Entry nesting now works consistently across all views
- Expand/collapse state persists across page navigation
- No more duplicate rendering logic for products and recipes

### Technical
- Eliminated ~1000 lines of duplicated code across 4 pages
- Depth-aware rendering with automatic indentation (52px per level)
- Recursive children lookup via childrenByParent map
- Follows CLAUDE.md patterns: Card + ListTile + CircleAvatar
- Extensible architecture for future nesting scenarios

---

## [0.8.1] - 2025-11-17
### Added
- **Calendar search**: Day-specific search filtering in CalendarFullScreen
    - Search bar filters only entries for the currently selected day
    - Uses searchEntriesForDay() for targeted results
    - Maintains all day details panel functionality while searching
- **Weekly overview search**: 7-day range search in WeeklyOverviewPanel
    - Search bar filters entries from the last 7 days
    - Uses searchEntriesInDateRange() for date-bound results
    - Preserves pie chart and aggregation features during search

### Changed
- **CalendarFullScreen**: Removed global SearchResults, now always shows DayDetailsPanel
    - Search filtering is integrated directly into day details
    - Cleaner UI with consistent panel structure
- **DayDetailsPanel**: Enhanced with inline search support
    - Conditionally uses SearchService when query is present
    - Falls back to standard repo.watchByDay() when no query
- **WeeklyOverviewPanel**: Enhanced with inline search support
    - Handles both Map and List stream types for flexibility
    - Search results maintain proper parent-child hierarchy

### Technical
- Inline search pattern completed across all calendar views
- SearchService integration in calendar components
- Stream type polymorphism in WeeklyOverviewPanel for search compatibility

---

## [0.8.0] - 2025-11-17
### Added
- **Comprehensive search service**: Context-aware filtering across all app sections
    - New centralized SearchService handles all search operations
    - Inline search filtering on Kinds, Products, and Recipes pages
    - Search query persists when switching between sections
    - Empty query shows full unfiltered lists
- **"All Entries" section**: New dedicated page to view and search all database entries
    - Access via new bottom bar button (Icons.view_list)
    - Lists all calendar entries with standard Card + ListTile pattern
    - Full search support with entry details (date, time, static flag)
    - Edit and delete operations with undo support
- **Search field clear button**: X icon to quickly clear search query
    - Appears dynamically when search query is not empty
    - Single tap clears field and resets all filters

### Changed
- **Bottom navigation bar**: Extended with "All Entries" button (6th section)
    - Order: Calendar, Handedness, Products, Kinds, Recipes, All Entries, Database
    - Consistent icon style across all sections
- **AppSection enum**: Added `allEntries` member
- **Search UX**: Clear visual feedback when no results found
    - Context-specific empty state messages (e.g., "No kinds found for 'protein'")
    - Distinguishes between "no data" and "no search results"

### Technical
- SearchService architecture: Single source of truth for all search operations
    - searchKinds(), searchProducts(), searchRecipes() for template filtering
    - searchEntriesForDay(), searchEntriesInDateRange() for calendar filtering
    - searchAllEntries() for global entry search
- Inline filtering pattern: Each page uses SearchService for reactive filtering
    - Stream-based updates ensure UI stays in sync with search query
    - No separate search result screens, filters applied directly to page content
- Bottom controls refactored to ConsumerStatefulWidget for TextEditingController management
    - Bidirectional sync between controller and searchQueryProvider
    - Prevents cursor jumps during external query updates

---

## [0.7.9] - 2025-11-17
### Fixed
- **All linter warnings eliminated**: Comprehensive cleanup for production-ready code
    - **BuildContext async gaps** (15+ instances): Captured ScaffoldMessenger/Navigator before async operations
    - **Unnecessary type checks**: Removed redundant `is dynamic` checks and simplified type assertions
    - **Unused imports** (5 files): Cleaned up drift, dart:convert, and repository imports
    - **Unused local variables** (8 instances): Removed or repurposed unused variables across dialogs
    - **Deprecated APIs** (4 instances): Replaced DropdownButtonFormField with DropdownButton
    - **Dead code**: Removed unreachable null coalescing and impossible null checks
    - **Code style**: Fixed unnecessary multiple underscores, added library directive for formatters
- **Pie chart readability**: Labels moved outside sections for better visibility
    - Legend on right side shows full information: "Name: 123.45unit"
    - Flex ratio (2:1) for better space distribution
    - Works better with many small pie sections
- **Export page usability**: Enhanced category selection controls
    - Added "Select All" / "Deselect All" buttons for Kinds, Products, and Recipes
    - "Include All" / "Exclude All" button for Calendar Entries
    - Consistent UI pattern across all export categories
- **Recipe instance static flag**: Simplified toggle behavior
    - Static flag now directly controlled by user toggle
    - Removed automatic static conversion logic
    - Clear user control over template propagation

### Changed
- **Code quality documentation**: Extended claude.md with linter best practices
    - BuildContext async gap patterns and anti-patterns
    - Deprecated API replacement guidelines (DropdownButtonFormField → DropdownButton)
    - Type checks and null safety patterns
    - Unused variable investigation strategy
    - Pre-commit checklist for zero-warning code
- **Mounted checks**: Converted `mounted` to `context.mounted` where context is used after check
    - Makes mounted checks 'related' to context usage for linter compliance
    - Applied consistently across all editor dialogs

### Technical
- ProductHierarchyService/RecipeHierarchyService: Made propagateTemplateChange return int
    - Provides user feedback statistics about propagation operations
- Editor dialogs: Context captures moved to function start (before any async operations)
    - Ensures proper context lifetime handling across async boundaries
- All code now passes `flutter analyze` with zero warnings/info messages

---

## [0.7.8] - 2025-11-17
### Added
- **Recipe instance editing**: Complete CRUD support for recipe instances
    - Edit button now available in day details, weekly overview, and search results
    - Edit dialog loads current values from instance (kind amounts, product grams)
    - Update operation recreates children from template with new overrides
    - Supports toggling isStatic flag during edit
- **Static/Dynamic toggle UI**: User control over template propagation
    - Recipe instance dialog: Static toggle with reset dialog when switching static→dynamic
    - Product instance dialog: Enhanced existing toggle with reset dialog
    - Reset dialogs offer to reload template defaults when making instances dynamic
    - User can cancel toggle or keep current values
- **Visual indicators for static instances**: 🔒 "Static" badge in all views
    - Day details panel: Lock icon + "Static" label in entry subtitle
    - Weekly overview: Same indicator pattern
    - Search results: Same indicator pattern
    - Consistent styling (14px icon, 60% opacity, labelSmall text)
- **Template-instance propagation system**: Centralized children management
    - DB schema: Added `recipe_id` column to entries table with index for fast queries
    - ProductHierarchyService: Manages product instance hierarchies and propagation
    - RecipeHierarchyService: Manages recipe instance hierarchies with recursive aggregation
    - Propagation hooks in template editors with undo support
- **Scientific test methodology**: All tests now show complete data flow
    - Format: INIT → ACTION → EXPECTED → ACTUAL → RESULT
    - 8 comprehensive tests covering template propagation, static instances, recursive aggregation
    - Tests validate recipe_id column, listParentsByRecipeId query, instance editing

### Fixed
- **Integer division bug**: Product instances were nulling small nutrient values
    - Changed `~/` to `/` in ProductService (line 133: `amountPerGram * grams / 100.0`)
    - Prevents vitamins/minerals from being rounded to zero (e.g., 0.05mg now preserved)
- **Widget lifecycle crashes**: Undo operations were accessing disposed widgets
    - Added mounted checks after all async operations in template editors
    - Prevents "Looking up a deactivated widget's ancestor" errors
- **Recipe instances always static**: isStatic was hardcoded to `true`
    - RecipeService now accepts `isStatic` parameter (defaults to false)
    - Template propagation now works correctly for recipe instances

### Changed
- **RecipeService**: Added `updateRecipeInstance()` method
    - Updates parent entry (targetAt, isStatic, payload)
    - Deletes ALL old children including nested product hierarchies
    - Recreates children from template with new kind/product overrides
    - Properly cascades product deletion through ProductService
- **RecipeInstantiateDialog**: Enhanced for both create and edit modes
    - Optional `entryId` parameter triggers edit mode
    - `_loadExisting()` populates controllers with current instance values
    - Loads kind amounts from child payloads, product grams from productGrams column
    - Dialog title adapts: "Edit" vs "Instantiate"
    - Different snackbar messages for create vs update

### Technical
- Added `dart:convert` import to RecipeService for jsonEncode
- Recipe instance dialog now requires `entryId`, `recipeId`, and `initialTarget` to all be optional
- Edit buttons added to 3 views with proper imports of RecipeInstantiateDialog
- Tests expanded from 6 to 8 with new recipe editing coverage

---

## [0.7.7] - 2025-11-16
### Fixed
- **Pie chart proportions**: Fixed incorrect proportions when mixing different units
    - Weight units now normalized to grams for accurate proportions (mg÷1000, µg÷1000000)
    - Display values still show original units (e.g., "500mg" instead of "0.5g")
    - Prevents visual distortion when comparing nutrients with different scales
- **Calendar view**: Fixed missing values for nutrient kinds in day details
    - Kind entries now display amount with unit (previously showed only "—")
- **Number formatting**: Adaptive precision for small values
    - Values < 1 now show 2 decimal places (e.g., "0.50mg" instead of "0mg")
    - Values ≥ 1 show 0 decimal places (e.g., "100mg" instead of "100.00mg")
    - Applied consistently across calendar view, weekly overview, child rows, and search
- **Recipe instances**: Now display component weight summaries with recursive aggregation
    - Shows total product grams plus top 2 nutrient kinds with **labels**
    - **Recursive**: Nutrients from products within recipes are now included
    - **Unit-aware sorting**: Top nutrients sorted by normalized values (10g > 100mg)
    - Format example: "Breakfast Smoothie • 250g • Protein: 30g • Vitamin C: 500mg"
    - Applied to calendar view, weekly overview, and recipe templates page
    - Search shows name only (performance optimization)
- **Weekly overview**: Fixed recipe summaries not displaying
    - Recipe instances now show component weights (was showing only name)

### Changed
- **Documentation**: Simplified claude.md from 119 to 66 lines
    - Removed redundant sections (workflow, testing checklist, common pitfalls)
    - Focused on core patterns and architecture essentials
    - Added unit normalization pattern documentation

## [0.7.6] - 2025-11-15
### Code Quality & Architecture
- **Pattern compliance audit**: Comprehensive review and harmonization of all editor dialogs
    - Unified inline editing pattern across all template editors
    - Consistent transient state management (changes only committed on explicit Save)
    - Save-based creation pattern: Products/Recipes now created on Save instead of before opening editor
    - Fixed: Cancel now properly reverts all changes without leaving orphaned data

### Fixed
- **Product instance components editor**: Critical fix for immediate database writes
    - Now uses transient local state like other editors
    - Add/Delete operations no longer write to DB until Save is clicked
    - Cancel button now correctly reverts all pending changes
    - Added missing Delete button for component removal

### Changed
- **Recipe template editor**: Switched from popup-based to inline editing
    - Consistent with product template editor UX
    - Values now editable directly in list items (faster workflow)
    - Simplified Add dialogs to only select component (amount set inline)
- **Product/Recipe creation**: No longer creates empty templates before editor opens
    - Template created on first Save instead
    - Prevents orphaned empty entries if user clicks Cancel
    - Cleaner separation: user action (Save) triggers database write

### Technical
- **Code cleanup**: Removed 5 obsolete editor screens (1061 lines of dead code)
    - Deleted: `product_instance_editor.dart`, `kind_instance_editor.dart`
    - Deleted: `product_instance_components_editor.dart`, `product_template_editor.dart`, `recipe_template_editor.dart`
    - All functionality consolidated into `*_dialog.dart` variants
- **Centralized formatters**: Created `lib/utils/formatters.dart`
    - Eliminated duplication of `fmtDouble`, `parseDouble`, `fmtTime` across 11+ files
    - Single source of truth for number/time formatting
- **Repository consistency**: Added missing `dispose()` method to `ProductsRepository`

---

## [0.7.5] - 2025-11-15
### Changed
- **Universal actions-on-the-side pattern**: All list pages now use explicit Edit/Delete buttons instead of clickable list items
    - Kinds page: Edit/Delete buttons (already correct)
    - Products page: Edit/Delete buttons (already correct)
    - Recipes page: Edit/Delete buttons (already correct)
    - Day details panel: Added Edit button for kind entries, removed clickable behavior
    - Weekly overview panel: Added Edit button for kind entries, removed clickable behavior
    - Search results: Added Edit/Delete buttons, removed clickable behavior
    - Database page: Checkboxes for selection (appropriate pattern)
- **Weekly overview collapsible views**: Products and recipes now expand to show child entries
    - Matches day details panel behavior with AnimatedRotation chevron
    - onTap only handles expand/collapse for parent items (products/recipes)
    - Kind entries have no onTap handler
- **Pie chart height balance**: Chart section now exactly matches calendar height (420px)
    - Filter chips included within the fixed height container
    - Pie chart uses Expanded to fill remaining space after chips

### Technical
- Created shared icon resolver helper in `lib/ui/widgets/icon_resolver.dart`
    - Eliminated ~120 lines of duplicate code across kinds/recipes/database pages
    - Centralized icon resolution for consistency
- Standardized all list items: Card + CircleAvatar + ListView.builder throughout

---

## [0.7.0] - 2025-11-15
### Added
- **Database Management Page**: New centralized database section accessible from bottom navigation
    - Full database export/import operations with JSON support
    - Quick backup/restore to single-slot file
    - Database wipe functionality with double confirmation
    - All operations now include recipes in addition to kinds, products, and entries
- **Database section navigation**: New "Database" button in bottom navigation bar (storage icon)
    - Added `database` to `AppSection` enum
    - Integrated with existing section-based navigation

### Changed
- **Import/Export consolidation**: Removed scattered import/export UI from individual pages
    - Removed export/import buttons from Kinds page
    - Removed export/import buttons from Products page
    - Removed backup/restore/wipe popup menu from bottom controls
    - All database operations now centralized in Database section

### Technical
- Enhanced `ImportExportService` with complete recipes support
    - Added `RecipesRepository` parameter to service constructor
    - Updated `exportBundle()` to include recipes with components
    - Updated `importBundle()` to import recipes with both kind and product components
    - Added `recipesUpserted` field to `ImportResult` class
- Added `dumpRecipes()` method to `RecipesRepository`
    - Exports all recipes with their components (kinds and products)
    - Follows same pattern as `dumpProductsWithComponents()`
- Updated `importExportServiceProvider` to include `RecipesRepository`
- Created new `lib/ui/database/database_page.dart` with comprehensive database management UI

---

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

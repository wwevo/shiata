### Step‑by‑step implementation plan (no time estimates; each step is testable)

This sequence minimizes risk and lets you verify visible progress at each step. We’ll keep code behind stable routes and wire features incrementally so you can interact with the app after nearly every step.

---

#### 0) Prep and guardrails
- Create a feature branch for Phase 1 (e.g., `feat/widgets-foundation`).
- Add a simple build flag/config (e.g., `AppConfig.enableWidgetsV1 = true`) so you can toggle the new UI if needed.
- Manual test: app still launches; no functional changes yet.

---

#### 1) Replace dummy list with one demo widget entry point
- Home/main screen: replace the list of dummy widgets with a single card: Protein.
- Tapping the card routes to a placeholder Protein screen (temporary scaffold).
- Manual test: tap → navigates to Protein placeholder.

---

#### 2) Secure database bootstrap (encrypted at rest)
- Add Drift + SQLCipher (`sqlcipher_flutter_libs`) and `flutter_secure_storage`.
- Implement DB opener that:
    - Retrieves/creates a random 256‑bit key from Secure Storage.
    - Opens the SQLCipher database with that key.
- Implement lifecycle hooks: open on `resumed`, close on `paused/inactive`, clear in‑memory key.
- Manual tests:
    - App opens DB on start; no crashes.
    - Background the app, lock device, return → DB reopens only after unlock.

---

#### 3) Schema v1 and repository skeleton
- Create `entries` table with indexes:
    - `id, widget_kind, created_at, target_at, show_in_calendar, payload_json, schema_version, updated_at, source_event_id?, source_entry_id?, source_widget_kind?`.
- Create `EntriesRepository` with:
    - `create(...)`, `update(...)`, `delete(...)`, `getById(...)`.
    - Streams: `watchByDayRange(start, end)`, `watchByDay(date)`.
- Manual test: create a temporary dev command in the Protein placeholder to insert a fake entry; verify it can be read back.

---

#### 4) Widget framework contracts + registry
- Define base interfaces/classes:
    - `WidgetKind` (id, displayName, icon, accentColor, editor builders, `createActions(...)`).
    - `EntryBase` (base fields) and `EntryPayload` (versioned JSON).
    - `WidgetRegistry` (map id→kind; helpers for (de)serialization and navigation).
- Register the Protein widget kind in the registry (stub methods return placeholders for now).
- Manual test: dump registry contents to console; verify Protein is registered.

---

#### 5) Protein editor (Create/Edit) minimal flow
- Implement Protein payload v1: `{ grams: int }`, bounds 0–300 (integer only).
- Build Create Editor screen:
    - Fields: grams (numeric + stepper), date+time pickers (minute precision), `show in calendar` (default ON).
    - Save → writes to `entries` with correct `createdAt` and `targetAt` (UTC storage, local UI).
- Build Edit Editor screen:
    - Loads entry by id; same UI; always edit mode.
- Wire main Protein card → Create Editor.
- Manual tests:
    - Create an entry; navigate back; reopen via temporary list or logs.
    - Validation works: non‑integer rejected, range enforced.

---

#### 6) Calendar (real month grid) with stacked dots (no Day Sheet yet)
- Implement month grid UI in the top panel.
- Subscribe to `watchByDayRange(visibleMonth)`.
- Render stacked dots per day for entries with `showInCalendar = true` (colors from widget kind). Limit visible dots (3–4) + “+N” overflow.
- Tap on an individual dot → open the corresponding entry in Edit Editor.
- Manual tests:
    - Create multiple Protein entries on different days/times; dots appear with correct color.
    - Tap dot → opens that entry in edit mode.

---

#### 7) Day Details Sheet (inside top panel)
- On tapping a day cell (outside dots), expand a details area below the calendar:
    - Header with selected date (local timezone).
    - List of entries for that date (`watchByDay`), sorted by time then widget.
    - List items: time, widget icon/color, compact summary (e.g., `Protein • 30 g`).
- Manual tests:
    - Change selected day; list updates.
    - Tap a list item → opens the entry in edit mode.

---

#### 8) Create Action Sheet (CAS) — share‑sheet style
- Define `CreateAction` and `WidgetKind.createActions(...)`.
- Protein exposes at least one action: “Custom grams” → opens Create Editor prefilled with selected date, time=now.
- Build CAS grid:
    - 4 columns (adaptive), max 2 visible rows; vertical scroll beyond.
    - Icons: colored circular backgrounds with white glyphs; tint from `WidgetKind.accentColor` (Protein = indigo/blue).
    - Ordering: recent → priority → alphabetical (recent can be a simple in‑memory list for now).
- Invoke CAS from Day Details Sheet’s “Add” button and from empty‑day state.
- Manual tests:
    - Open CAS; tap Protein action → Create Editor opens and prefilled date/time shown.
    - With more than 8 actions (use mock actions), grid scrolls instead of growing.

---

#### 9) Honor `show in calendar` in all views
- Ensure that only entries with `showInCalendar = true` produce dots and appear in Day Details list filters if you want that behavior (or keep them in Day Details but not in dots — choose one and be consistent; default: dots only).
- Manual test: toggle off → dot disappears; toggle on → dot appears.

---

#### 10) Security lifecycle verification pass
- Re‑verify DB lifecycle:
    - Create entries, background app, lock device, unlock → app resumes and shows data again.
    - Ensure key isn’t cached across lock; logs contain no payloads.
- Manual test checklist:
    - Kill app; restart; data persists and decrypts correctly after unlock.

---

#### 11) Provenance fields — schema ready, UI dormant
- Keep `source_event_id`, `source_entry_id`, `source_widget_kind` in schema and model.
- In the editor, add conditional UI to render a provenance chip if these fields are present (hidden for now since Protein doesn’t set them yet).
- Manual test: insert a fake entry with provenance fields and confirm chip renders and navigates (if source exists) or shows disabled state (if missing).

---

#### 12) Theme and color configurability
- Introduce a theme extension or registry‑provided colors; use Protein indigo/blue for:
    - Calendar dots
    - CAS icons
    - Badges/chips
- Manual test: change the accent color in one place; verify it propagates.

---

#### 13) Remove remaining dummy code and tidy navigation
- Delete any legacy dummy widget lists and routes.
- Ensure named routes exist for:
    - `/widget/:kind/create` (with optional prefilled `targetAt`)
    - `/widget/:kind/edit/:entryId`
- Manual test: deep links from calendar and lists land in edit mode reliably.

---

#### 14) Error handling and empty states
- Friendly empty states for calendar (no entries this month), Day Details (no entries today), and CAS (should always have Protein in Phase 1).
- Snackbar/toast on save errors, validation errors clearly indicated.
- Manual tests: simulate failure paths (e.g., deny storage temporarily if possible) and ensure UX remains clear.

---

#### 15) Final QA pass for Phase 1
- Create several entries on the same day; confirm stacked dots and `+N` overflow.
- Toggle `showInCalendar` and confirm behavior matches your chosen policy.
- Navigate via: Protein card → create; Calendar dot → edit; Day list item → edit; CAS → create.
- Lock/unlock device and verify secure lifecycle.

---

### Notes and future hooks (no action in Phase 1)
- DomainEventBus for cross‑widget interactions (Smoothie → Protein) will plug into `subscriptions()` on `WidgetKind` in Phase 3.
- `events` table (analytics/audit) can be added in Phase 2 without breaking the `entries` API.
- CAS can support pinned/favorites later; keep model flexible.

If this step order looks good, say “go” and we’ll begin implementing Step 1. We’ll keep each change small and verifiable before moving on.

---

## 0.3.0 Implementation Notes (since 0.2.0)

### Domain model changes
- Products & components
  - Tables (idempotent creation in `ensureInitialized()`): `products`, `product_components` (per‑100g integer coefficients), indexes.
  - Entries extended: `product_id`, `product_grams`, `is_static` (non‑breaking); index on `entries(product_id)`.
- Services
  - `ProductService.createProductEntry(...)` — parent (visible) + child nutrients (hidden); integer amounts computed with `amount = (per100g × grams) / 100`.
  - `ProductService.updateParentAndChildren(...)` — edit grams/static; recreate children.
  - `ProductService.updateAllEntriesForProductToCurrentFormula(productId)` — propagate template changes to non‑static entries; transaction-based; single refresh.
  - `ProductService.deleteProductTemplate(productId)` — convert instances: detach children linkage, set them visible, delete parents; remove template & components.

### UI features
- Products page (basket) and Product Template Editor (per‑100g integers; add/remove kinds; save, propagate, Undo).
- CAS dynamic Products section; instances open Product Editor (grams; Static toggle); Day Details expandable product rows with composed nutrients.
- Per‑instance component overrides (Day Details → tune): edits child amounts and marks instance Static.

### Integer-only policy
- All nutrient values are integers; units are canonical (g/mg/µg/mL). Per‑100g coefficients ensure integer scaling to grams.

### Error handling & UX
- Template save: confirm propagation with Undo; editor auto-refreshes after Undo.
- Parent delete: Undo restores parent+children; template delete converts instances (keep values, make visible).

---

## 0.2.0 Implementation Notes (since 0.1.9)

### Calendar navigation and selection
- Providers:
  - `visibleMonthProvider` anchors the visible month (local, first day). Initialized independently.
  - `selectedDayProvider` always holds a day (defaults to today). No null state at runtime.
- Navigation:
  - Header buttons (chevrons) and horizontal swipe gestures (`onHorizontalDragEnd`) change months.
  - When month changes, selection is kept valid: if current selection is not in the new month, it switches to today (if within the month) or the 1st of the new month.
- DST/locale correctness:
  - Calendar cell iteration uses UTC dates and converts to local per-cell to avoid duplicate/missing local days.

### Create Action Sheet (CAS) side-sheet by default
- Configurable via `UXConfig.actionSheetPresentation` with `ActionSheetPresentation.bottom|side|auto`.
- Side-sheet implementation uses `showGeneralDialog` + `SlideTransition`:
  - Slides from the same side as the handedness-aware Add button.
  - Width calculation tuned via `SideSheetConfig` (min/max/tabletMax/widthFraction/horizontalMargin).
  - Dismissal: back button, scrim tap, and tapping empty space inside the panel.
- Bottom-sheet implementation remains available via `showModalBottomSheet` and shares the same `CreateActionSheetContent`.

### Handedness-aware Add button
- `handednessProvider` controls placement of the Add icon in Day Details header (left for left‑handed, right for right‑handed).
- CAS side aligns with handedness for spatial consistency.

### Deletion with Undo in Day Details
- Each entry row has a delete icon; confirmation via `AlertDialog`.
- On delete, a `SnackBar` appears with `UNDO` action that reconstructs the original entry using persisted fields.
- Streams update immediately via `EntriesRepository`’s internal change broadcast.

### Simple Search mode
- Bottom search field toggles middle content between Main list and Search results.
- Repository exposes `watchSearch(query)` using a simple `LIKE` across `widget_kind` and `payload_json`, ordered by `updated_at DESC`.
- Results open the correct editor on tap.

### Dynamic middle list (scalable)
- Extracted to `lib/ui/main_actions_list.dart`.
- Renders one card per `WidgetKind` from the `WidgetRegistry`.
- For each kind, chooses the highest-priority action (`createActions` sorted by `priority`) and runs it for the selected day.

### Riverpod initialization fix
- Removed cross-provider mutation during provider initialization (no writing to `visibleMonthProvider` inside `selectedDayProvider`’s build).
- This resolves the `StateNotifierListenerError` and follows Riverpod’s rule that providers must not modify others while building.

### Editors and kinds
- Added `CarbohydrateKind` (red) and `CarbohydrateEditorScreen` mirroring Protein/Fat.
- All three editors support: grams validation, date/time picker, `show in calendar`, create and edit flows.

### UXConfig additions
- `ActionSheetPresentation` and `SideSheetConfig` added to `UXConfig` with sensible defaults (`side` by default).
- See README for quick-tuning examples.

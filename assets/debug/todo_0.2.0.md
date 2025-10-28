### What remains in the current phase (carry-over checklist)
1) Create Action Sheet (CAS)
- Share-sheet style grid (4 columns, 2 visible rows, scroll beyond).
- Aggregates actions from all `WidgetKind`s; open Create editor prefilled, or quick-create.

2) Calendar interaction polish
- Tap a specific dot → open that exact entry in edit mode.
- Month header + weekday labels; stronger style for out-of-month dates.

3) Day Details refinements
- Replace temporary Add buttons with CAS; finalize muted style for hidden entries.

4) Editor finishing touches
- Validation copy, numeric keyboard hints, optional stepper long-press repeat.

5) Registry hardening
- Per-kind summary helper (e.g., grams → "30 g"); UI derives labels/colors from registry.

6) Cleanup + DX
- Remove placeholders/dev insert paths; friendly error surfacing.

7) Docs
- Expand `IMPLEMENTATION.md`; add `docs/CAS.md` with action model & visuals.

8) Encryption follow-up (later phase)
- Re-introduce SQLCipher with unified FFI loader; repo API unchanged.


### CAS code skeleton (ready for next session)
- Types: `CreateAction` runner signature, `WidgetKind.createActions`, `WidgetRegistry.actionsForDate(...)`.
- UI: `CreateActionSheet` (4-col grid, 2 visible rows, scroll beyond) with colored circular icons + white glyphs.
- Wiring example: open CAS from Day Details empty state via `showModalBottomSheet(...)`.
- Example actions for Protein kind ("Custom grams" → opens editor prefilled for selected date).

These snippets are prepared so we can implement Step 8 quickly next month.


### Next-session quick start
- Implement CAS and wire it to Day Details (empty state and Add button).
- Add dot tap → edit deep link.

Great work this month — we shipped a functional slice: create, edit, calendar visibility, and day-based navigation across two kinds. When we resume, we’ll complete CAS and polish calendar interactions to close Phase 1 strong.
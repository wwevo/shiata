# Claude Code Guidelines for Shiata

## ⛔ CRITICAL RULES - READ THESE FIRST ⛔

### 1. SCOPE CONTROL (ABSOLUTE PRIORITY)
**Change ONLY what was explicitly requested. NOTHING else.**

❌ **FORBIDDEN**:
- Changing files not related to the task
- "Improving" or "optimizing" code that wasn't mentioned
- Changing visual appearance (colors, icons, layouts) without explicit request
- Fixing "bugs" or "inconsistencies" that weren't reported
- Refactoring code "while you're at it"
- Adding features or functionality not asked for

✅ **ALLOWED**:
- ONLY the specific change requested
- ONLY in the specific files/screens mentioned
- ONLY if you've analyzed the impact first (see below)

**Example violations from last session**:
- Task: "Überarbeite den Datenbank-Screen"
- ❌ Changed lists on OTHER pages
- ❌ Changed PieChart appearance
- ❌ Created 10-step fix cascades

### 2. MANDATORY WORKFLOW - BEFORE ANY CODE

**EVERY task must follow this sequence**:

```
1. READ the user's request carefully
   └─ What EXACTLY is being asked?
   └─ What is the SCOPE? (which files/screens?)

2. ANALYZE the current code
   └─ Use Read/Grep to understand existing implementation
   └─ Identify ALL files that might be affected
   └─ Check for shared components, patterns, dependencies

3. IMPACT ANALYSIS
   └─ What could break if I change this?
   └─ Are there other screens using this component?
   └─ Are there shared utilities or styles?
   └─ Will this affect existing tests?

4. ASK if uncertain
   └─ Multiple valid approaches? → ASK
   └─ Could affect other areas? → ASK
   └─ Design decision needed? → ASK
   └─ Not 100% sure about scope? → ASK

5. PROPOSE the plan
   └─ List exactly what files will be changed
   └─ Explain what will change and why
   └─ Note any risks or dependencies
   └─ WAIT for confirmation

6. IMPLEMENT only after approval
   └─ Make ONLY the approved changes
   └─ Test the specific area changed
   └─ Update tests if business logic changed

7. VERIFY no side effects
   └─ Run flutter analyze
   └─ Check that OTHER screens still work
   └─ Confirm no unintended visual changes
```

**DO NOT SKIP THESE STEPS. EVER.**

### 3. ASK FIRST - When in doubt, STOP and ASK

**ALWAYS ask before**:
- Changing any visual appearance (colors, icons, spacing, layout)
- Modifying shared components or utilities
- Changing patterns used across multiple screens
- Refactoring or "improving" existing code
- Adding ANY functionality not explicitly requested
- Making breaking changes
- Deviating from established patterns

**Questions should be**:
- Specific: "Should I change the PieChart colors to match the new theme?"
- With context: "This component is used on 3 screens. Should I change all of them?"
- With options: "I can do this in two ways: A) ... or B) ... Which do you prefer?"

### 4. NEVER INVENT - ALWAYS READ FIRST

**Before writing ANY code**:
- ✅ Use Read to see existing implementations
- ✅ Use Grep to find similar patterns in codebase
- ✅ Check how it's done elsewhere in the project
- ✅ Verify that services/methods/constructors exist

**NEVER**:
- ❌ Assume a service or method exists
- ❌ Invent new patterns when one exists
- ❌ Create "improved" versions of existing code
- ❌ Make up API signatures

**CRITICAL: Before calling ANY method, VERIFY it exists**:
```bash
# ❌ BAD: Assume dispose() exists
entries.dispose()  # Might not exist!

# ✅ GOOD: Check first
grep -n "dispose" lib/data/repo/entries_repository.dart
# → No results found

# → STOP and ASK: "EntriesRepository has no dispose() method. Should I add it?"
```

**If a method/feature is missing**:
1. STOP immediately
2. ASK the user whether to add it
3. Do NOT silently add it without discussion
4. Do NOT assume "it probably exists like in other repos"

**Example**:
- Task: "Add a delete button to the recipe list"
- ✅ Read how delete buttons work on OTHER lists first
- ✅ Use the SAME pattern (colors, icons, confirmation dialog)
- ❌ Don't invent a new delete pattern

### 5. SURGICAL CHANGES ONLY

**Think of yourself as a surgeon, not a renovator**:
- Change the MINIMUM necessary
- Touch the FEWEST files possible
- Keep changes LOCALIZED
- Preserve EVERYTHING else

**If a change requires touching 5+ files → STOP and ASK**
**If a change affects other screens → STOP and ASK**
**If you're unsure about side effects → STOP and ASK**

---

## 🎯 Quality Standards

### Well-Thought Systems over Quick Fixes
This project values:
- **Architecture** over speed
- **Consistency** over cleverness
- **Predictability** over innovation
- **Stability** over features

**Before proposing a solution**:
- Think about edge cases
- Consider maintainability
- Check for similar problems already solved
- Ensure it fits the existing architecture

---

## 📋 Key Patterns (Use These, Don't Invent New Ones)

### List Items (MANDATORY)
**ALL list items** must follow this exact pattern:

```dart
Card(
  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: color,  // Item's actual color
      foregroundColor: Colors.white,
      child: Icon(icon, color: Colors.white),  // Item's actual icon
    ),
    title: Text(item.name),
    subtitle: Text('relevant • metadata'),
    trailing: /* Checkbox OR Row(Edit, Delete) */,
  ),
)
```

**Standard colors/icons:**
- **Kinds**: Use kind's own color and icon from metadata
- **Products**: Purple (`Colors.purple`), basket (`Icons.shopping_basket`)
- **Recipes**: Recipe's color/icon if set, else brown (`Colors.brown`), menu (`Icons.restaurant_menu`)

**DO NOT change these colors or icons without explicit request.**

### Edit Dialogs
- **Two save buttons**: "Save" (OutlinedButton) + "Save & Close" (FilledButton)
- **Cancel**: TextButton

**DO NOT change this button layout without explicit request.**

### Navigation
- **Section-based**: Use `currentSectionProvider` - NO `Navigator.push` for main sections
- **Bottom bar**: Always visible

---

## 🏗️ Architecture

### State Management
- **Riverpod**: StateProvider for simple state, StreamBuilder for reactive data
- **Key providers**: `currentSectionProvider`, `viewModeProvider`, `searchQueryProvider`, `selectedDayProvider`

### File Organization
- `lib/ui/` - All UI (editors, pages, widgets)
- `lib/data/` - Repositories, services, database
- `lib/domain/` - Models and business logic

### Key Patterns
- **Names**: Extract from `payloadJson` using `jsonDecode`
- **Dates**: Store UTC milliseconds, display local
- **Units**: From kind metadata, never hardcode
- **Unit Normalization**: Convert mg→g (÷1000), µg→g (÷1000000) for pie chart proportions

**Before changing any of these patterns → ASK**

---

## 🔄 Reactive UI Patterns (CRITICAL)

### StreamBuilder vs FutureBuilder

**GOLDEN RULE**: Use StreamBuilder for ALL data-driven UI in Pages. FutureBuilder is only acceptable in dialogs or one-time queries.

#### ⛔ Critical Bug Pattern: FutureBuilder in Pages

```dart
// ❌ CRITICAL BUG: This widget NEVER updates after initial load
FutureBuilder<List<EntryRecord>>(
  future: repo.listEntries(),  // Loads ONCE, never updates
  builder: (context, snapshot) {
    final entries = snapshot.data ?? [];
    // BUG: After creating/deleting entries, list stays stale
  }
)
```

**Why this is a bug**:
- FutureBuilder executes the future ONCE when widget builds
- After creating/updating/deleting data, the UI shows stale data
- User must navigate away and back to see changes
- This violates user expectations of immediate feedback

#### ✅ Correct Pattern: StreamBuilder for Reactive Lists

```dart
// ✅ CORRECT: UI automatically updates on any data change
StreamBuilder<List<EntryRecord>>(
  stream: repo.watchEntries(),  // Stream that reacts to changes
  builder: (context, snapshot) {
    final entries = snapshot.data ?? [];
    // UI updates automatically when data changes
  }
)
```

**When to use each**:

| Pattern | Use Case | Example |
|---------|----------|---------|
| **StreamBuilder** | Pages, lists, data that changes | AllEntriesPage, DatabasePage, RecipesPage |
| **FutureBuilder** | Dialogs, one-time queries, static data | Initial data load in dialogs, lookup tables |

### The Reactive List Pattern

All repositories provide `watch*()` methods that return reactive streams. Use these in UI:

#### Repository Pattern (Provider Side)

```dart
// ✅ Every data-fetching method should have a watch* counterpart
class EntriesRepository {
  // One-time query (use sparingly)
  Future<List<EntryRecord>> listEntries() async {
    final rows = await db.customSelect('SELECT * FROM entries;').get();
    return rows.map((r) => EntryRecord.fromDb(r.data)).toList();
  }

  // Reactive stream (use in UI)
  Stream<List<EntryRecord>> watchEntries() async* {
    yield await listEntries();
    await for (final _ in _changes.stream) {
      yield await listEntries();
    }
  }
}
```

**Pattern documentation in repository methods**:
Every `watch*()` method should include a docstring with usage example:

```dart
/// Watch all entries (reactive).
/// Returns a stream that automatically updates when entries change.
///
/// Use this instead of listEntries() in UI widgets:
/// ```dart
/// StreamBuilder<List<EntryRecord>>(
///   stream: repo.watchEntries(),
///   builder: (context, snapshot) {
///     final entries = snapshot.data ?? [];
///     // UI updates automatically
///   }
/// )
/// ```
Stream<List<EntryRecord>> watchEntries() async* { ... }
```

#### Hierarchical Lists with Expand Support

For lists that need parent-child hierarchy (products with components, recipes with ingredients):

```dart
// ✅ The Hierarchical Reactive List Pattern
StreamBuilder<List<EntryRecord>>(
  stream: repo.watchAllEntriesWithChildren(),
  builder: (context, snapshot) {
    final allEntries = snapshot.data ?? <EntryRecord>[];

    // Build hierarchy: childrenByParent map from ALL entries
    final childrenByParent = <String, List<EntryRecord>>{};
    for (final entry in allEntries) {
      if (entry.sourceEntryId != null && entry.sourceEntryId!.isNotEmpty) {
        childrenByParent.putIfAbsent(entry.sourceEntryId!, () => []).add(entry);
      }
    }

    // Get only top-level entries for display
    final topLevel = allEntries
        .where((e) => e.sourceEntryId == null || e.sourceEntryId!.isEmpty)
        .toList();

    // Use EntryListItemFactory with childrenByParent for expand support
    return ListView.builder(
      itemCount: topLevel.length,
      itemBuilder: (ctx, index) {
        return EntryListItemFactory.buildEntry(
          context: context,
          ref: ref,
          entry: topLevel[index],
          childrenByParent: childrenByParent,  // Enables expand
          registry: registry,
          config: EntryListItemConfig.fullDateTime,
          displayMode: EntryDisplayMode.normal,
        );
      },
    );
  }
)
```

**Why this pattern**:
- Single stream for ALL entries (efficient, one DB query)
- Hierarchy built in-memory (fast, no extra queries)
- Expand/collapse works automatically (children available)
- Filter/search on top-level only (cleaner UX)
- Fully reactive (any change updates entire tree)

#### Available Watch Methods

**EntriesRepository**:
- `watchAllEntriesWithChildren()` - All entries for hierarchy (Database, AllEntries with expand)
- `watchAllInstanceEntries()` - Top-level only (simpler lists without expand)
- `watchByDay(DateTime)` - Single day entries
- `watchByDayRange(DateTime, DateTime)` - Date range entries
- `watchSearch(String)` - Text search results
- `watchById(String)` - Single entry (for detail views)

**RecipesRepository**:
- `watchRecipes({bool onlyActive})` - All recipes
- `watchComponents(String recipeId)` - Recipe components (v0.8.5+)

**ProductsRepository**:
- `watchProducts({bool onlyActive})` - All products

**KindsRepository**:
- `watchKinds({bool onlyActive})` - All kinds

### Audit Checklist for Lists

When reviewing list implementations, check:
- [ ] Is this in a Page (not a Dialog)? → Must use StreamBuilder
- [ ] Does data change during app usage? → Must use StreamBuilder
- [ ] Is there a `watch*()` method available? → Use it
- [ ] Is there expand/hierarchy needed? → Use `watchAllEntriesWithChildren()`
- [ ] Is it truly one-time data? → FutureBuilder acceptable (rare)

### Migration Guide: FutureBuilder → StreamBuilder

If you find a FutureBuilder bug:
1. Check if a `watch*()` method exists in the repository
2. If not, add one following the pattern above
3. Replace `FutureBuilder` → `StreamBuilder`
4. Replace `future: repo.get*()` → `stream: repo.watch*()`
5. Verify reactivity by creating/deleting data and checking UI updates
6. Add tests for the new stream (see Testing section)

**Example migration**:
```dart
// BEFORE (BUG):
FutureBuilder<List<RecipeComponentDef>>(
  future: recipesRepo.getComponents(recipeId),
  builder: (ctx, snapshot) { ... }
)

// AFTER (FIXED):
StreamBuilder<List<RecipeComponentDef>>(
  stream: recipesRepo.watchComponents(recipeId),
  builder: (ctx, snapshot) { ... }
)
```

---

## 🧪 Testing

**Tests are living documentation**: They must always reflect current behavior.

### Test Maintenance (CRITICAL)
- **WHEN**: Any service, repository, or business logic changes
- **WHAT**: Update corresponding tests IMMEDIATELY
- **WHY**: Broken tests = broken trust. Green tests that test wrong behavior are worse than no tests.

### Test Format (Scientific Method)
All tests must follow this structure:
```dart
print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
print('TEST: Description of what is being tested');
print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

// Setup code...

print('INIT:     What was created/initial state');
print('ACTION:   What operation was performed');
print('EXPECTED: What should happen');
print('ACTUAL:   What actually happened\n');

// Assertions...

print('RESULT:   ✅ PASS or ❌ FAIL - Why it passed/failed');
print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
```

### Running Tests
```bash
flutter test test/propagation_test.dart  # Run specific test file
flutter test                              # Run all tests
```

---

## 🎨 Code Quality & Linter Best Practices

### BuildContext Async Gaps (CRITICAL)
**Problem**: Using `BuildContext` after `await` causes warnings and potential bugs if widget is unmounted.

**Solutions**:
1. **Capture context-dependent objects BEFORE any await**:
```dart
Future<void> _save() async {
  // ✅ Capture FIRST, before any await
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  await someAsyncOperation();

  // ✅ Use captured objects after await
  if (!mounted) return;
  messenger.showSnackBar(SnackBar(content: Text('Saved')));
  navigator.pop();
}
```

2. **Use `context.mounted` when context is used immediately**:
```dart
await someAsyncOperation();
if (!context.mounted) return;  // ✅ Related check
await showDialog(context: context, ...);  // ✅ Safe to use
```

**Anti-patterns**:
```dart
// ❌ BAD: Capturing after await
await someAsyncOperation();
if (!mounted) return;  // Unrelated check
ScaffoldMessenger.of(context).showSnackBar(...);  // Warning!

// ❌ BAD: Using mounted instead of context.mounted
if (!mounted) return;  // Unrelated to context
await showDialog(context: context, ...);  // Warning!
```

### Deprecated Flutter APIs
**DropdownButtonFormField.value** (deprecated in Flutter 3.33+):
```dart
// ❌ BAD: Using deprecated 'value' parameter
DropdownButtonFormField<String>(
  value: _selected,
  onChanged: (v) => setState(() => _selected = v),
  decoration: InputDecoration(labelText: 'Select'),
)

// ✅ GOOD: Use DropdownButton with state management
DropdownButton<String>(
  value: _selected,
  hint: Text('Select'),
  isExpanded: true,
  onChanged: (v) => setState(() => _selected = v),
)
```

### Unused Variables & Imports
**Always investigate before removing**:
- Check if variable was planned for future use (see TODOs, comments)
- If truly unused, remove it
- For return values: Consider if they should be used for user feedback

**Example - Making variables useful**:
```dart
// ❌ Before: unused variable
int updatedCount = 0;
for (final item in items) {
  await update(item);
  updatedCount++;
}
// TODO: Show user feedback

// ✅ After: return for user feedback
Future<int> updateItems() async {
  int updatedCount = 0;
  for (final item in items) {
    await update(item);
    updatedCount++;
  }
  return updatedCount;  // Now useful!
}
```

### Type Checks & Null Safety
```dart
// ❌ BAD: Unnecessary type check
if (value is dynamic) { ... }  // Always true

// ❌ BAD: Dead null-aware operator
final unit = kind.unit ?? '';  // If kind.unit is non-nullable

// ✅ GOOD: Remove unnecessary operations
if (value != null) { ... }     // Only check what's actually nullable
final unit = kind?.unit ?? '';  // Use ?. if kind itself is nullable
```

### Code Style
```dart
// ❌ BAD: Multiple unnecessary underscores
separatorBuilder: (_, __) => Divider()

// ✅ GOOD: Meaningful or single underscore
separatorBuilder: (context, index) => Divider()
// or if truly unused:
separatorBuilder: (_, __) => Divider()  // But prefer meaningful names
```

### Library Documentation
```dart
// ❌ BAD: Dangling doc comment
/// This is a utility library.
///
/// It contains helper functions.

import 'package:flutter/material.dart';

// ✅ GOOD: Add library directive
/// This is a utility library.
///
/// It contains helper functions.
library;

import 'package:flutter/material.dart';
```

### Pre-commit Checklist
Before committing, ensure:
- [ ] Run `flutter analyze` - zero warnings
- [ ] Check all `context` usage after `await`
- [ ] No unused imports or variables (or documented why kept)
- [ ] No deprecated API usage
- [ ] All mounted checks use `context.mounted` when context follows
- [ ] No unintended side effects on other screens
- [ ] Tests updated if business logic changed

---

## 📦 Version Management

- Update `pubspec.yaml` version
- Update `CHANGELOG.md` with categories: Added, Changed, Fixed, Technical
- Format: `## [X.Y.Z] - YYYY-MM-DD`

---

## 🚨 Summary - The Golden Rules

1. **SCOPE**: Change ONLY what was asked for
2. **READ**: Always read existing code first, never invent
3. **ASK**: When in doubt, STOP and ASK
4. **ANALYZE**: Check for side effects BEFORE changing
5. **MINIMAL**: Make the smallest change that works
6. **VERIFY**: Test that nothing else broke
7. **QUALITY**: Well-thought systems over quick fixes

**If you violate these rules, you will create chaos.**
**If you follow these rules, you will create value.**

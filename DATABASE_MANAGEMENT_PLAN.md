# Database Management Feature - Implementation Plan

**Date:** 2025-11-14
**Version:** 0.7.0 (Next Release)
**Status:** Ready to implement

---

## 📋 Overview

Streamline the database experience by creating a centralized Database Management page that handles all import/export operations, replacing the scattered UI elements currently in Kinds, Products, and Bottom Controls.

---

## 🎯 Goals

1. Remove all existing import/export UI from individual pages
2. Create a new dedicated Database Management page
3. Support full database operations (export all, import all, wipe)
4. Support fine-grained operations (export/import specific items with dependencies)
5. Include recipes in all operations (currently missing from backend)

---

## 📊 Current State Analysis

### Existing Import/Export Locations

1. **lib/ui/kinds/kinds_page.dart** (lines 12-105, 127-142)
   - `_exportJson()` and `_importJson()` functions
   - PopupMenu with "Export (JSON)" and "Import (JSON)" items

2. **lib/ui/products/products_page.dart** (lines 13-96, 133-148)
   - `_exportJsonProducts()` and `_importJsonProducts()` functions
   - PopupMenu with "Export (JSON)" and "Import (JSON)" items

3. **lib/ui/widgets/bottom_controls.dart** (lines 92-183)
   - PopupMenu with 3 items:
     - "Backup (single slot)"
     - "Restore (single slot)"
     - "Wipe DB (temporary)"
   - Inline handlers for backup/restore/wipe operations

4. **lib/ui/recipes/recipes_page.dart**
   - ❌ No import/export currently

### Backend Service

**File:** `lib/data/repo/import_export_service.dart`

**Currently handles:**
- ✅ Kinds
- ✅ Products (with components)
- ✅ Entries (calendar instances)
- ❌ Recipes (missing!)

**Key methods:**
- `exportBundle()` - Returns full JSON bundle
- `importBundle(jsonLike)` - Destructive import (wipes first)
- `backupToFile()` - Saves to file system
- `restoreFromFile()` - Restores from file system

---

## 🔧 Implementation Plan

### Phase 1: Cleanup (Remove Old UI)

#### Task 1: Clean up kinds_page.dart
**File:** `lib/ui/kinds/kinds_page.dart`

**Changes:**
- Remove `_exportJson()` function (lines 12-55)
- Remove `_importJson()` function (lines 57-105)
- Remove PopupMenuButton from AppBar actions (lines 127-142)
- Keep only the "Add kind" IconButton

#### Task 2: Clean up products_page.dart
**File:** `lib/ui/products/products_page.dart`

**Changes:**
- Remove `_exportJsonProducts()` function (lines 13-48)
- Remove `_importJsonProducts()` function (lines 50-96)
- Remove PopupMenuButton from AppBar actions (lines 133-148)
- Keep only the "Add product" IconButton

#### Task 3: Clean up bottom_controls.dart
**File:** `lib/ui/widgets/bottom_controls.dart`

**Changes:**
- Remove entire PopupMenuButton (lines 92-184)
- Keep all other navigation buttons
- Remove import for `import_export_service.dart` if no longer used
- Remove import for `db_handle.dart` if no longer used

---

### Phase 2: Add Database Section to Navigation

#### Task 4: Update AppSection enum
**File:** `lib/ui/main_screen_providers.dart`

**Changes:**
```dart
// Before:
enum AppSection { calendar, products, kinds, recipes }

// After:
enum AppSection { calendar, products, kinds, recipes, database }
```

#### Task 5: Add database navigation button
**File:** `lib/ui/widgets/bottom_controls.dart`

**Changes:**
- Add new IconButton after recipes button
- Suggested icon: `Icons.storage` or `Icons.database`
- Position: After recipes (line 70), before search field

**Example:**
```dart
IconButton(
  tooltip: 'Database',
  onPressed: () {
    ref.read(currentSectionProvider.notifier).state = AppSection.database;
  },
  icon: const Icon(Icons.storage),
),
```

#### Task 6: Wire up database page in main screen
**File:** `lib/ui/main_screen.dart`

**Changes:**
- Add import: `import 'database/database_page.dart';`
- Add case to switch statement:
```dart
case AppSection.database:
  return const DatabasePage();
```

---

### Phase 3: Enhance Backend Service

#### Task 7: Add recipes support to exportBundle()
**File:** `lib/data/repo/import_export_service.dart`

**Changes:**
- Add `RecipesRepository` parameter to constructor
- Add `recipes` field to class
- Update `exportBundle()` to call `recipes.dumpRecipes()` (or similar)
- Add recipes to returned JSON bundle

**Example:**
```dart
class ImportExportService {
  ImportExportService({
    required this.db,
    required this.kinds,
    required this.products,
    required this.entries,
    required this.recipes, // NEW
  });

  final RecipesRepository recipes; // NEW

  Future<Map<String, Object?>> exportBundle() async {
    final kindsList = await kinds.dumpKinds();
    final productsList = await products.dumpProductsWithComponents();
    final recipesList = await recipes.dumpRecipes(); // NEW
    final entriesList = await entries.dumpEntries();

    return <String, Object?>{
      'version': 1,
      'kinds': kindsList,
      'products': productsList,
      'recipes': recipesList, // NEW
      'entries': entriesList,
    };
  }
}
```

**Note:** May need to add `dumpRecipes()` method to RecipesRepository if it doesn't exist

#### Task 8: Add recipes support to importBundle()
**File:** `lib/data/repo/import_export_service.dart`

**Changes:**
- Add recipes deletion to wipe section
- Add recipes import logic (similar to products)
- Handle recipe components/ingredients

**Example wipe section:**
```dart
await db.transaction(() async {
  await db.customStatement('DELETE FROM entries;');
  await db.customStatement('DELETE FROM recipe_components;'); // if exists
  await db.customStatement('DELETE FROM recipes;'); // NEW
  await db.customStatement('DELETE FROM product_components;');
  await db.customStatement('DELETE FROM products;');
  await db.customStatement('DELETE FROM kinds;');
});
```

#### Task 9: Add fine-grained export method
**File:** `lib/data/repo/import_export_service.dart`

**New method:**
```dart
/// Export selected items with their dependencies.
/// Dependencies are automatically included:
/// - Products include their component kinds
/// - Recipes include their ingredient products and kinds
/// - If includeEntries=true, calendar instances are included
Future<Map<String, Object?>> exportSelected({
  List<String>? kindIds,
  List<String>? productIds,
  List<String>? recipeIds,
  bool includeEntries = false,
}) async {
  // 1. Start with requested IDs
  final selectedKindIds = <String>{...?kindIds};
  final selectedProductIds = <String>{...?productIds};
  final selectedRecipeIds = <String>{...?recipeIds};

  // 2. Resolve dependencies
  // - For each product, add its component kinds
  for (final productId in selectedProductIds) {
    final components = await products.getComponents(productId);
    selectedKindIds.addAll(components.map((c) => c.kindId));
  }

  // - For each recipe, add its ingredient products and their kinds
  for (final recipeId in selectedRecipeIds) {
    // TODO: get recipe ingredients
    // Add product IDs and their component kinds
  }

  // 3. Export only selected items
  final kindsList = await kinds.getByIds(selectedKindIds.toList());
  final productsList = await products.getByIdsWithComponents(selectedProductIds.toList());
  final recipesList = await recipes.getByIds(selectedRecipeIds.toList());

  final bundle = <String, Object?>{
    'version': 1,
    'kinds': kindsList,
    'products': productsList,
    'recipes': recipesList,
  };

  // 4. Optionally include calendar entries
  if (includeEntries) {
    final entriesFilter = await entries.getEntriesForItems(
      kindIds: selectedKindIds.toList(),
      productIds: selectedProductIds.toList(),
      recipeIds: selectedRecipeIds.toList(),
    );
    bundle['entries'] = entriesFilter;
  }

  return bundle;
}
```

**Note:** May need to add helper methods to repositories (getByIds, getByIdsWithComponents, getEntriesForItems)

#### Task 10: Add fine-grained import method (merge mode)
**File:** `lib/data/repo/import_export_service.dart`

**New method:**
```dart
/// Import bundle in merge mode (no wipe, updates existing by ID).
/// Handles conflicts by updating existing records.
Future<ImportResult> importMerge(dynamic jsonLike) async {
  final Map<String, dynamic> root;
  if (jsonLike is String) {
    root = jsonDecode(jsonLike) as Map<String, dynamic>;
  } else if (jsonLike is Map<String, dynamic>) {
    root = jsonLike;
  } else {
    throw ArgumentError('Unsupported import payload');
  }

  final version = root['version'];
  if (version != 1) {
    throw StateError('Unsupported version: $version');
  }

  int kindsUpserted = 0;
  int productsUpserted = 0;
  int recipesUpserted = 0;
  int componentsWritten = 0;
  int entriesUpserted = 0;

  // Import kinds (upsert by ID)
  final kindsArr = (root['kinds'] as List?) ?? const [];
  for (final item in kindsArr) {
    // ... existing kind import logic ...
    kindsUpserted++;
  }

  // Import products + components (upsert by ID)
  final prodsArr = (root['products'] as List?) ?? const [];
  for (final item in prodsArr) {
    // ... existing product import logic ...
    productsUpserted++;
  }

  // Import recipes + components (upsert by ID)
  final recipesArr = (root['recipes'] as List?) ?? const [];
  for (final item in recipesArr) {
    // ... recipe import logic ...
    recipesUpserted++;
  }

  // Import entries (upsert or insert based on ID)
  final entriesArr = (root['entries'] as List?) ?? const [];
  if (entriesArr.isNotEmpty) {
    // Check if entry exists, update or insert
    entriesUpserted = entriesArr.length;
  }

  return ImportResult(
    kindsUpserted: kindsUpserted,
    productsUpserted: productsUpserted,
    componentsWritten: componentsWritten,
    warnings: const <String>[],
  );
}
```

#### Update provider
**File:** `lib/data/repo/import_export_service.dart`

**Update provider to include recipes:**
```dart
final importExportServiceProvider = Provider<ImportExportService?>((ref) {
  final db = ref.watch(appDbProvider);
  final kr = ref.watch(kindsRepositoryProvider);
  final pr = ref.watch(productsRepositoryProvider);
  final rr = ref.watch(recipesRepositoryProvider); // NEW
  final er = ref.watch(entriesRepositoryProvider);
  if (db == null || kr == null || pr == null || rr == null || er == null) return null;
  return ImportExportService(
    db: db,
    kinds: kr,
    products: pr,
    recipes: rr, // NEW
    entries: er,
  );
});
```

---

### Phase 4: Create Database Management Page

#### Task 11: Create database_page.dart
**New file:** `lib/ui/database/database_page.dart`

**Basic structure:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../data/providers.dart';
import '../../data/db/db_handle.dart';
import '../../data/repo/import_export_service.dart';

class DatabasePage extends ConsumerWidget {
  const DatabasePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFullOperationsSection(context, ref),
          const Divider(height: 32),
          _buildQuickBackupSection(context, ref),
          const Divider(height: 32),
          _buildFineGrainedSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildFullOperationsSection(BuildContext context, WidgetRef ref) {
    // Task 12
  }

  Widget _buildQuickBackupSection(BuildContext context, WidgetRef ref) {
    // Task 13
  }

  Widget _buildFineGrainedSection(BuildContext context, WidgetRef ref) {
    // Tasks 14-15
  }
}
```

#### Task 12: Implement full operations section
**File:** `lib/ui/database/database_page.dart`

**Section includes:**
- **Export All** button
  - Calls `exportBundle()`
  - Shows JSON in dialog with copy button
  - Includes kinds, products, recipes, entries, components

- **Import All** button
  - Shows text input for JSON
  - Calls `importBundle()` (destructive)
  - Shows double confirmation warning
  - Displays import results

- **Wipe Database** button
  - Double confirmation dialog
  - Calls `dbHandleProvider.notifier.wipeDb()`
  - Shows success/error snackbar

**UI mockup:**
```dart
Widget _buildFullOperationsSection(BuildContext context, WidgetRef ref) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Full Database Operations',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Export, import, or wipe the entire database including all kinds, products, recipes, and calendar entries.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Export All'),
            onPressed: () => _exportAll(context, ref),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload),
            label: const Text('Import All'),
            onPressed: () => _importAll(context, ref),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Wipe Database'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _wipeDatabase(context, ref),
          ),
        ],
      ),
    ],
  );
}
```

#### Task 13: Implement quick backup section
**File:** `lib/ui/database/database_page.dart`

**Section includes:**
- **Backup to File** button
  - Calls `backupToFile()`
  - Shows file path in snackbar

- **Restore from File** button
  - Shows confirmation dialog
  - Calls `restoreFromFile()`
  - Shows success/error snackbar

**UI mockup:**
```dart
Widget _buildQuickBackupSection(BuildContext context, WidgetRef ref) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Quick Backup (Single Slot)',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Single-slot backup saved to device storage. Quick way to save and restore your complete database.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Backup to File'),
            onPressed: () => _backupToFile(context, ref),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restore from File'),
            onPressed: () => _restoreFromFile(context, ref),
          ),
        ],
      ),
    ],
  );
}
```

#### Task 14: Implement fine-grained export UI
**File:** `lib/ui/database/database_page.dart`

**Section includes:**
- List of all kinds with checkboxes
- List of all products with checkboxes
- List of all recipes with checkboxes
- Checkbox for "Include calendar entries"
- **Export Selected** button
  - Calls `exportSelected()`
  - Shows JSON in dialog with copy button

**UI mockup:**
```dart
Widget _buildFineGrainedSection(BuildContext context, WidgetRef ref) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Fine-Grained Operations',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        'Export or import specific items. Dependencies are automatically included (e.g., products include their kinds).',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),

      // Export section
      ExpansionTile(
        title: const Text('Export Selected Items'),
        children: [
          _buildExportSelectionUI(context, ref),
        ],
      ),

      // Import section
      ExpansionTile(
        title: const Text('Import & Merge'),
        children: [
          _buildImportMergeUI(context, ref),
        ],
      ),
    ],
  );
}
```

**Export selection UI:**
```dart
Widget _buildExportSelectionUI(BuildContext context, WidgetRef ref) {
  // Use local state for selections (StatefulBuilder or StateProvider)
  final kindsAsync = ref.watch(kindsListProvider);
  final productsAsync = ref.watch(productsRepositoryProvider)?.watchProducts();
  final recipesAsync = ref.watch(recipesRepositoryProvider)?.watchRecipes();

  return Column(
    children: [
      // Kinds checkboxes
      Text('Kinds', style: Theme.of(context).textTheme.titleMedium),
      kindsAsync.when(
        data: (kinds) => Column(
          children: kinds.map((k) => CheckboxListTile(
            title: Text(k.name),
            value: _selectedKinds.contains(k.id),
            onChanged: (val) => _toggleKind(k.id, val ?? false),
          )).toList(),
        ),
        loading: () => CircularProgressIndicator(),
        error: (e, st) => Text('Error loading kinds'),
      ),

      // Products checkboxes
      // ... similar pattern ...

      // Recipes checkboxes
      // ... similar pattern ...

      // Include entries checkbox
      CheckboxListTile(
        title: const Text('Include calendar entries'),
        value: _includeEntries,
        onChanged: (val) => setState(() => _includeEntries = val ?? false),
      ),

      // Export button
      ElevatedButton.icon(
        icon: const Icon(Icons.download),
        label: const Text('Export Selected'),
        onPressed: () => _exportSelected(context, ref),
      ),
    ],
  );
}
```

**Note:** Will need to convert to StatefulWidget or use StateProvider for selections

#### Task 15: Implement fine-grained import UI
**File:** `lib/ui/database/database_page.dart`

**Section includes:**
- Text input for JSON
- **Import & Merge** button
  - Calls `importMerge()`
  - Shows import results
  - No confirmation needed (non-destructive)

**UI mockup:**
```dart
Widget _buildImportMergeUI(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();

  return Column(
    children: [
      TextField(
        controller: controller,
        maxLines: 10,
        decoration: const InputDecoration(
          labelText: 'Paste JSON here',
          hintText: '{"version": 1, "kinds": [...], ...}',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Merge mode: Existing items will be updated, new items will be added. Nothing will be deleted.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        icon: const Icon(Icons.merge),
        label: const Text('Import & Merge'),
        onPressed: () => _importMerge(context, ref, controller.text),
      ),
    ],
  );
}
```

#### Task 16: Implement helper methods
**File:** `lib/ui/database/database_page.dart`

**Helper methods to implement:**
- `_exportAll(BuildContext context, WidgetRef ref)`
- `_importAll(BuildContext context, WidgetRef ref)`
- `_wipeDatabase(BuildContext context, WidgetRef ref)`
- `_backupToFile(BuildContext context, WidgetRef ref)`
- `_restoreFromFile(BuildContext context, WidgetRef ref)`
- `_exportSelected(BuildContext context, WidgetRef ref)`
- `_importMerge(BuildContext context, WidgetRef ref, String json)`

All should follow similar patterns:
1. Get service from ref
2. Show loading indicator if needed
3. Call service method
4. Show result (dialog or snackbar)
5. Handle errors with try-catch

---

## 🧪 Testing Checklist

- [ ] Full export includes all data types (kinds, products, recipes, entries)
- [ ] Full import wipes and restores correctly
- [ ] Database wipe requires double confirmation
- [ ] Quick backup saves to file successfully
- [ ] Quick restore loads from file successfully
- [ ] Fine-grained export includes only selected items
- [ ] Fine-grained export includes dependencies automatically
- [ ] Fine-grained import merges without deleting existing data
- [ ] All error cases show user-friendly messages
- [ ] Navigation to database page works from bottom bar
- [ ] Old import/export UI is completely removed from other pages

---

## 📁 Files Modified/Created Summary

### Files to Modify (7)
1. `lib/ui/kinds/kinds_page.dart` - Remove import/export UI
2. `lib/ui/products/products_page.dart` - Remove import/export UI
3. `lib/ui/widgets/bottom_controls.dart` - Remove popup menu, add database button
4. `lib/ui/main_screen_providers.dart` - Add database to AppSection enum
5. `lib/ui/main_screen.dart` - Add database section case
6. `lib/data/repo/import_export_service.dart` - Add recipes support and fine-grained methods
7. Provider update in `import_export_service.dart` - Include RecipesRepository

### Files to Create (1)
1. `lib/ui/database/database_page.dart` - New database management page

---

## 🚀 Implementation Order

**Recommended sequence:**

1. **Cleanup first** (Tasks 1-3) - Remove old UI to avoid confusion
2. **Add navigation** (Tasks 4-6) - Wire up new section
3. **Enhance backend** (Tasks 7-10) - Ensure service supports all operations
4. **Build UI** (Tasks 11-16) - Create database page with all features
5. **Test thoroughly** - Verify all operations work correctly

**Estimated time:** 3-4 hours total

---

## 📝 Notes & Considerations

### Dependency Resolution
When exporting products, automatically include their component kinds. When exporting recipes, include ingredient products AND their kinds. This ensures exported bundles are complete and importable.

### Import Modes
- **Destructive (importBundle):** Wipes database first, then imports. Used for "Import All" and "Restore from File"
- **Merge (importMerge):** Updates existing items by ID, adds new items. Used for "Import & Merge"

### Recipes Repository
Check if `RecipesRepository` has necessary methods:
- `dumpRecipes()` - Get all recipes as JSON-serializable list
- `getByIds(List<String>)` - Get specific recipes
- May need to add if missing

### Error Handling
All operations should:
- Show loading indicators during processing
- Display clear error messages on failure
- Confirm success with snackbars or dialogs
- Use try-catch blocks to handle exceptions gracefully

### UI/UX Polish
- Use icons consistently (download, upload, save, restore, merge, delete)
- Color-code dangerous operations (red for wipe)
- Show clear descriptions for each section
- Provide confirmation dialogs for destructive operations
- Display import results showing counts of items imported

---

## ✅ Ready to Implement

All details are documented. Implementation can proceed task-by-task following the 16-step plan. Good luck! 🚀

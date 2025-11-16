# Children Management System - Revised Design

**Branch**: `claude/centralize-children-management-01LwN22cDGS78onRbs9CGUd2`
**Date**: 2025-11-16 (Updated)
**Criticality**: ⚠️ **CORE FUNCTIONALITY** - App useless if this breaks

---

## Core Requirements

### 1. Template-Instance Architecture

```
Kinds (Templates Only)
  └─ Instances (amount varies)

Product Templates (contain Kinds with fixed values)
  ├─ Non-Static Instances (update when template changes)
  └─ Static Instances (frozen, don't update)

Recipe Templates (contain Kinds + Products)
  ├─ Non-Static Instances (update when template changes)
  └─ Static Instances (frozen, don't update)
```

### 2. Propagation Rules (CRITICAL!)

**Kind Template Change**:
```
Kind Template changed
  → Product Templates updated (all products using this kind)
  → Product Instances updated (ONLY non-static!)
  → Recipe Instances updated (ONLY non-static!)
```

**Product Template Change**:
```
Product Template changed
  → Product Instances updated (ONLY non-static!)
  → Recipe Instances updated (if recipe contains this product, ONLY non-static!)
```

**Recipe Template Change**:
```
Recipe Template changed
  → Recipe Instances updated (ONLY non-static!)
```

**Static Instances**:
- ❌ NEVER update automatically
- ✅ Can be manually reset to template values

### 3. Reset Functionality

Users can reset static instances back to template:
```
Static Product Instance → Reset → Recalculate from Product Template
Static Recipe Instance → Reset → Recalculate from Recipe Template
```

**No UI yet, but service MUST support this.**

---

## Service Architecture (Revised)

### Multiple Specialized Services

```dart
// 1. ProductHierarchyService
class ProductHierarchyService {
  // Get product instance with all nutrient children
  Future<ProductInstanceHierarchy> getProductInstance(String entryId);

  // Aggregate nutrients from product (direct children only)
  Future<NutrientSummary> aggregateNutrients(String productEntryId);

  // Reset static instance to template values
  Future<void> resetToTemplate(String productEntryId);

  // Propagate template changes to non-static instances
  Future<void> propagateTemplateChange(String productId);
}

// 2. RecipeHierarchyService
class RecipeHierarchyService {
  // Get recipe instance with all children (products + kinds)
  Future<RecipeInstanceHierarchy> getRecipeInstance(String entryId);

  // Aggregate nutrients RECURSIVELY (includes product children)
  Future<NutrientSummary> aggregateNutrients(String recipeEntryId);

  // Reset static instance to template values
  Future<void> resetToTemplate(String recipeEntryId);

  // Propagate template changes to non-static instances
  Future<void> propagateTemplateChange(String recipeId);
}

// 3. Shared Data Structures
class NutrientSummary {
  final double totalProductGrams;
  final Map<String, double> nutrientsByKind; // kindId -> amount (original)
  final Map<String, double> normalizedNutrients; // kindId -> amount (normalized to g)

  // Get top N nutrients sorted by normalized value
  List<(String kindId, double originalAmount)> getTopNutrients(int n);

  // Format as string with labels
  String format(WidgetRegistry registry, {int topN = 2});
}

class ProductInstanceHierarchy {
  final EntryRecord parent;
  final List<EntryRecord> nutrientChildren;
  final bool isStatic;
}

class RecipeInstanceHierarchy {
  final EntryRecord parent;
  final List<ProductInstanceHierarchy> productChildren;
  final List<EntryRecord> kindChildren;
  final bool isStatic;
}
```

---

## Propagation Implementation

### Current DB Schema Check

**entries table** (from `raw_db.dart`):
```sql
- id (TEXT PRIMARY KEY)
- widget_kind (TEXT)
- source_entry_id (TEXT) -- Parent link
- product_id (TEXT) -- Link to product template
- product_grams (INTEGER)
- is_static (INTEGER) -- 0 = dynamic, 1 = static
- payload_json (TEXT)
- ...
```

**products table**:
```sql
- id (TEXT PRIMARY KEY)
- name (TEXT)
- ...
```

**product_components table**:
```sql
- product_id (TEXT)
- kind_id (TEXT)
- amount_per_gram (REAL) -- per 100g
```

**recipes table**:
```sql
- id (TEXT PRIMARY KEY)
- name (TEXT)
- ...
```

**recipe_components table**:
```sql
- recipe_id (TEXT)
- comp_id (TEXT) -- product_id OR kind_id
- type (TEXT) -- 'product' OR 'kind'
- grams (INTEGER) -- for products
- amount (REAL) -- for kinds
```

**Assessment**: ✅ Schema is good! `is_static` flag exists, template links exist.

---

## Propagation Flows (Detailed)

### Flow 1: Kind Definition Change

**Scenario**: User edits Kind "Protein" (changes unit or limits)

**Impact**: NONE on instances (kinds don't have "values" in template, only schema)

**Action**: No propagation needed

---

### Flow 2: Product Template Change

**Scenario**: User edits Product Template "Egg" components (e.g., 10g protein → 12g protein)

**Steps**:
1. Update `product_components` table
2. Find all product instances: `SELECT * FROM entries WHERE product_id = 'egg'`
3. For each instance:
   - If `is_static = 0`: Recalculate children (delete + recreate with new formula)
   - If `is_static = 1`: Skip
4. Find all recipe instances containing this product
5. For each recipe instance:
   - If `is_static = 0`: Trigger recipe recalculation
   - If `is_static = 1`: Skip

**Service Method**:
```dart
Future<void> propagateProductTemplateChange(String productId) async {
  // 1. Get new template components
  final components = await products.getComponents(productId);

  // 2. Find all non-static instances
  final instances = await entries.listParentsByProductId(productId);

  for (final instance in instances) {
    if (!instance.isStatic) {
      // Recalculate children
      await productService.updateParentAndChildren(
        parentEntryId: instance.id,
        productGrams: instance.productGrams!,
      );
    }
  }

  // 3. Find recipes containing this product
  // TODO: Need way to query which recipes use a product
  // May need new DB query or index
}
```

---

### Flow 3: Recipe Template Change

**Scenario**: User edits Recipe Template "Smoothie" components

**Steps**:
1. Update `recipe_components` table
2. Find all recipe instances: Query entries where `widget_kind = 'recipe'` AND payload contains `recipe_id = 'smoothie'`
3. For each instance:
   - If `is_static = 0`: Recalculate all children (products + kinds)
   - If `is_static = 1`: Skip

**Challenge**: No direct `recipe_id` foreign key in entries table!

**Current**: Recipe ID stored in `payload_json`: `{"recipe_id": "smoothie", "name": "..."}`

**Solution Options**:
- **Option A**: Add `recipe_id` column to entries (cleaner, faster queries)
- **Option B**: JSON query: `WHERE payload_json LIKE '%"recipe_id":"smoothie"%'` (slower, works now)

---

## Database Schema Improvements (Proposed)

### Add recipe_id column to entries

**Migration**:
```sql
ALTER TABLE entries ADD COLUMN recipe_id TEXT;
CREATE INDEX idx_entries_recipe_id ON entries(recipe_id);
```

**Benefits**:
- Fast queries for recipe instances
- Consistent with `product_id` pattern
- No JSON parsing needed

**Migration Strategy**:
1. Add column (nullable)
2. Backfill from existing `payload_json`
3. Update creation/update code to populate both

---

## Reset Functionality

### Reset Static Product Instance

```dart
Future<void> resetProductInstanceToTemplate(String entryId) async {
  final entry = await entries.getById(entryId);
  if (entry == null || !entry.isStatic || entry.productId == null) {
    throw Exception('Entry is not a static product instance');
  }

  // Mark as non-static and recalculate (uses template)
  await productService.updateParentAndChildren(
    parentEntryId: entryId,
    productGrams: entry.productGrams!,
    isStatic: false, // Back to dynamic
  );
}
```

### Reset Static Recipe Instance

```dart
Future<void> resetRecipeInstanceToTemplate(String entryId) async {
  final entry = await entries.getById(entryId);
  if (entry == null || !entry.isStatic) {
    throw Exception('Entry is not a static recipe instance');
  }

  // Extract recipe_id from payload
  final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
  final recipeId = payload['recipe_id'] as String?;
  if (recipeId == null) throw Exception('No recipe_id found');

  // Delete old children
  await entries.deleteChildrenOfParent(entryId);

  // Recreate from template
  final targetAt = DateTime.fromMillisecondsSinceEpoch(entry.targetAt, isUtc: true).toLocal();
  await recipeService.createRecipeEntry(
    recipeId: recipeId,
    targetAtLocal: targetAt,
    showParentInCalendar: entry.showInCalendar,
    overrideParentId: entryId, // Reuse same ID
    isStatic: false, // Back to dynamic
  );
}
```

---

## Implementation Plan

### Phase 1: DB Schema Enhancement ✅
- [x] Add `recipe_id` column to entries table
- [x] Create migration script
- [x] Update entry creation/update code
- [x] Add query helper `listParentsByRecipeId()`
- [ ] Write tests for schema changes

**Implementation Notes**:
- Added `recipe_id TEXT NULL` column to entries table (`raw_db.dart:68-70`)
- Added index `idx_entries_recipe_id` for fast queries (`raw_db.dart:147-149`)
- Updated `EntryRecord` class with `recipeId` field (`entries_repository.dart:24,41`)
- Updated `EntriesRepository.create()` to accept `recipeId` parameter (`entries_repository.dart:150,171`)
- Added `listParentsByRecipeId()` helper method (`entries_repository.dart:256-264`)
- Updated `RecipeService.createRecipeEntry()` to populate `recipe_id` field (`recipe_service.dart:40`)
- Updated `deleteRecipeTemplate()` to use new query method instead of JSON extraction (`recipe_service.dart:87`)

### Phase 2: Core Services ✅
- [x] Create `ProductHierarchyService`
  - [x] `getProductInstance()`
  - [x] `aggregateNutrients()`
  - [x] `resetToTemplate()`
  - [x] `propagateTemplateChange()`
- [x] Create `RecipeHierarchyService`
  - [x] `getRecipeInstance()`
  - [x] `aggregateNutrients()` (recursive!)
  - [x] `resetToTemplate()`
  - [x] `propagateTemplateChange()`
- [x] Create shared `NutrientSummary` class
- [ ] Unit tests for all methods

**Implementation Notes**:
- Created `NutrientSummary` class with unit normalization and formatting (`nutrient_summary.dart`)
  - `getTopNutrients(n)`: Sort by normalized values
  - `format(registry)`: Format with labels (e.g., "250g • Protein: 30g")
  - `normalizeToGrams(value, unit)`: Convert mg/µg to grams for comparison
- Created `ProductHierarchyService` (`product_hierarchy_service.dart`)
  - Direct children aggregation only (no recursion)
  - Reset static instances to template
  - Propagate template changes to non-static instances
- Created `RecipeHierarchyService` (`recipe_hierarchy_service.dart`)
  - RECURSIVE aggregation through products
  - Handles both kind and product children
  - Reset and propagation logic for recipe instances
  - Uses `ProductHierarchyService` for product hierarchy traversal

### Phase 3: Integrate Propagation ✅
- [x] Hook into Product Template Editor
  - Already implemented using `ProductService.updateAllEntriesForProductToCurrentFormula()`
  - Includes user confirmation and undo support
- [x] Hook into Recipe Template Editor
  - On save: Call `RecipeHierarchyService.propagateTemplateChange()`
  - Added user confirmation dialog
  - Added undo support with template restoration
- [x] Add user feedback (e.g., "Updated existing recipe instances")

**Implementation Notes**:
- Product template editor already had propagation logic (using ProductService)
- Added propagation to recipe template editor (`recipe_template_editor_dialog.dart:120-162`)
  - User confirmation before propagation
  - Undo support that restores old components and re-propagates
  - Consistent UX with product editor
- Both editors now support template change propagation to non-static instances

### Phase 4: Migrate Views
- [ ] Replace manual aggregation in `weekly_overview_panel.dart`
- [ ] Replace manual aggregation in `day_details_panel.dart`
- [ ] Replace manual aggregation in `recipes_page.dart`
- [ ] Update search results (if feasible)

### Phase 5: Reset UI (Future)
- [ ] Add "Reset to Template" button in instance editors
- [ ] Confirmation dialog
- [ ] Visual indicator for static instances

---

## Critical Tests

### Must Verify
1. ✅ **Static instances don't update**: Change template → verify static unchanged
2. ✅ **Non-static instances update**: Change template → verify non-static recalculated
3. ✅ **Recursive propagation**: Product in Recipe → change product template → recipe updates
4. ✅ **Reset works**: Static instance → reset → matches current template
5. ✅ **No data loss**: Propagation doesn't delete user data
6. ✅ **Performance**: Large templates (100+ instances) propagate in reasonable time

---

## Open Questions

1. **Partial propagation failures**:
   - If 50 instances need update and #25 fails, what happens?
   - Transaction? Rollback? Continue and log errors?

2. **User notification**:
   - Silent propagation or show progress/results?
   - "Updated 47 product instances, 3 recipe instances"?

3. **Recipe-Product dependency tracking**:
   - Do we need an index/cache of "which recipes use product X"?
   - Or query on-demand (slower but simpler)?

4. **Static-to-dynamic transition**:
   - When resetting, should user choose to stay static or become dynamic?
   - Or always become dynamic after reset?

---

## Next Steps

1. **Discuss**: Review this design, answer open questions
2. **Phase 1**: DB schema enhancement (recipe_id column)
3. **Phase 2**: Implement core services with tests
4. **Phase 3**: Integrate propagation hooks
5. **Phase 4**: Migrate views to use services


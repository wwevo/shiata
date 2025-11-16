# Children Management System - Analysis & Design

**Branch**: `claude/centralize-children-management-01LwN22cDGS78onRbs9CGUd2`
**Date**: 2025-11-16
**Goal**: Centralize parent-child relationship management to eliminate code duplication and improve maintainability

---

## Current State Analysis

### 1. **Parent-Child Relationships in DB**

**Schema** (`entries` table):
- `id` (String) - Entry ID
- `source_entry_id` (String?) - Parent entry ID (NULL = top-level)
- `widget_kind` (String) - Type (product, recipe, or nutrient kind)

**Current DB Methods** (`entries_repository.dart`):
- ✅ `listChildrenOfParent(parentId)` - Loads direct children
- ✅ `deleteChildrenOfParent(parentId)` - Deletes all children
- ✅ `detachChildrenOfParent(parentId)` - Removes parent link
- ✅ `convertChildrenOfParentToStandalone(parentId)` - Makes children standalone

**Limitation**: Only handles **ONE level** (direct children). No recursive queries.

---

### 2. **Current childrenByParent Map Pattern**

**Used in**:
1. `day_details_panel.dart` (Calendar View)
2. `weekly_overview_panel.dart` (Weekly Overview)

**Pattern**:
```dart
// Build map manually from flat list
final childrenByParent = <String, List<EntryRecord>>{};
for (final c in allEntries) {
  if (c.sourceEntryId != null) {
    (childrenByParent[c.sourceEntryId!] ??= []).add(c);
  }
}
```

**Problem**:
- ❌ Duplicated in 2 places
- ❌ Must be rebuilt on every render
- ❌ Only works when all entries are already loaded

---

### 3. **Recursive Aggregation Pattern**

**Used for Recipe Summaries** (3 locations):
1. `day_details_panel.dart` - `_recipeTitleFromPayload()`
2. `weekly_overview_panel.dart` - Recipe summary inline
3. `recipes_page.dart` - `_RecipeTemplateSummary` widget

**Pattern**:
```dart
void aggregateNutrients(List<EntryRecord> entries) {
  for (final child in entries) {
    if (child.widgetKind == 'product') {
      totalProductGrams += grams;
      // RECURSIVE: Get grandchildren
      final grandchildren = childrenByParent[child.id] ?? [];
      aggregateNutrients(grandchildren);
    } else {
      kindSummaries[child.widgetKind] = (kindSummaries[child.widgetKind] ?? 0) + amount;
    }
  }
}
```

**Problems**:
- ❌ **Code duplication**: 3x nearly identical implementations
- ❌ **Unit normalization**: Duplicated sorting logic (mg→g, µg→g) in 3 places
- ❌ **Performance**: Recursive traversal happens on every render
- ❌ **Not reusable**: Search results can't use it (no childrenByParent available)

---

### 4. **Entry Creation with Children**

**ProductService** (`product_service.dart`):
- `createProductEntry()` - Creates parent + nutrient children
- `updateParentAndChildren()` - Updates parent, deletes & recreates children

**RecipeService** (`recipe_service.dart`):
- `createRecipeEntry()` - Creates parent + product/nutrient children

**Pattern**: Services handle creation, but **views handle traversal**.

---

## Problem Summary

### Code Duplication
1. **childrenByParent map building**: 2 locations
2. **Recursive nutrient aggregation**: 3 locations
3. **Unit normalization for sorting**: 3 locations
4. **Recipe summary formatting**: 3 locations

### Performance Issues
1. **Rebuilds on every render**: childrenByParent map + recursive aggregation
2. **No caching**: Same data traversed multiple times
3. **Inefficient for search**: Can't show summaries without loading all children

### Maintainability Issues
1. **Bug fixes need 3+ changes**: Any fix to aggregation logic must be replicated
2. **Inconsistency risk**: Slight variations in logic between locations
3. **Hard to extend**: Adding new features (e.g., 3-level nesting) requires changes everywhere

---

## Proposed Solution: EntriesHierarchyService

### Design Goals
1. ✅ **Single source of truth** for parent-child relationships
2. ✅ **Efficient caching** of hierarchy data
3. ✅ **Reusable aggregations** (nutrients, summaries)
4. ✅ **Flexible queries** (direct children, all descendants, ancestry)

---

### Service Architecture

```dart
class EntriesHierarchyService {
  final EntriesRepository _entries;
  final WidgetRegistry _registry;

  // Cached hierarchy (invalidated on DB changes)
  Map<String, List<EntryRecord>>? _childrenByParent;

  // --- Core Hierarchy Methods ---

  /// Get direct children of an entry
  Future<List<EntryRecord>> getChildren(String parentId);

  /// Get ALL descendants recursively (children, grandchildren, etc.)
  Future<List<EntryRecord>> getAllDescendants(String parentId);

  /// Get childrenByParent map for a list of entries
  Map<String, List<EntryRecord>> buildChildrenMap(List<EntryRecord> entries);

  /// Get ancestry chain (parent -> grandparent -> ...)
  Future<List<EntryRecord>> getAncestry(String childId);

  // --- Aggregation Methods ---

  /// Aggregate nutrients recursively for a recipe/product
  Future<NutrientSummary> aggregateNutrients(
    EntryRecord parent,
    List<EntryRecord> allEntries,
  );

  /// Get formatted summary string
  String formatSummary(NutrientSummary summary, {int topN = 2});
}

class NutrientSummary {
  final double totalProductGrams;
  final Map<String, double> nutrientsByKind; // Original values
  final Map<String, double> normalizedNutrients; // For sorting (all in grams)

  List<MapEntry<String, double>> getTopNutrients(int n) {
    // Sort by normalized values, return original
    return normalizedNutrients.entries
      .toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      .take(n)
      .map((e) => MapEntry(e.key, nutrientsByKind[e.key]!))
      .toList();
  }
}
```

---

### Migration Plan

#### Phase 1: Create Service (New Code)
- [ ] Create `lib/data/repo/entries_hierarchy_service.dart`
- [ ] Implement basic hierarchy methods
- [ ] Implement nutrient aggregation
- [ ] Add unit tests

#### Phase 2: Migrate Views (One by One)
- [ ] Migrate `weekly_overview_panel.dart`
  - Replace manual childrenByParent building
  - Replace inline recipe aggregation
- [ ] Migrate `day_details_panel.dart`
  - Replace `_recipeTitleFromPayload()` with service call
  - Remove duplicate aggregation logic
- [ ] Migrate `recipes_page.dart`
  - Simplify `_RecipeTemplateSummary` to use service

#### Phase 3: Extend Functionality
- [ ] Add caching/memoization for performance
- [ ] Enable summaries in search results
- [ ] Add hierarchy visualization helpers (tree view)

#### Phase 4: Cleanup
- [ ] Remove all duplicate aggregation code
- [ ] Update documentation
- [ ] Performance testing

---

### Benefits

**Immediate**:
- ✅ **Fix code duplication**: 3+ duplicate implementations → 1 service
- ✅ **Consistent behavior**: All views use same logic
- ✅ **Easier debugging**: Single place to fix bugs

**Long-term**:
- ✅ **Better performance**: Caching + optimized queries
- ✅ **Extensible**: Easy to add new aggregation types
- ✅ **Testable**: Service can be unit tested independently
- ✅ **Search results**: Can now show recipe summaries efficiently

---

### Risks & Mitigation

**Risk**: Breaking existing functionality during migration
**Mitigation**: Migrate one view at a time, test thoroughly

**Risk**: Performance regression with caching
**Mitigation**: Benchmark before/after, add lazy loading if needed

**Risk**: Complexity in service layer
**Mitigation**: Keep API simple, well-documented

---

## Open Questions

1. **Caching strategy**:
   - Cache entire hierarchy map in memory?
   - Or lazy-load on demand with LRU cache?

2. **Recipe Templates vs Instances**:
   - Recipe templates use `RecipeComponentDef` (from recipes_repository)
   - Recipe instances use `EntryRecord` (from entries_repository)
   - Should service handle both? Or separate services?

3. **Unit normalization**:
   - Hardcode in service (mg→g, µg→g)?
   - Or make configurable via WidgetRegistry unit metadata?

---

## Next Steps

1. **Discuss design** with user
2. **Choose implementation approach** (phased vs big-bang)
3. **Start with Phase 1**: Create service + tests
4. **Iterate**: Migrate views one by one


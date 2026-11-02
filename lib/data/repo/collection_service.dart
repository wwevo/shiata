import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'collections_repository.dart';
import 'entries_repository.dart';
import 'product_service.dart';

class CollectionService {
  CollectionService({
    required this.entries,
    required this.collections,
    required this.productService,
  });

  final EntriesRepository entries;
  final CollectionsRepository collections;
  final ProductService? productService;

  /// Creates a collection parent entry and its selected children.
  /// Only ingredients with [selectedIngredients] set to true will be created.
  Future<String?> createCollectionEntry({
    required String collectionId,
    required DateTime targetAtLocal,
    required Map<String, bool> selectedIngredients,
    Map<String, double>? kindOverrides,
    Map<String, int>? productGramOverrides,
    bool showParentInCalendar = true,
    bool isStatic = false,
  }) async {
    final def = await collections.getCollection(collectionId);
    if (def == null) return null;
    final comps = await collections.getComponents(collectionId);

    // Parent payload keeps collection id and name for simple rendering.
    final parent = await entries.create(
      widgetKind: 'collection',
      targetAtLocal: targetAtLocal,
      payload: {'collection_id': collectionId, 'name': def.name},
      showInCalendar: showParentInCalendar,
      recipeId: collectionId,
      isStatic: isStatic,
    );

    // Create children only for selected ingredients
    for (final c in comps) {
      final isSelected = selectedIngredients[c.compId] ?? true;
      if (!isSelected) continue;

      if (c.type == CollectionComponentType.kind) {
        final amount = (kindOverrides?[c.compId]) ?? (c.amount ?? 0.0);
        await entries.create(
          widgetKind: c.compId,
          targetAtLocal: targetAtLocal,
          payload: {'amount': amount},
          showInCalendar: false,
          sourceEntryId: parent.id,
          sourceWidgetKind: 'collection',
        );
      } else {
        // Product component
        final grams = (productGramOverrides?[c.compId]) ?? (c.grams ?? 0);
        if (productService != null && grams > 0) {
          final productParentId = await productService!.createProductEntry(
            productId: c.compId,
            productGrams: grams,
            targetAtLocal: targetAtLocal,
            isStatic: true,
          );
          if (productParentId != null) {
            await entries.update(productParentId, {
              'source_entry_id': parent.id,
              'source_widget_kind': 'collection',
            });
          }
        }
      }
    }

    return parent.id;
  }

  /// Update an existing collection instance with new values and recompute its children.
  Future<void> updateCollectionInstance({
    required String parentEntryId,
    required DateTime targetAtLocal,
    required Map<String, bool> selectedIngredients,
    Map<String, double>? kindOverrides,
    Map<String, int>? productGramOverrides,
    bool? isStatic,
    bool? showInCalendar,
  }) async {
    // 1. Load parent and validate it's a collection instance
    final parent = await entries.getById(parentEntryId);
    if (parent == null || parent.widgetKind != 'collection') return;
    final collectionId = parent.recipeId;
    if (collectionId == null) return;

    // 2. Load collection template and components
    final def = await collections.getCollection(collectionId);
    if (def == null) return;
    final comps = await collections.getComponents(collectionId);

    // 3. Update parent row
    final payload = {'collection_id': collectionId, 'name': def.name};
    await entries.update(parentEntryId, {
      'payload_json': jsonEncode(payload),
      'target_at': targetAtLocal.toUtc().millisecondsSinceEpoch,
      if (isStatic != null) 'is_static': isStatic ? 1 : 0,
      if (showInCalendar != null) 'show_in_calendar': showInCalendar ? 1 : 0,
    });

    // 4. Delete ALL old children (including product hierarchies)
    final oldChildren = await entries.listChildrenOfParent(parentEntryId);
    for (final child in oldChildren) {
      if (child.widgetKind == 'product' && productService != null) {
        await productService!.deleteParentAndChildren(child.id);
      } else {
        await entries.delete(child.id);
      }
    }

    // 5. Recreate children from template with new values, only for selected ingredients
    for (final c in comps) {
      final isSelected = selectedIngredients[c.compId] ?? true;
      if (!isSelected) continue;

      if (c.type == CollectionComponentType.kind) {
        final amount = (kindOverrides?[c.compId]) ?? (c.amount ?? 0.0);
        await entries.create(
          widgetKind: c.compId,
          targetAtLocal: targetAtLocal,
          payload: {'amount': amount},
          showInCalendar: false,
          sourceEntryId: parentEntryId,
          sourceWidgetKind: 'collection',
        );
      } else {
        // Product component
        final grams = (productGramOverrides?[c.compId]) ?? (c.grams ?? 0);
        if (productService != null && grams > 0) {
          final productParentId = await productService!.createProductEntry(
            productId: c.compId,
            productGrams: grams,
            targetAtLocal: targetAtLocal,
            isStatic: true,
          );
          if (productParentId != null) {
            await entries.update(productParentId, {
              'source_entry_id': parentEntryId,
              'source_widget_kind': 'collection',
            });
          }
        }
      }
    }
  }
}

final collectionServiceProvider = Provider<CollectionService?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final c = ref.watch(collectionsRepositoryProvider);
  final ps = ref.watch(productServiceProvider);
  if (e == null || c == null) return null;
  return CollectionService(entries: e, collections: c, productService: ps);
});

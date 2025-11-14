import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'entries_repository.dart';
import 'products_repository.dart';

class ProductService {
  ProductService({required this.entries, required this.products});
  final EntriesRepository entries;
  final ProductsRepository products;

  /// Creates a parent product entry (visible) and denormalized child nutrient entries (hidden).
  /// Returns the parent entry id.
  Future<String?> createProductEntry({
    required String productId,
    required int productGrams,
    required DateTime targetAtLocal,
    bool isStatic = false,
  }) async {
    final def = await products.getProduct(productId);
    if (def == null) return null;
    final comps = await products.getComponents(productId);

    // Parent payload keeps name and grams for simple rendering without joins.
    final parent = await entries.create(
      widgetKind: 'product',
      targetAtLocal: targetAtLocal,
      payload: {
        'product_id': productId,
        'name': def.name,
        'grams': productGrams,
      },
      showInCalendar: true,
      schemaVersion: 1,
      productId: productId,
      productGrams: productGrams,
      isStatic: isStatic,
    );

    // Children: one per component; hidden in calendar; link to parent via source_entry_id.
    for (final c in comps) {
      // Treat amountPerGram as per-100g coefficient. Scale by grams and divide by 100 (integer math).
      final amount = (c.amountPerGram * productGrams) / 100.0;
      await entries.create(
        widgetKind: c.kindId,
        targetAtLocal: targetAtLocal,
        payload: {
          'amount': amount,
        },
        showInCalendar: false,
        schemaVersion: 1,
        sourceEntryId: parent.id,
        sourceWidgetKind: 'product',
      );
    }
    return parent.id;
  }

  /// Update a parent product entry (grams/static) and recompute its children amounts.
  Future<void> updateParentAndChildren({
    required String parentEntryId,
    required int productGrams,
    bool? isStatic,
  }) async {
    // Load parent
    final parent = await entries.getById(parentEntryId);
    if (parent == null) return;
    final productId = parent.productId;
    if (productId == null) return;
    final def = await products.getProduct(productId);
    if (def == null) return;
    final comps = await products.getComponents(productId);

    // Update parent row
    final payload = jsonDecode(parent.payloadJson) as Map<String, dynamic>;
    payload['grams'] = productGrams;
    await entries.update(parentEntryId, {
      'payload_json': jsonEncode(payload),
      'product_grams': productGrams,
      if (isStatic != null) 'is_static': isStatic ? 1 : 0,
    });

    // Recreate children: delete old, insert new with scaled amounts
    await entries.deleteChildrenOfParent(parentEntryId);
    for (final c in comps) {
      final amount = (c.amountPerGram * productGrams) / 100.0;
      await entries.create(
        widgetKind: c.kindId,
        targetAtLocal: DateTime.fromMillisecondsSinceEpoch(parent.targetAt, isUtc: true).toLocal(),
        payload: {'amount': amount},
        showInCalendar: false,
        schemaVersion: 1,
        sourceEntryId: parentEntryId,
        sourceWidgetKind: 'product',
      );
    }
  }

  /// Delete a parent product entry and all its children.
  Future<void> deleteParentAndChildren(String parentEntryId) async {
    await entries.deleteChildrenOfParent(parentEntryId);
    await entries.delete(parentEntryId);
  }

  /// Delete a product template. If instances exist:
  /// - Detach their children (remove source linkage), keeping them as standalone entries
  /// - Delete parent product entries
  /// - Finally delete the template and its components
  Future<void> deleteProductTemplate(String productId) async {
    // Find all parent entries that reference this product
    final parents = await entries.listParentsByProductId(productId);
    for (final parent in parents) {
      // Convert children to standalone visible entries and remove the parent
      await entries.convertChildrenOfParentToStandalone(parent.id);
      await entries.delete(parent.id); // remove parent row
    }
    await products.deleteProduct(productId);
  }

  /// Recompute children for all non-static instances of a product using current template components.
  Future<void> updateAllEntriesForProductToCurrentFormula(String productId) async {
    final parents = await entries.listParentsByProductId(productId);
    final comps = await products.getComponents(productId);
    for (final parent in parents) {
      if (parent.isStatic) continue; // skip static instances
      final grams = parent.productGrams ?? 0;
      if (grams <= 0) continue;
      // Update parent payload grams (keep as-is) and recreate children
      await entries.deleteChildrenOfParent(parent.id);
      for (final c in comps) {
        final amount = (c.amountPerGram * grams) ~/ 100;
        await entries.create(
          widgetKind: c.kindId,
          targetAtLocal: DateTime.fromMillisecondsSinceEpoch(parent.targetAt, isUtc: true).toLocal(),
          payload: {'amount': amount},
          showInCalendar: false,
          schemaVersion: 1,
          sourceEntryId: parent.id,
          sourceWidgetKind: 'product',
        );
      }
    }
  }
}

final productServiceProvider = Provider<ProductService?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final p = ref.watch(productsRepositoryProvider);
  if (e == null || p == null) return null;
  return ProductService(entries: e, products: p);
});

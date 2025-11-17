import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/widgets/registry.dart';
import '../providers.dart';
import 'entries_repository.dart';
import 'nutrient_summary.dart';
import 'product_service.dart';
import 'products_repository.dart';

/// Hierarchy information for a product instance.
class ProductInstanceHierarchy {
  ProductInstanceHierarchy({
    required this.parent,
    required this.nutrientChildren,
    required this.isStatic,
  });

  final EntryRecord parent;
  final List<EntryRecord> nutrientChildren;
  final bool isStatic;
}

/// Service for managing product instance hierarchies and nutrient aggregation.
/// Handles product-level operations (direct children only, no recursion).
class ProductHierarchyService {
  ProductHierarchyService({
    required this.entries,
    required this.products,
    required this.productService,
    required this.registry,
  });

  final EntriesRepository entries;
  final ProductsRepository products;
  final ProductService productService;
  final WidgetRegistry registry;

  /// Get product instance with all nutrient children.
  Future<ProductInstanceHierarchy?> getProductInstance(String entryId) async {
    final parent = await entries.getById(entryId);
    if (parent == null || parent.widgetKind != 'product') {
      return null;
    }

    final children = await entries.listChildrenOfParent(entryId);
    return ProductInstanceHierarchy(
      parent: parent,
      nutrientChildren: children,
      isStatic: parent.isStatic,
    );
  }

  /// Aggregate nutrients from product (direct children only).
  /// Does NOT recurse into product children - only sums direct nutrient entries.
  Future<NutrientSummary> aggregateNutrients(String productEntryId) async {
    final hierarchy = await getProductInstance(productEntryId);
    if (hierarchy == null) {
      return NutrientSummary.empty();
    }

    final nutrientsByKind = <String, double>{};
    final normalizedNutrients = <String, double>{};

    for (final child in hierarchy.nutrientChildren) {
      final payload = jsonDecode(child.payloadJson) as Map<String, dynamic>;
      final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;

      // Sum original amounts
      nutrientsByKind[child.widgetKind] = (nutrientsByKind[child.widgetKind] ?? 0.0) + amount;

      // Normalize for comparison
      final kind = registry.byId(child.widgetKind);
      final unit = kind?.unit ?? '';
      final normalized = NutrientSummary.normalizeToGrams(amount, unit);
      normalizedNutrients[child.widgetKind] = (normalizedNutrients[child.widgetKind] ?? 0.0) + normalized;
    }

    final productGrams = hierarchy.parent.productGrams?.toDouble() ?? 0.0;

    return NutrientSummary(
      totalProductGrams: productGrams,
      nutrientsByKind: nutrientsByKind,
      normalizedNutrients: normalizedNutrients,
    );
  }

  /// Reset static instance to template values.
  /// Marks instance as non-static and recalculates from template.
  Future<void> resetToTemplate(String productEntryId) async {
    final entry = await entries.getById(productEntryId);
    if (entry == null || entry.widgetKind != 'product') {
      throw Exception('Entry is not a product instance');
    }
    if (!entry.isStatic) {
      throw Exception('Entry is not static - already dynamic');
    }
    if (entry.productId == null) {
      throw Exception('Entry has no product template link');
    }

    // Recalculate from template (sets isStatic: false)
    await productService.updateParentAndChildren(
      parentEntryId: productEntryId,
      productGrams: entry.productGrams!,
      isStatic: false,
    );
  }

  /// Propagate template changes to non-static instances.
  /// When a product template is updated, this recalculates all non-static instances.
  /// Returns the number of instances that were updated.
  Future<int> propagateTemplateChange(String productId) async {
    // Get all instances of this product
    final instances = await entries.listParentsByProductId(productId);

    int updatedCount = 0;
    for (final instance in instances) {
      if (!instance.isStatic) {
        // Recalculate children from current template
        await productService.updateParentAndChildren(
          parentEntryId: instance.id,
          productGrams: instance.productGrams!,
          isStatic: false,
        );
        updatedCount++;
      }
    }

    return updatedCount;
  }
}

final productHierarchyServiceProvider = Provider<ProductHierarchyService?>((ref) {
  final e = ref.watch(entriesRepositoryProvider);
  final p = ref.watch(productsRepositoryProvider);
  final ps = ref.watch(productServiceProvider);
  final r = ref.watch(widgetRegistryProvider);
  if (e == null || p == null || ps == null) return null;
  return ProductHierarchyService(
    entries: e,
    products: p,
    productService: ps,
    registry: r,
  );
});

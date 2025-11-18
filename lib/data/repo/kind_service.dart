import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/raw_db.dart';
import '../providers.dart';
import 'entries_repository.dart';
import 'kinds_repository.dart';
import 'product_service.dart';
import 'products_repository.dart';

class KindUsage {
  KindUsage({
    required this.kindId,
    required this.productsUsing,
    required this.directEntriesCount,
  });

  final String kindId;
  final List<ProductDef> productsUsing;
  final int directEntriesCount;
}


class KindService {
  KindService({
    required this.db,
    required this.kinds,
    required this.products,
    required this.entries,
    required this.productService,
  });

  final AppDb db;
  final KindsRepository kinds;
  final ProductsRepository products;
  final EntriesRepository entries;
  final ProductService? productService;

  Future<KindUsage?> getUsage(String kindId) async {
    final k = await kinds.getKind(kindId);
    if (k == null) return null;
    final prods = await products.listProductsUsingKind(kindId);
    final direct = await entries.listDirectEntriesByKind(kindId);
    return KindUsage(
      kindId: kindId,
      productsUsing: prods,
      directEntriesCount: direct.length,
    );
  }

  Future<void> deleteKindWithSideEffects({
    required String kindId,
    required bool removeFromProducts,
    required bool deleteDirectEntries,
  }) async {
    final k = await kinds.getKind(kindId);
    if (k == null) return;
    final comps = await products.listProductComponentsByKind(kindId);
    final direct = await entries.listDirectEntriesByKind(kindId);

    // If usage exists and neither mitigation chosen, abort
    if ((comps.isNotEmpty || direct.isNotEmpty) &&
        !(removeFromProducts || deleteDirectEntries)) {
      throw StateError('Kind is in use and neither mitigation option selected');
    }

    await db.transaction(() async {
      if (deleteDirectEntries && direct.isNotEmpty) {
        await entries.deleteEntriesByIds(direct.map((e) => e.id).toList());
      }
      if (removeFromProducts && comps.isNotEmpty) {
        // Remove components for this kind across all products.
        await db.customStatement(
          'DELETE FROM product_components WHERE kind_id = ?;',
          [kindId],
        );
      }
      // Delete the kind last
      await kinds.deleteKind(kindId);
    });

    // Re-propagate affected products (sequentially) if requested
    if (removeFromProducts && productService != null) {
      final affected = comps.map((c) => c.productId).toSet().toList();
      for (final pid in affected) {
        try {
          await productService!.updateAllEntriesForProductToCurrentFormula(pid);
        } catch (_) {
          // best-effort; UI can surface errors separately
        }
      }
    }
  }
}

final kindServiceProvider = Provider<KindService?>((ref) {
  final db = ref.watch(appDbProvider);
  final kr = ref.watch(kindsRepositoryProvider);
  final pr = ref.watch(productsRepositoryProvider);
  final er = ref.watch(entriesRepositoryProvider);
  final ps = ref.watch(productServiceProvider);
  if (db == null || kr == null || pr == null || er == null) return null;
  return KindService(
    db: db,
    kinds: kr,
    products: pr,
    entries: er,
    productService: ps,
  );
});

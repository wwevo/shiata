import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/raw_db.dart';
import '../providers.dart';
import 'kinds_repository.dart';
import 'products_repository.dart';
import 'entries_repository.dart';
import 'product_service.dart';

class KindUsage {
  KindUsage({required this.kindId, required this.productsUsing, required this.directEntriesCount});
  final String kindId;
  final List<ProductDef> productsUsing;
  final int directEntriesCount;
}

class KindDeletionSnapshot {
  KindDeletionSnapshot({
    required this.kind,
    required this.components,
    required this.directEntries,
  });
  final KindDef kind;
  final List<ProductComponent> components;
  final List<EntryRecord> directEntries;
}

class KindService {
  KindService({required this.db, required this.kinds, required this.products, required this.entries, required this.productService});
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
    return KindUsage(kindId: kindId, productsUsing: prods, directEntriesCount: direct.length);
  }

  Future<KindDeletionSnapshot?> deleteKindWithSideEffects({
    required String kindId,
    required bool removeFromProducts,
    required bool deleteDirectEntries,
  }) async {
    final k = await kinds.getKind(kindId);
    if (k == null) return null;
    final comps = await products.listProductComponentsByKind(kindId);
    final direct = await entries.listDirectEntriesByKind(kindId);

    // If usage exists and neither mitigation chosen, abort
    if ((comps.isNotEmpty || direct.isNotEmpty) && !(removeFromProducts || deleteDirectEntries)) {
      throw StateError('Kind is in use and neither mitigation option selected');
    }

    final snap = KindDeletionSnapshot(kind: k, components: comps, directEntries: direct);

    await db.transaction(() async {
      if (deleteDirectEntries && direct.isNotEmpty) {
        await entries.deleteEntriesByIds(direct.map((e) => e.id).toList());
      }
      if (removeFromProducts && comps.isNotEmpty) {
        // Remove components for this kind across all products.
        await db.customStatement('DELETE FROM product_components WHERE kind_id = ?;', [kindId]);
      }
      // Delete the kind last
      await kinds.deleteKind(kindId);
    });

    // Re-propagate affected products (sequentially) if requested
    if (removeFromProducts && productService != null) {
      final affected = snap.components.map((c) => c.productId).toSet().toList();
      for (final pid in affected) {
        try {
          await productService!.updateAllEntriesForProductToCurrentFormula(pid);
        } catch (_) {
          // best-effort; UI can surface errors separately
        }
      }
    }

    return snap;
  }

  Future<void> undoKindDeletion(KindDeletionSnapshot snap) async {
    // Restore DB state in a transaction
    await db.transaction(() async {
      // Re-insert kind
      await kinds.upsertKind(snap.kind);
      // Restore product_components
      for (final c in snap.components) {
        await db.customStatement(
          'INSERT OR REPLACE INTO product_components (product_id, kind_id, amount_per_gram) VALUES (?, ?, ?);',
          [c.productId, c.kindId, c.amountPerGram],
        );
      }
      // Restore direct entries
      await entries.insertRawEntries(snap.directEntries);
    });

    // Re-propagate products to include restored kind where applicable
    if (productService != null) {
      final affected = snap.components.map((c) => c.productId).toSet().toList();
      for (final pid in affected) {
        try {
          await productService!.updateAllEntriesForProductToCurrentFormula(pid);
        } catch (_) {}
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
  return KindService(db: db, kinds: kr, products: pr, entries: er, productService: ps);
});

import 'dart:async';

import 'package:drift/drift.dart';

import '../db/raw_db.dart';

class ProductDef {
  ProductDef({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.icon,
    this.color,
  });
  final String id;
  final String name;
  final int createdAt;
  final int updatedAt;
  final bool isActive;
  final String? icon;
  final int? color;
}

class ProductComponent {
  ProductComponent({required this.productId, required this.kindId, required this.amountPerGram});
  final String productId;
  final String kindId;
  final int amountPerGram; // integer amount per 1 g of product, using the kind's canonical unit
}

class ProductsRepository {
  ProductsRepository({required this.db}) : _ready = db.ensureInitialized();
  final AppDb db;
  final Future<void> _ready;

  final _changes = StreamController<void>.broadcast();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> upsertProduct(ProductDef p) async {
    await _ready;
    await db.customStatement(
      'INSERT INTO products (id, name, created_at, updated_at, is_active, icon, color) VALUES (?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET name=excluded.name, updated_at=excluded.updated_at, is_active=excluded.is_active, icon=excluded.icon, color=excluded.color;',
      [p.id, p.name, p.createdAt, p.updatedAt, p.isActive ? 1 : 0, p.icon, p.color],
    );
    _notify();
  }

  Future<ProductDef?> getProduct(String productId) async {
    await _ready;
    final rows = await db.customSelect(
      'SELECT * FROM products WHERE id = ? LIMIT 1;',
      variables: [Variable.withString(productId)],
      readsFrom: const {},
    ).get();
    if (rows.isEmpty) return null;
    final r = rows.first.data;
    return ProductDef(
      id: r['id'] as String,
      name: r['name'] as String,
      createdAt: r['created_at'] as int,
      updatedAt: r['updated_at'] as int,
      isActive: (r['is_active'] as int) != 0,
      icon: r['icon'] as String?,
      color: r['color'] as int?,
    );
  }

  Future<List<ProductDef>> listProducts({bool onlyActive = true}) async {
    await _ready;
    final where = onlyActive ? 'WHERE is_active = 1' : '';
    final rows = await db.customSelect(
      'SELECT * FROM products $where ORDER BY name ASC;',
      readsFrom: const {},
    ).get();
    return rows.map((r) {
      final d = r.data;
      return ProductDef(
        id: d['id'] as String,
        name: d['name'] as String,
        createdAt: d['created_at'] as int,
        updatedAt: d['updated_at'] as int,
        isActive: (d['is_active'] as int) != 0,
        icon: d['icon'] as String?,
        color: d['color'] as int?,
      );
    }).toList();
  }

  Future<void> setComponents(String productId, List<ProductComponent> components) async {
    await _ready;
    await db.transaction(() async {
      // Remove existing
      await db.customStatement('DELETE FROM product_components WHERE product_id = ?;', [productId]);
      // Insert new
      for (final c in components) {
        await db.customStatement(
          'INSERT INTO product_components (product_id, kind_id, amount_per_gram) VALUES (?, ?, ?);',
          [productId, c.kindId, c.amountPerGram],
        );
      }
    });
    _notify();
  }

  Future<void> deleteProduct(String productId) async {
    await _ready;
    await db.transaction(() async {
      await db.customStatement('DELETE FROM product_components WHERE product_id = ?;', [productId]);
      await db.customStatement('DELETE FROM products WHERE id = ?;', [productId]);
    });
    _notify();
  }

  Future<List<ProductComponent>> getComponents(String productId) async {
    await _ready;
    final rows = await db.customSelect(
      'SELECT * FROM product_components WHERE product_id = ? ORDER BY kind_id ASC;',
      variables: [Variable.withString(productId)],
      readsFrom: const {},
    ).get();
    return rows.map((r) {
      final d = r.data;
      return ProductComponent(
        productId: d['product_id'] as String,
        kindId: d['kind_id'] as String,
        amountPerGram: d['amount_per_gram'] as int,
      );
    }).toList();
  }

  Stream<List<ProductDef>> watchProducts({bool onlyActive = true}) async* {
    yield await listProducts(onlyActive: onlyActive);
    await for (final _ in _changes.stream) {
      yield await listProducts(onlyActive: onlyActive);
    }
  }
}

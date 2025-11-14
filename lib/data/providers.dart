import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/db_handle.dart';
import 'db/raw_db.dart';
import 'repo/entries_repository.dart';
import 'repo/kinds_repository.dart';
import 'repo/products_repository.dart';
import 'repo/recipes_repository.dart';

/// Provides an [AppDb] instance when the low-level [QueryExecutor] is available.
final appDbProvider = Provider<AppDb?>((ref) {
  final execAsync = ref.watch(dbHandleProvider);
  return execAsync.maybeWhen(
    data: (exec) {
      if (exec == null) return null;
      final db = AppDb(exec);
      // Ensure schema is initialized once; ignore errors here, surface in repo calls
      // to avoid rebuild loops.
      // Use microtask to avoid synchronous setState during build.
      scheduleMicrotask(() async {
        try {
          await db.ensureInitialized();
        } catch (_) {
          // Ignored here; repository operations will surface errors.
        }
      });
      return db;
    },
    orElse: () => null,
  );
});

final entriesRepositoryProvider = Provider<EntriesRepository?>((ref) {
  final db = ref.watch(appDbProvider);
  if (db == null) return null;
  final repo = EntriesRepository(db: db);
  return repo;
});

final productsRepositoryProvider = Provider<ProductsRepository?>((ref) {
  final db = ref.watch(appDbProvider);
  if (db == null) return null;
  return ProductsRepository(db: db);
});

final kindsRepositoryProvider = Provider<KindsRepository?>((ref) {
  final db = ref.watch(appDbProvider);
  if (db == null) return null;
  return KindsRepository(db: db);
});

final recipesRepositoryProvider = Provider<RecipesRepository?>((ref) {
  final db = ref.watch(appDbProvider);
  if (db == null) return null;
  return RecipesRepository(db: db);
});

// FIXED: Use consistent pattern for all three stream providers
final kindsListProvider = StreamProvider<List<KindDef>>((ref) {
  final repo = ref.watch(kindsRepositoryProvider);
  if (repo == null) return Stream.value(<KindDef>[]);
  return repo.watchKinds();
});

final productsListProvider = StreamProvider<List<ProductDef>>((ref) {
  final repo = ref.watch(productsRepositoryProvider);
  if (repo == null) return Stream.value(<ProductDef>[]);
  return repo.watchProducts(onlyActive: true);
});

final recipesListProvider = StreamProvider<List<RecipeDef>>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  if (repo == null) return Stream.value(<RecipeDef>[]);
  return repo.watchRecipes(onlyActive: true);
});

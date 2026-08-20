import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/db_handle.dart';
import 'db/raw_db.dart';
import 'repo/entries_repository.dart';
import 'repo/kinds_repository.dart';
import 'repo/products_repository.dart';
import 'repo/recipes_repository.dart';
import 'repo/units_repository.dart';
import '../ui/main_screen_providers.dart';
import '../ui/ux_config.dart';

/// Provides an [AppDb] instance when the low-level [QueryExecutor] is available.
final appDbProvider = Provider<AppDb?>((ref) {
  final execAsync = ref.watch(dbHandleProvider);
  return execAsync.maybeWhen(
    data: (exec) {
      if (exec == null) return null;
      final db = AppDb(exec);
      ref.onDispose(() => db.close());
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

final unitsRepositoryProvider = Provider<UnitsRepository?>((ref) {
  final db = ref.watch(appDbProvider);
  if (db == null) return null;
  return UnitsRepository(db: db);
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

final allProductsListProvider = StreamProvider<List<ProductDef>>((ref) {
  final repo = ref.watch(productsRepositoryProvider);
  if (repo == null) return Stream.value(<ProductDef>[]);
  return repo.watchProducts(onlyActive: false);
});

final recipesListProvider = StreamProvider<List<RecipeDef>>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  if (repo == null) return Stream.value(<RecipeDef>[]);
  return repo.watchRecipes(onlyActive: true);
});

final allRecipesListProvider = StreamProvider<List<RecipeDef>>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  if (repo == null) return Stream.value(<RecipeDef>[]);
  return repo.watchRecipes(onlyActive: false);
});

final unitsListProvider = StreamProvider<List<UnitDef>>((ref) {
  final repo = ref.watch(unitsRepositoryProvider);
  if (repo == null) return Stream.value(<UnitDef>[]);
  return repo.watchUnits();
});

final allEntriesWithChildrenProvider = StreamProvider<List<EntryRecord>>((ref) {
  final repo = ref.watch(entriesRepositoryProvider);
  if (repo == null) return Stream.value(<EntryRecord>[]);
  return repo.watchAllEntriesWithChildren();
});

final allRecipeComponentsProvider = StreamProvider<List<RecipeComponentDef>>((ref) {
  final repo = ref.watch(recipesRepositoryProvider);
  if (repo == null) return Stream.value(<RecipeComponentDef>[]);
  return repo.watchAllComponents();
});

final allProductComponentsProvider = StreamProvider<List<ProductComponent>>((ref) {
  final repo = ref.watch(productsRepositoryProvider);
  if (repo == null) return Stream.value(<ProductComponent>[]);
  return repo.watchAllComponents();
});

final recipeComponentsProvider =
    StreamProvider.family<List<RecipeComponentDef>, String>((ref, recipeId) {
  final repo = ref.watch(recipesRepositoryProvider);
  if (repo == null) return Stream.value(<RecipeComponentDef>[]);
  return repo.watchComponents(recipeId);
});

final entriesForSelectedDayProvider = StreamProvider<List<EntryRecord>>((ref) {
  final repo = ref.watch(entriesRepositoryProvider);
  final selected = ref.watch(selectedDayProvider);
  if (repo == null || selected == null) return Stream.value(<EntryRecord>[]);
  return repo.watchByDay(selected);
});

final calendarEntriesProvider =
    StreamProvider<Map<DateTime, List<EntryRecord>>>((ref) {
  final repo = ref.watch(entriesRepositoryProvider);
  final anchor = ref.watch(calendarAnchorProvider);
  final config = ref.watch(uxConfigProvider);
  if (repo == null) return Stream.value(<DateTime, List<EntryRecord>>{});

  // Calculate range same as WeeklyCalendar
  final grid = config.calendarGrid;
  final daysToShow = grid.columns * grid.rows;

  final startLocal = anchor;
  final endLocal = anchor.add(Duration(days: daysToShow));

  return repo
      .watchByDayRange(startLocal, endLocal, onlyShowInCalendar: true)
      .cast<Map<DateTime, List<EntryRecord>>>();
});

final weeklyOverviewEntriesProvider = StreamProvider<dynamic>((ref) {
  final repo = ref.watch(entriesRepositoryProvider);
  if (repo == null) return Stream.value(<EntryRecord>[]);

  // Calculate range same as WeeklyOverviewPanel
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final nextMonday = monday.add(const Duration(days: 7));

  return repo.watchByDayRange(
    monday,
    nextMonday,
    onlyShowInCalendar: false,
  );
});

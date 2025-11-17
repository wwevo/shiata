/// Centralized search service for context-aware filtering across all app sections.
///
/// This service provides search methods for:
/// - Kinds (nutrient types)
/// - Products (food templates)
/// - Recipes (meal templates)
/// - Entries (calendar instances) with date-based filtering
library;

import 'package:shiata/data/repo/entries_repository.dart';
import 'package:shiata/data/repo/kinds_repository.dart';
import 'package:shiata/data/repo/products_repository.dart';
import 'package:shiata/data/repo/recipes_repository.dart';

class SearchService {
  final KindsRepository kindsRepo;
  final ProductsRepository productsRepo;
  final RecipesRepository recipesRepo;
  final EntriesRepository entriesRepo;

  SearchService({
    required this.kindsRepo,
    required this.productsRepo,
    required this.recipesRepo,
    required this.entriesRepo,
  });

  /// Searches kinds by name (case-insensitive).
  Stream<List<KindDef>> searchKinds(String query) async* {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) {
      yield await kindsRepo.listKinds();
      return;
    }

    final allKinds = await kindsRepo.listKinds();
    yield allKinds
        .where((k) => k.name.toLowerCase().contains(normalized))
        .toList();
  }

  /// Searches products by name (case-insensitive), only active products.
  Stream<List<ProductDef>> searchProducts(String query) async* {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) {
      yield await productsRepo.listProducts(onlyActive: true);
      return;
    }

    final allProducts = await productsRepo.listProducts(onlyActive: true);
    yield allProducts
        .where((p) => p.name.toLowerCase().contains(normalized))
        .toList();
  }

  /// Searches recipes by name (case-insensitive), only active recipes.
  Stream<List<RecipeDef>> searchRecipes(String query) async* {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) {
      yield await recipesRepo.listRecipes(onlyActive: true);
      return;
    }

    final allRecipes = await recipesRepo.listRecipes(onlyActive: true);
    yield allRecipes
        .where((r) => r.name.toLowerCase().contains(normalized))
        .toList();
  }

  /// Searches entries for a specific day (local date).
  /// Uses the existing repository search with date filtering.
  Stream<List<EntryRecord>> searchEntriesForDay(
    String query,
    DateTime localDate,
  ) async* {
    final normalized = query.toLowerCase().trim();

    // Get all entries for the day
    await for (final dayEntries in entriesRepo.watchByDay(localDate)) {
      if (normalized.isEmpty) {
        yield dayEntries;
        continue;
      }

      // Filter by widget_kind and payload_json content
      yield dayEntries.where((entry) {
        final widgetKindMatch = entry.widgetKind.toLowerCase().contains(
          normalized,
        );
        final payloadMatch = entry.payloadJson.toLowerCase().contains(
          normalized,
        );
        return widgetKindMatch || payloadMatch;
      }).toList();
    }
  }

  /// Searches entries within a date range (e.g., last 7 days).
  /// Used for weekly overview.
  Stream<List<EntryRecord>> searchEntriesInDateRange(
    String query,
    DateTime startLocal,
    DateTime endLocal,
  ) async* {
    final normalized = query.toLowerCase().trim();

    // Get all entries in range
    await for (final entriesByDay in entriesRepo.watchByDayRange(
      startLocal,
      endLocal,
      onlyShowInCalendar: false, // Include all entries
    )) {
      final allEntries = entriesByDay.values.expand((e) => e).toList();

      if (normalized.isEmpty) {
        yield allEntries;
        continue;
      }

      // Filter by content
      yield allEntries.where((entry) {
        final widgetKindMatch = entry.widgetKind.toLowerCase().contains(
          normalized,
        );
        final payloadMatch = entry.payloadJson.toLowerCase().contains(
          normalized,
        );
        return widgetKindMatch || payloadMatch;
      }).toList();
    }
  }

  /// Searches all entries in the database.
  /// Uses the existing repository global search (limit: 200 results).
  Stream<List<EntryRecord>> searchAllEntries(String query) {
    final normalized = query.trim();
    return entriesRepo.watchSearch(normalized);
  }
}

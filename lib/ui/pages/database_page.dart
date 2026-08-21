import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../data/repo/import_export_service.dart';
import '../../domain/widgets/registry.dart';
import '../widgets/entry_list_item_factory.dart';
import '../main_screen_providers.dart';

enum WipeMode {
  blank,
  demo,
  import,
}

class DatabasePage extends ConsumerStatefulWidget {
  const DatabasePage({super.key});

  @override
  ConsumerState<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends ConsumerState<DatabasePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(databaseTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database')),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(text: 'Entries'),
              Tab(text: 'Kinds'),
              Tab(text: 'Products'),
              Tab(text: 'Recipes'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildEntriesSection(),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildKindsSection(),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildProductsSection(),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildRecipesSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildKindsSection() {
    final kindsAsync = ref.watch(kindsListProvider);
    final selectedIds = ref.watch(bulkSelectionProvider);
    final registry = ref.watch(widgetRegistryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kinds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                kindsAsync.whenData((kinds) {
                  final newSelected = {...selectedIds};
                  final kindIds = kinds.map((k) => k.id).toSet();
                  if (kindIds.every(newSelected.containsKey)) {
                    for (final id in kindIds) {
                      newSelected.remove(id);
                    }
                  } else {
                    for (final id in kindIds) {
                      newSelected[id] = SelectionCategory.kinds;
                    }
                  }
                  ref.read(bulkSelectionProvider.notifier).state = newSelected;
                  ref.read(selectionModeProvider.notifier).state =
                      newSelected.isNotEmpty;
                });
              },
              child: kindsAsync.maybeWhen(
                data: (kinds) {
                  final kindIds = kinds.map((k) => k.id).toSet();
                  final allSelected = kindIds.isNotEmpty &&
                      kindIds.every(selectedIds.containsKey);
                  return Text(allSelected ? 'Deselect All' : 'Select All');
                },
                orElse: () => const Text('Select All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        kindsAsync.when(
          data: (kinds) {
            if (kinds.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No kinds available'),
              );
            }
            return Column(
              children: kinds.map((k) {
                return EntryListItemFactory.buildEntry(
                  context: context,
                  ref: ref,
                  entry: k,
                  childrenByParent: const {},
                  registry: registry,
                  displayMode: EntryDisplayMode.checkbox,
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error: $e'),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export Selected'),
          onPressed: selectedIds.isEmpty ? null : _exportSelected,
        ),
      ],
    );
  }

  Widget _buildProductsSection() {
    final productsAsync = ref.watch(allProductsListProvider);
    final selectedIds = ref.watch(bulkSelectionProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final hierarchy = ref.watch(managementHierarchyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            productsAsync.maybeWhen(
              data: (products) => TextButton(
                onPressed: products.isEmpty
                    ? null
                    : () {
                        final newSelected = {...selectedIds};
                        final prodIds = products.map((p) => p.id).toSet();
                        if (prodIds.every(newSelected.containsKey)) {
                          for (final id in prodIds) {
                            newSelected.remove(id);
                          }
                        } else {
                          for (final id in prodIds) {
                            newSelected[id] = SelectionCategory.products;
                          }
                        }
                        ref.read(bulkSelectionProvider.notifier).state =
                            newSelected;
                        ref.read(selectionModeProvider.notifier).state =
                            newSelected.isNotEmpty;
                      },
                child: Builder(
                  builder: (ctx) {
                    final prodIds = products.map((p) => p.id).toSet();
                    final allSelected = prodIds.isNotEmpty &&
                        prodIds.every(selectedIds.containsKey);
                    return Text(allSelected ? 'Deselect All' : 'Select All');
                  },
                ),
              ),
              orElse: () => const TextButton(
                onPressed: null,
                child: Text('Select All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        productsAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No products available'),
              );
            }
            return Column(
              children: products.map((p) {
                return EntryListItemFactory.buildEntry(
                  context: context,
                  ref: ref,
                  entry: p,
                  childrenByParent: hierarchy,
                  registry: registry,
                  displayMode: EntryDisplayMode.checkbox,
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error: $e'),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export Selected'),
          onPressed: selectedIds.isEmpty ? null : _exportSelected,
        ),
      ],
    );
  }

  Widget _buildRecipesSection() {
    final recipesAsync = ref.watch(allRecipesListProvider);
    final selectedIds = ref.watch(bulkSelectionProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final hierarchy = ref.watch(managementHierarchyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recipes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            recipesAsync.maybeWhen(
              data: (recipes) => TextButton(
                onPressed: recipes.isEmpty
                    ? null
                    : () {
                        final newSelected = {...selectedIds};
                        final recIds = recipes.map((r) => r.id).toSet();
                        if (recIds.every(newSelected.containsKey)) {
                          for (final id in recIds) {
                            newSelected.remove(id);
                          }
                        } else {
                          for (final id in recIds) {
                            newSelected[id] = SelectionCategory.recipes;
                          }
                        }
                        ref.read(bulkSelectionProvider.notifier).state =
                            newSelected;
                        ref.read(selectionModeProvider.notifier).state =
                            newSelected.isNotEmpty;
                      },
                child: Builder(
                  builder: (ctx) {
                    final recIds = recipes.map((r) => r.id).toSet();
                    final allSelected = recIds.isNotEmpty &&
                        recIds.every(selectedIds.containsKey);
                    return Text(allSelected ? 'Deselect All' : 'Select All');
                  },
                ),
              ),
              orElse: () => const TextButton(
                onPressed: null,
                child: Text('Select All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        recipesAsync.when(
          data: (recipes) {
            if (recipes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No recipes available'),
              );
            }
            return Column(
              children: recipes.map((r) {
                return EntryListItemFactory.buildEntry(
                  context: context,
                  ref: ref,
                  entry: r,
                  childrenByParent: hierarchy,
                  registry: registry,
                  displayMode: EntryDisplayMode.checkbox,
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error: $e'),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export Selected'),
          onPressed: selectedIds.isEmpty ? null : _exportSelected,
        ),
      ],
    );
  }

  Widget _buildEntriesSection() {
    final entriesAsync = ref.watch(allEntriesWithChildrenProvider);
    final sortMode = ref.watch(entrySortModeProvider);
    final typeFilter = ref.watch(entryTypeFilterProvider);
    final selectedIds = ref.watch(bulkSelectionProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Calendar Entries',
              style: theme.textTheme.titleMedium,
            ),
            entriesAsync.maybeWhen(
              data: (allEntries) {
                // Only count top-level entries for "Select All"
                final topLevel = allEntries
                    .where(
                      (e) => e.sourceEntryId == null || e.sourceEntryId!.isEmpty,
                    )
                    .toList();
                return TextButton(
                  onPressed: topLevel.isEmpty
                      ? null
                      : () {
                          final newSelected = {...selectedIds};
                          final topLevelIds = topLevel.map((e) => e.id).toSet();
                          if (topLevelIds.every(newSelected.containsKey)) {
                            for (final id in topLevelIds) {
                              newSelected.remove(id);
                            }
                          } else {
                            for (final id in topLevelIds) {
                              newSelected[id] = SelectionCategory.entries;
                            }
                            // Auto-select dependencies
                            for (final entry in topLevel) {
                              _autoSelectDependencies(entry, newSelected);
                            }
                          }
                          ref.read(bulkSelectionProvider.notifier).state =
                              newSelected;
                          ref.read(selectionModeProvider.notifier).state =
                              newSelected.isNotEmpty;
                        },
                  child: Builder(
                    builder: (ctx) {
                      final topLevelIds = topLevel.map((e) => e.id).toSet();
                      final allSelected = topLevelIds.isNotEmpty &&
                          topLevelIds.every(selectedIds.containsKey);
                      return Text(allSelected ? 'Deselect All' : 'Select All');
                    },
                  ),
                );
              },
              orElse: () => const TextButton(
                onPressed: null,
                child: Text('Select All'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        entriesAsync.when(
          data: (allEntries) {
            if (allEntries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('No entries available'),
              );
            }

            // Build hierarchy: childrenByParent map from ALL entries
            final childrenByParent = <String, List<EntryRecord>>{};
            for (final entry in allEntries) {
              final parentId = entry.sourceEntryId;
              if (parentId != null && parentId.isNotEmpty) {
                childrenByParent.putIfAbsent(parentId, () => []).add(entry);
              }
            }

            // Get only top-level entries (those without sourceEntryId)
            var topLevelEntries = allEntries
                .where(
                  (e) => e.sourceEntryId == null || e.sourceEntryId!.isEmpty,
                )
                .toList();

            // Apply type filter
            if (typeFilter.isNotEmpty) {
              topLevelEntries = topLevelEntries.where((e) {
                if (e.widgetKind == 'product') {
                  return typeFilter.contains('product');
                } else if (e.widgetKind == 'recipe') {
                  return typeFilter.contains('recipe');
                } else {
                  return typeFilter.contains('kind');
                }
              }).toList();
            }

            // Apply sort mode
            if (sortMode == EntrySortMode.oldest) {
              topLevelEntries.sort((a, b) => a.targetAt.compareTo(b.targetAt));
            } else {
              topLevelEntries.sort((a, b) => b.targetAt.compareTo(a.targetAt));
            }

            // Get registry for icons/colors
            final registry = ref.watch(widgetRegistryProvider);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter and Sort UI
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('Kinds'),
                            selected: typeFilter.contains('kind'),
                            onSelected: (selected) {
                              final newSet = {...typeFilter};
                              if (selected) {
                                newSet.add('kind');
                              } else {
                                newSet.remove('kind');
                              }
                              ref
                                  .read(entryTypeFilterProvider.notifier)
                                  .state = newSet;
                            },
                          ),
                          FilterChip(
                            label: const Text('Products'),
                            selected: typeFilter.contains('product'),
                            onSelected: (selected) {
                              final newSet = {...typeFilter};
                              if (selected) {
                                newSet.add('product');
                              } else {
                                newSet.remove('product');
                              }
                              ref
                                  .read(entryTypeFilterProvider.notifier)
                                  .state = newSet;
                            },
                          ),
                          FilterChip(
                            label: const Text('Recipes'),
                            selected: typeFilter.contains('recipe'),
                            onSelected: (selected) {
                              final newSet = {...typeFilter};
                              if (selected) {
                                newSet.add('recipe');
                              } else {
                                newSet.remove('recipe');
                              }
                              ref
                                  .read(entryTypeFilterProvider.notifier)
                                  .state = newSet;
                            },
                          ),
                          if (typeFilter.isNotEmpty)
                            ActionChip(
                              label: const Text('Clear All'),
                              onPressed: () {
                                ref
                                    .read(entryTypeFilterProvider.notifier)
                                    .state = {};
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sort by Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('Newest First'),
                            selected: sortMode == EntrySortMode.newest,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(entrySortModeProvider.notifier)
                                    .state = EntrySortMode.newest;
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Oldest First'),
                            selected: sortMode == EntrySortMode.oldest,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(entrySortModeProvider.notifier)
                                    .state = EntrySortMode.oldest;
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (topLevelEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        typeFilter.isNotEmpty
                            ? 'No entries match selected filters'
                            : 'No entries available',
                      ),
                    ),
                  )
                else
                  ...topLevelEntries.map((entry) {
                  return EntryListItemFactory.buildEntry(
                    context: context,
                    ref: ref,
                    entry: entry,
                    childrenByParent: childrenByParent,
                    registry: registry,
                    config: EntryListItemConfig.fullDateTime,
                    displayMode: EntryDisplayMode.checkbox,
                  );
                }),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export Selected'),
                      onPressed: selectedIds.isEmpty
                          ? null
                          : _exportSelected,
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Error: $e'),
          ),
        ),
      ],
    );
  }

  void _autoSelectDependencies(
      EntryRecord entry, Map<String, SelectionCategory> selection) {
    // Auto-select kinds
    if (entry.productId == null &&
        entry.recipeId == null &&
        entry.sourceEntryId == null) {
      // This is a direct kind entry
      selection[entry.widgetKind] = SelectionCategory.kinds;
    }

    // Auto-select products
    if (entry.productId != null) {
      selection[entry.productId!] = SelectionCategory.products;
    }

    // Auto-select recipes
    if (entry.recipeId != null) {
      selection[entry.recipeId!] = SelectionCategory.recipes;
    }
  }

  Future<void> _exportSelected() async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      _showSnackBar('Service not ready');
      return;
    }

    try {
      final selectedIds = ref.read(bulkSelectionProvider);
      final kinds = ref.read(kindsListProvider).value ?? [];
      final products = ref.read(allProductsListProvider).value ?? [];
      final recipes = ref.read(allRecipesListProvider).value ?? [];
      final entries = ref.read(allEntriesWithChildrenProvider).value ?? [];

      final selectedKinds =
          kinds.map((k) => k.id).where(selectedIds.containsKey).toList();
      final selectedProducts =
          products.map((p) => p.id).where(selectedIds.containsKey).toList();
      final selectedRecipes =
          recipes.map((r) => r.id).where(selectedIds.containsKey).toList();
      final selectedEntries =
          entries.map((e) => e.id).where(selectedIds.containsKey).toList();

      final bundle = await svc.exportSelected(
        kindIds: selectedKinds,
        productIds: selectedProducts,
        recipeIds: selectedRecipes,
        entryIds: selectedEntries,
      );

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final fileName = 'shiata_selected_export_$timestamp.json';

      final encoder = const JsonEncoder.withIndent('  ');
      final text = encoder.convert(bundle);
      final bytes = utf8.encode(text);

      final outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Selected Export',
        fileName: fileName,
        bytes: bytes,
      );

      if (outputFile != null && !kIsWeb) {
        final file = File(outputFile.toFilePath());
        await file.writeAsBytes(bytes);
      }

      if (mounted && (outputFile != null || kIsWeb)) {
        _showSnackBar('Export saved successfully');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Export failed: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

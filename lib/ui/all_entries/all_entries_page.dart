import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../main_screen_providers.dart';
import '../widgets/entry_list_item_factory.dart';

/// Page that displays all instance entries (no children, no templates) with filtering,
/// sorting, bulk selection, and deletion capabilities.
///
/// Features:
/// - Filter by entry type (nutrients/products/recipes)
/// - Sort by date (newest/oldest)
/// - Search filter (uses existing searchQueryProvider)
/// - Bulk delete with undo support
/// - Scroll position restoration
class AllEntriesPage extends ConsumerStatefulWidget {
  const AllEntriesPage({super.key});

  @override
  ConsumerState<AllEntriesPage> createState() => _AllEntriesPageState();
}

class _AllEntriesPageState extends ConsumerState<AllEntriesPage> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedEntries = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final sortMode = ref.watch(entrySortModeProvider);
    final typeFilter = ref.watch(entryTypeFilterProvider);
    final theme = Theme.of(context);

    if (repo == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Entries')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('All Entries (${_selectedEntries.length} selected)'),
      ),
      body: StreamBuilder<List<EntryRecord>>(
        stream: repo.watchAllEntriesWithChildren(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEntries = snapshot.data ?? <EntryRecord>[];

          // Build hierarchy: childrenByParent map from ALL entries
          final childrenByParent = <String, List<EntryRecord>>{};
          for (final entry in allEntries) {
            if (entry.sourceEntryId != null && entry.sourceEntryId!.isNotEmpty) {
              childrenByParent.putIfAbsent(entry.sourceEntryId!, () => []).add(
                entry,
              );
            }
          }

          // Get only top-level entries for filtering and display
          var entries = allEntries
              .where((e) => e.sourceEntryId == null || e.sourceEntryId!.isEmpty)
              .toList();

          // Apply type filter (empty = show all)
          if (typeFilter.isNotEmpty) {
            entries = entries.where((e) {
              // Determine entry type: 'kind' for direct nutrients, 'product', 'recipe'
              if (e.widgetKind == 'product') {
                return typeFilter.contains('product');
              } else if (e.widgetKind == 'recipe') {
                return typeFilter.contains('recipe');
              } else {
                // Direct kind entry (nutrient)
                return typeFilter.contains('kind');
              }
            }).toList();
          }

          // Apply search filter
          if (searchQuery.trim().isNotEmpty) {
            final normalized = searchQuery.toLowerCase().trim();
            entries = entries.where((e) {
              final widgetKindMatch = e.widgetKind.toLowerCase().contains(
                normalized,
              );
              final payloadMatch = e.payloadJson.toLowerCase().contains(
                normalized,
              );
              return widgetKindMatch || payloadMatch;
            }).toList();
          }

          // Apply sort mode
          if (sortMode == EntrySortMode.oldest) {
            entries.sort((a, b) => a.targetAt.compareTo(b.targetAt));
          } else {
            // Newest first (default)
            entries.sort((a, b) => b.targetAt.compareTo(a.targetAt));
          }

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _buildEmptyMessage(searchQuery, typeFilter),
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              // Filter chips
              Container(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Type filter chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('Nutrients'),
                            selected: typeFilter.contains('kind'),
                            onSelected: (selected) {
                              final newSet = {...typeFilter};
                              if (selected) {
                                newSet.add('kind');
                              } else {
                                newSet.remove('kind');
                              }
                              ref.read(entryTypeFilterProvider.notifier).state =
                                  newSet;
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
                              ref.read(entryTypeFilterProvider.notifier).state =
                                  newSet;
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
                              ref.read(entryTypeFilterProvider.notifier).state =
                                  newSet;
                            },
                          ),
                          // Clear type filters button
                          if (typeFilter.isNotEmpty)
                            ActionChip(
                              label: const Text('Clear Filters'),
                              onPressed: () {
                                ref
                                    .read(entryTypeFilterProvider.notifier)
                                    .state = {};
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Sort chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('Newest First'),
                            selected: sortMode == EntrySortMode.newest,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(entrySortModeProvider.notifier).state =
                                    EntrySortMode.newest;
                              }
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Oldest First'),
                            selected: sortMode == EntrySortMode.oldest,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(entrySortModeProvider.notifier).state =
                                    EntrySortMode.oldest;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              // Bulk actions bar
              if (_selectedEntries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: theme.colorScheme.primaryContainer,
                  child: Row(
                    children: [
                      Text(
                        '${_selectedEntries.length} selected',
                        style: theme.textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedEntries.clear();
                          });
                        },
                        child: const Text('Deselect All'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Selected'),
                        onPressed: () => _bulkDelete(entries),
                      ),
                    ],
                  ),
                ),
              // Entry list
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: entries.length,
                  itemBuilder: (ctx, index) {
                    final entry = entries[index];
                    return EntryListItemFactory.buildEntry(
                      context: context,
                      ref: ref,
                      entry: entry,
                      childrenByParent: childrenByParent,
                      registry: registry,
                      config: EntryListItemConfig.fullDateTime,
                      displayMode: EntryDisplayMode.checkbox,
                      selectedIds: _selectedEntries,
                      onSelectionChanged: (entryId, selected) {
                        setState(() {
                          if (selected) {
                            _selectedEntries.add(entryId);
                          } else {
                            _selectedEntries.remove(entryId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildEmptyMessage(String query, Set<String> typeFilter) {
    if (query.trim().isNotEmpty && typeFilter.isNotEmpty) {
      return 'No entries found for "$query" with selected filters';
    } else if (query.trim().isNotEmpty) {
      return 'No entries found for "$query"';
    } else if (typeFilter.isNotEmpty) {
      return 'No entries found with selected filters';
    } else {
      return 'No entries in database';
    }
  }

  Future<void> _bulkDelete(List<EntryRecord> allEntries) async {
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) return;

    final messenger = ScaffoldMessenger.of(context);

    // Build summary of what will be deleted
    int nutrientCount = 0;
    int productCount = 0;
    int recipeCount = 0;

    for (final id in _selectedEntries) {
      final entry = allEntries.firstWhere((e) => e.id == id);
      if (entry.widgetKind == 'product') {
        productCount++;
      } else if (entry.widgetKind == 'recipe') {
        recipeCount++;
      } else {
        nutrientCount++;
      }
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Entries?'),
        content: Text(
          'This will delete:\n'
          '• $nutrientCount nutrient entries\n'
          '• $productCount product entries (with components)\n'
          '• $recipeCount recipe entries (with components)\n\n'
          'Total: ${_selectedEntries.length} entries\n\n'
          'You can undo this action from the snackbar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Collect all entries to delete and their data for undo
    final entriesToDelete = <EntryRecord>[];
    final childrenToDelete = <EntryRecord>[];

    for (final id in _selectedEntries) {
      final entry = allEntries.firstWhere((e) => e.id == id);
      entriesToDelete.add(entry);

      // Collect children for products/recipes
      if (entry.widgetKind == 'product' || entry.widgetKind == 'recipe') {
        final children = await repo.listChildrenOfParent(id);
        childrenToDelete.addAll(children);
      }
    }

    // Delete all entries (parent + children)
    for (final entry in entriesToDelete) {
      if (entry.widgetKind == 'product' || entry.widgetKind == 'recipe') {
        await repo.deleteChildrenOfParent(entry.id);
      }
      await repo.delete(entry.id);
    }

    if (!mounted) return;

    setState(() {
      _selectedEntries.clear();
    });

    // Show snackbar with undo
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted ${entriesToDelete.length} entries'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            // Restore all entries
            final allToRestore = [...entriesToDelete, ...childrenToDelete];
            await repo.insertRawEntries(allToRestore);
          },
        ),
      ),
    );
  }
}

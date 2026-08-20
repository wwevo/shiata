import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/db/db_handle.dart';
import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../data/repo/import_export_service.dart';
import '../../domain/widgets/registry.dart';
import '../widgets/entry_list_item_factory.dart';
import '../widgets/icon_resolver.dart';
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

class _DatabasePageState extends ConsumerState<DatabasePage> {
  // Selection state for fine-grained export
  final Set<String> _selectedKinds = {};
  final Set<String> _selectedProducts = {};
  final Set<String> _selectedRecipes = {};
  final Set<String> _selectedEntries = {};

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(title: const Text('Database')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFullOperationsSection(),
            ),
            TabBar(
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
      ),
    );
  }

  Widget _buildFullOperationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Database Operations',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Export, import, or wipe the entire database including all kinds, products, recipes, and calendar entries.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export All'),
              onPressed: _exportAll,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('Import All'),
              onPressed: _importAll,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Wipe Database'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _wipeDatabase,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKindsSection() {
    final kindsAsync = ref.watch(kindsListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kinds (${_selectedKinds.length} selected)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextButton(
              onPressed: () {
                kindsAsync.whenData((kinds) {
                  setState(() {
                    if (_selectedKinds.length == kinds.length) {
                      _selectedKinds.clear();
                    } else {
                      _selectedKinds.addAll(kinds.map((k) => k.id));
                    }
                  });
                });
              },
              child: kindsAsync.maybeWhen(
                data: (kinds) => Text(
                  _selectedKinds.length == kinds.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
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
                final icon = resolveIcon(k.icon, Icons.category);
                final color = Color(k.color ?? 0xFF607D8B);
                final isSelected = _selectedKinds.contains(k.id);
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Icon(icon, color: Colors.white),
                    ),
                    title: Text(k.name),
                    subtitle: Text(
                      '${k.unit}  •  min ${k.min}  •  max ${k.max}',
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedKinds.add(k.id);
                          } else {
                            _selectedKinds.remove(k.id);
                          }
                        });
                      },
                    ),
                  ),
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
          label: const Text('Export Selected Kinds'),
          onPressed: _selectedKinds.isEmpty ? null : _exportSelected,
        ),
      ],
    );
  }

  Widget _buildProductsSection() {
    final productsAsync = ref.watch(allProductsListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Products (${_selectedProducts.length} selected)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            productsAsync.maybeWhen(
              data: (products) => TextButton(
                onPressed: products.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (_selectedProducts.length == products.length) {
                            _selectedProducts.clear();
                          } else {
                            _selectedProducts.addAll(
                              products.map((p) => p.id),
                            );
                          }
                        });
                      },
                child: Text(
                  _selectedProducts.length == products.length
                      ? 'Deselect All'
                      : 'Select All',
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
                final isSelected = _selectedProducts.contains(p.id);
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.shopping_basket, color: Colors.white),
                    ),
                    title: Text(p.name),
                    subtitle: Text(p.id),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedProducts.add(p.id);
                          } else {
                            _selectedProducts.remove(p.id);
                          }
                        });
                      },
                    ),
                  ),
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
          label: const Text('Export Selected Products'),
          onPressed: _selectedProducts.isEmpty ? null : _exportSelected,
        ),
      ],
    );
  }

  Widget _buildRecipesSection() {
    final recipesAsync = ref.watch(allRecipesListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recipes (${_selectedRecipes.length} selected)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            recipesAsync.maybeWhen(
              data: (recipes) => TextButton(
                onPressed: recipes.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (_selectedRecipes.length == recipes.length) {
                            _selectedRecipes.clear();
                          } else {
                            _selectedRecipes.addAll(
                              recipes.map((r) => r.id),
                            );
                          }
                        });
                      },
                child: Text(
                  _selectedRecipes.length == recipes.length
                      ? 'Deselect All'
                      : 'Select All',
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
                final icon = r.icon != null
                    ? resolveIcon(r.icon, Icons.restaurant_menu)
                    : Icons.restaurant_menu;
                final color = r.color != null
                    ? Color(r.color!)
                    : Colors.brown;
                final isSelected = _selectedRecipes.contains(r.id);
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Icon(icon, color: Colors.white),
                    ),
                    title: Text(r.name),
                    subtitle: Text(r.id),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedRecipes.add(r.id);
                          } else {
                            _selectedRecipes.remove(r.id);
                          }
                        });
                      },
                    ),
                  ),
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
          label: const Text('Export Selected Recipes'),
          onPressed: _selectedRecipes.isEmpty ? null : _exportSelected,
        ),
      ],
    );
  }

  Widget _buildEntriesSection() {
    final entriesAsync = ref.watch(allEntriesWithChildrenProvider);
    final sortMode = ref.watch(entrySortModeProvider);
    final typeFilter = ref.watch(entryTypeFilterProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Calendar Entries (${_selectedEntries.length} selected)',
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
                          setState(() {
                            if (_selectedEntries.length == topLevel.length) {
                              _selectedEntries.clear();
                            } else {
                              _selectedEntries.addAll(
                                topLevel.map((e) => e.id),
                              );
                              // Auto-select dependencies
                              for (final entry in topLevel) {
                                _autoSelectDependencies(entry);
                              }
                            }
                          });
                        },
                  child: Text(
                    _selectedEntries.length == topLevel.length
                        ? 'Deselect All'
                        : 'Select All',
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
                    selectedIds: _selectedEntries,
                    onSelectionChanged: (entryId, selected) {
                      setState(() {
                        if (selected) {
                          _selectedEntries.add(entryId);
                          // Auto-select dependencies
                          final entry = allEntries.firstWhere(
                            (e) => e.id == entryId,
                          );
                          _autoSelectDependencies(entry);
                        } else {
                          _selectedEntries.remove(entryId);
                        }
                      });
                    },
                  );
                }),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Export Selected Entries'),
                      onPressed: _selectedEntries.isEmpty
                          ? null
                          : _exportSelected,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Selected Entries'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedEntries.isEmpty
                          ? null
                          : () => _bulkDeleteEntries(allEntries),
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

  void _autoSelectDependencies(EntryRecord entry) {
    // Auto-select kinds
    if (entry.productId == null &&
        entry.recipeId == null &&
        entry.sourceEntryId == null) {
      // This is a direct kind entry
      _selectedKinds.add(entry.widgetKind);
    }

    // Auto-select products
    if (entry.productId != null) {
      _selectedProducts.add(entry.productId!);
    }

    // Auto-select recipes
    if (entry.recipeId != null) {
      _selectedRecipes.add(entry.recipeId!);
    }
  }

  // Helper methods

  Future<void> _exportAll() async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      _showSnackBar('Service not ready');
      return;
    }

    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final fileName = 'shiata_full_export_$timestamp.json';

      final bundle = await svc.exportBundle();
      final encoder = const JsonEncoder.withIndent('  ');
      final text = encoder.convert(bundle);
      final bytes = utf8.encode(text);

      final outputFile = await FilePicker.saveFile(
        dialogTitle: 'Save Full Export',
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

  Future<void> _exportSelected() async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      _showSnackBar('Service not ready');
      return;
    }

    try {
      final bundle = await svc.exportSelected(
        kindIds: _selectedKinds.toList(),
        productIds: _selectedProducts.toList(),
        recipeIds: _selectedRecipes.toList(),
        entryIds: _selectedEntries.toList(),
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

  Future<void> _bulkDeleteEntries(List<EntryRecord> allEntries) async {
    final repo = ref.read(entriesRepositoryProvider);
    if (repo == null) return;

    final messenger = ScaffoldMessenger.of(context);

    // Build summary of what will be deleted
    int kindCount = 0;
    int productCount = 0;
    int recipeCount = 0;

    for (final id in _selectedEntries) {
      final entry = allEntries.firstWhere((e) => e.id == id);
      if (entry.widgetKind == 'product') {
        productCount++;
      } else if (entry.widgetKind == 'recipe') {
        recipeCount++;
      } else {
        kindCount++;
      }
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Entries?'),
        content: Text(
          'This will delete:\n'
          '• $kindCount kind entries\n'
          '• $productCount product entries (with components)\n'
          '• $recipeCount recipe entries (with components)\n\n'
          'Total: ${_selectedEntries.length} entries',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Collect all entries to delete
    final entriesToDelete = <EntryRecord>[];

    for (final id in _selectedEntries) {
      final entry = allEntries.firstWhere((e) => e.id == id);
      entriesToDelete.add(entry);
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

    // Show snackbar
    messenger.showSnackBar(
      SnackBar(content: Text('Deleted ${entriesToDelete.length} entries')),
    );
  }

  Future<String?> _pickAndReadJsonBundle() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (files.isEmpty) return null;

    try {
      final file = files.first;
      final bytes = await file.readAsBytes();
      return utf8.decode(bytes);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to read file: $e');
      }
      return null;
    }
  }

  Future<void> _importAll() async {
    // First confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import All (JSON File)'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WARNING: This will WIPE all existing data and replace it with the imported data.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text('You will be prompted to select a .json file to import.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Select File'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Pick file
    final jsonStr = await _pickAndReadJsonBundle();
    if (jsonStr == null || !mounted) return;

    // Second confirmation
    final reallyConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'This will permanently delete all existing data and cannot be undone. Proceed with import?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Import'),
          ),
        ],
      ),
    );

    if (reallyConfirmed != true || !mounted) return;

    try {
      final svc = ref.read(importExportServiceProvider);
      if (svc == null) {
        if (mounted) _showSnackBar('Service not ready');
        return;
      }
      final importResult = await svc.importBundle(jsonStr);
      if (!mounted) return;

      final msg =
          'Imported:\n'
          '${importResult.kindsUpserted} kinds\n'
          '${importResult.productsUpserted} products\n'
          '${importResult.recipesUpserted} recipes\n'
          '${importResult.componentsWritten} components'
          '${importResult.warnings.isEmpty ? '' : '\n\nWarnings: ${importResult.warnings.length}'}';

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Complete'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Text(
                importResult.warnings.isEmpty
                    ? msg
                    : ('$msg\n\n${importResult.warnings.join('\n')}'),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Import failed: $e');
      }
    }
  }

  Future<WipeMode?> _showWipeOptionsDialog() async {
    return showDialog<WipeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Wipe Mode'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(WipeMode.blank),
            child: const ListTile(
              leading: Icon(Icons.layers_clear),
              title: Text('Blank Slate'),
              subtitle: Text('Start with an empty database.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(WipeMode.demo),
            child: const ListTile(
              leading: Icon(Icons.abc),
              title: Text('Demo Data'),
              subtitle: Text('Seed with default example data.'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(WipeMode.import),
            child: const ListTile(
              leading: Icon(Icons.upload_file),
              title: Text('Import JSON'),
              subtitle: Text('Wipe and then import from a JSON file.'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _wipeDatabase() async {
    final mode = await _showWipeOptionsDialog();
    if (mode == null || !mounted) return;

    String? importJson;
    if (mode == WipeMode.import) {
      importJson = await _pickAndReadJsonBundle();
      if (importJson == null || !mounted) return;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: Text(
          mode == WipeMode.blank
              ? 'This will permanently delete all existing data. You will start with a blank slate.'
              : mode == WipeMode.demo
                  ? 'This will permanently delete all existing data and restart with bootstrap demo data.'
                  : 'This will permanently delete all existing data and replace it with data from the selected JSON file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Wipe'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(dbHandleProvider.notifier).wipeDb();
      // Wait for providers to propagate the new DB instance
      await Future.microtask(() {});
      final svc = ref.read(importExportServiceProvider);
      if (svc == null) {
        if (mounted) _showSnackBar('Service not ready');
        return;
      }

      if (mode == WipeMode.demo) {
        await svc.seedInitialData();
        if (mounted) {
          _showSnackBar('Database wiped and seeded with demo data');
        }
      } else if (mode == WipeMode.import && importJson != null) {
        await svc.importBundle(importJson);
        if (mounted) {
          _showSnackBar('Database wiped and data imported successfully');
        }
      } else {
        if (mounted) {
          _showSnackBar('Database wiped successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to wipe database: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

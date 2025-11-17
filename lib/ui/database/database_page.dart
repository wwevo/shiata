import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../data/db/db_handle.dart';
import '../../data/providers.dart';
import '../../data/repo/import_export_service.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipes_repository.dart';
import '../../data/repo/entries_repository.dart';
import '../widgets/icon_resolver.dart';
import '../widgets/entry_list_item_factory.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFullOperationsSection(),
          const Divider(height: 32),
          _buildFineGrainedSection(),
        ],
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

  Widget _buildFineGrainedSection() {
    final kindsAsync = ref.watch(kindsListProvider);
    final productsRepo = ref.watch(productsRepositoryProvider);
    final recipesRepo = ref.watch(recipesRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Export Selected Items',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Select specific kinds, products, or recipes to export. Dependencies will be included automatically.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),

        // Kinds section
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
                data: (kinds) => Text(_selectedKinds.length == kinds.length ? 'Deselect All' : 'Select All'),
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
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Icon(icon, color: Colors.white),
                    ),
                    title: Text(k.name),
                    subtitle: Text('${k.unit}  •  min ${k.min}  •  max ${k.max}'),
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

        const SizedBox(height: 16),

        // Products section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Products (${_selectedProducts.length} selected)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (productsRepo != null)
              StreamBuilder<List<ProductDef>>(
                stream: productsRepo.watchProducts(),
                builder: (context, snapshot) {
                  final products = snapshot.data ?? [];
                  return TextButton(
                    onPressed: products.isEmpty ? null : () {
                      setState(() {
                        if (_selectedProducts.length == products.length) {
                          _selectedProducts.clear();
                        } else {
                          _selectedProducts.addAll(products.map((p) => p.id));
                        }
                      });
                    },
                    child: Text(_selectedProducts.length == products.length ? 'Deselect All' : 'Select All'),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (productsRepo == null)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Repository not ready'),
          )
        else
          StreamBuilder<List<ProductDef>>(
            stream: productsRepo.watchProducts(),
            builder: (context, snapshot) {
              final products = snapshot.data ?? [];
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
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export Selected Products'),
          onPressed: _selectedProducts.isEmpty ? null : _exportSelected,
        ),

        const SizedBox(height: 16),

        // Recipes section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recipes (${_selectedRecipes.length} selected)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (recipesRepo != null)
              StreamBuilder<List<RecipeDef>>(
                stream: recipesRepo.watchRecipes(onlyActive: false),
                builder: (context, snapshot) {
                  final recipes = snapshot.data ?? [];
                  return TextButton(
                    onPressed: recipes.isEmpty ? null : () {
                      setState(() {
                        if (_selectedRecipes.length == recipes.length) {
                          _selectedRecipes.clear();
                        } else {
                          _selectedRecipes.addAll(recipes.map((r) => r.id));
                        }
                      });
                    },
                    child: Text(_selectedRecipes.length == recipes.length ? 'Deselect All' : 'Select All'),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (recipesRepo == null)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Repository not ready'),
          )
        else
          StreamBuilder<List<RecipeDef>>(
            stream: recipesRepo.watchRecipes(onlyActive: false),
            builder: (context, snapshot) {
              final recipes = snapshot.data ?? [];
              if (recipes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No recipes available'),
                );
              }
              return Column(
                children: recipes.map((r) {
                  final icon = r.icon != null ? resolveIcon(r.icon, Icons.restaurant_menu) : Icons.restaurant_menu;
                  final color = r.color != null ? Color(r.color!) : Colors.brown;
                  final isSelected = _selectedRecipes.contains(r.id);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export Selected Recipes'),
          onPressed: _selectedRecipes.isEmpty ? null : _exportSelected,
        ),

        const SizedBox(height: 16),

        // Calendar Entries section
        _buildEntriesSection(),
      ],
    );
  }

  Widget _buildEntriesSection() {
    final entriesRepo = ref.watch(entriesRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Calendar Entries (${_selectedEntries.length} selected)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (entriesRepo != null)
              FutureBuilder<List<EntryRecord>>(
                future: _getAllEntries(),
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? [];
                  return TextButton(
                    onPressed: entries.isEmpty ? null : () {
                      setState(() {
                        if (_selectedEntries.length == entries.length) {
                          _selectedEntries.clear();
                        } else {
                          _selectedEntries.addAll(entries.map((e) => e.id));
                          // Auto-select dependencies
                          for (final entry in entries) {
                            _autoSelectDependencies(entry);
                          }
                        }
                      });
                    },
                    child: Text(_selectedEntries.length == entries.length ? 'Deselect All' : 'Select All'),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (entriesRepo == null)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Repository not ready'),
          )
        else
          FutureBuilder<List<EntryRecord>>(
            future: _getAllEntries(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final entries = snapshot.data ?? [];
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No entries available'),
                );
              }

              // Build hierarchy: childrenByParent map
              final childrenByParent = <String, List<EntryRecord>>{};
              for (final entry in entries) {
                final parentId = entry.sourceEntryId;
                if (parentId != null && parentId.isNotEmpty) {
                  childrenByParent.putIfAbsent(parentId, () => []).add(entry);
                }
              }

              // Get only top-level entries (those without sourceEntryId)
              final topLevelEntries = entries.where((e) => e.sourceEntryId == null || e.sourceEntryId!.isEmpty).toList();

              // Sort by targetAt descending (newest first)
              topLevelEntries.sort((a, b) => b.targetAt.compareTo(a.targetAt));

              // Get registry for icons/colors
              final registry = ref.watch(widgetRegistryProvider);

              return Column(
                children: [
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
                            final entry = entries.firstWhere((e) => e.id == entryId);
                            _autoSelectDependencies(entry);
                          } else {
                            _selectedEntries.remove(entryId);
                          }
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Export Selected Entries'),
                    onPressed: _selectedEntries.isEmpty ? null : _exportSelected,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<List<EntryRecord>> _getAllEntries() async {
    final entriesRepo = ref.read(entriesRepositoryProvider);
    if (entriesRepo == null) return [];

    final rows = await entriesRepo.dumpEntries();
    return rows.map((row) => EntryRecord.fromDb(row)).toList();
  }

  void _autoSelectDependencies(EntryRecord entry) {
    // Auto-select kinds
    if (entry.productId == null && entry.recipeId == null && entry.sourceEntryId == null) {
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
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'shiata_full_export_$timestamp.json';
      final path = await svc.backupToFile(fileName: fileName);

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export Complete'),
            content: SelectableText(
              'Database exported to:\n\n$path\n\nYou can find this file in your app\'s documents directory.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
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

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'shiata_selected_export_$timestamp.json';

      // Save to file
      final path = await svc.saveBundleToFile(bundle, fileName: fileName);

      if (mounted) {
        // Count what was exported
        final kinds = (bundle['kinds'] as List?)?.length ?? 0;
        final products = (bundle['products'] as List?)?.length ?? 0;
        final recipes = (bundle['recipes'] as List?)?.length ?? 0;
        final entriesCount = (bundle['entries'] as List?)?.length ?? 0;

        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export Complete'),
            content: SelectableText(
              'Exported $kinds kinds, $products products, $recipes recipes, $entriesCount entries\n'
              '(includes auto-resolved dependencies)\n\n'
              'File saved to:\n$path',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Export failed: $e');
      }
    }
  }

  Future<void> _importAll() async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      _showSnackBar('Service not ready');
      return;
    }

    final controller = TextEditingController();

    // First confirmation - show input dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Import All (JSON)'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'WARNING: This will WIPE all existing data and replace it with the imported data.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    hintText: '{"version":1, "kinds": [...], ...}',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

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
      final result = await svc.importBundle(controller.text);
      if (!mounted) return;

      final msg = 'Imported:\n'
          '${result.kindsUpserted} kinds\n'
          '${result.productsUpserted} products\n'
          '${result.recipesUpserted} recipes\n'
          '${result.componentsWritten} components'
          '${result.warnings.isEmpty ? '' : '\n\nWarnings: ${result.warnings.length}'}';

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Complete'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Text(
                result.warnings.isEmpty
                    ? msg
                    : ('$msg\n\n${result.warnings.join('\n')}'),
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

  Future<void> _wipeDatabase() async {
    // First confirmation
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe Database?'),
        content: const Text(
          'This will delete all local data and restart with bootstrap demo data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (first != true || !mounted) return;

    // Second confirmation
    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text(
          'Wiping the database cannot be undone. All data will be lost. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Wipe'),
          ),
        ],
      ),
    );

    if (second != true) return;

    try {
      await ref.read(dbHandleProvider.notifier).wipeDb();
      if (mounted) {
        _showSnackBar('Database wiped successfully');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to wipe database: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

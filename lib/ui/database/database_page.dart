import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/db_handle.dart';
import '../../data/providers.dart';
import '../../data/repo/import_export_service.dart';
import '../../data/repo/kinds_repository.dart';
import '../../data/repo/products_repository.dart';
import '../../data/repo/recipes_repository.dart';

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
  bool _includeEntries = false;

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
              label: const Text('Export All to File'),
              onPressed: _exportAllToFile,
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
        ExpansionTile(
          title: Text('Kinds (${_selectedKinds.length} selected)'),
          initiallyExpanded: false,
          children: [
            kindsAsync.when(
              data: (kinds) {
                if (kinds.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No kinds available'),
                  );
                }
                return Column(
                  children: [
                    CheckboxListTile(
                      title: const Text('Select All'),
                      value: _selectedKinds.length == kinds.length && kinds.isNotEmpty,
                      tristate: _selectedKinds.isNotEmpty && _selectedKinds.length < kinds.length,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedKinds.addAll(kinds.map((k) => k.id));
                          } else {
                            _selectedKinds.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ...kinds.map((k) => CheckboxListTile(
                          dense: true,
                          title: Text(k.name),
                          subtitle: Text('${k.unit}  •  ${k.id}'),
                          value: _selectedKinds.contains(k.id),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedKinds.add(k.id);
                              } else {
                                _selectedKinds.remove(k.id);
                              }
                            });
                          },
                        )),
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
        ),

        // Products section
        ExpansionTile(
          title: Text('Products (${_selectedProducts.length} selected)'),
          initiallyExpanded: false,
          children: [
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
                    children: [
                      CheckboxListTile(
                        title: const Text('Select All'),
                        value: _selectedProducts.length == products.length,
                        tristate: _selectedProducts.isNotEmpty && _selectedProducts.length < products.length,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedProducts.addAll(products.map((p) => p.id));
                            } else {
                              _selectedProducts.clear();
                            }
                          });
                        },
                      ),
                      const Divider(),
                      ...products.map((p) => CheckboxListTile(
                            dense: true,
                            title: Text(p.name),
                            subtitle: Text(p.id),
                            value: _selectedProducts.contains(p.id),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedProducts.add(p.id);
                                } else {
                                  _selectedProducts.remove(p.id);
                                }
                              });
                            },
                          )),
                    ],
                  );
                },
              ),
          ],
        ),

        // Recipes section
        ExpansionTile(
          title: Text('Recipes (${_selectedRecipes.length} selected)'),
          initiallyExpanded: false,
          children: [
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
                    children: [
                      CheckboxListTile(
                        title: const Text('Select All'),
                        value: _selectedRecipes.length == recipes.length,
                        tristate: _selectedRecipes.isNotEmpty && _selectedRecipes.length < recipes.length,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedRecipes.addAll(recipes.map((r) => r.id));
                            } else {
                              _selectedRecipes.clear();
                            }
                          });
                        },
                      ),
                      const Divider(),
                      ...recipes.map((r) => CheckboxListTile(
                            dense: true,
                            title: Text(r.name),
                            subtitle: Text(r.id),
                            value: _selectedRecipes.contains(r.id),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedRecipes.add(r.id);
                                } else {
                                  _selectedRecipes.remove(r.id);
                                }
                              });
                            },
                          )),
                    ],
                  );
                },
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Include entries checkbox
        CheckboxListTile(
          title: const Text('Include calendar entries'),
          subtitle: const Text('Export calendar instances of selected items'),
          value: _includeEntries,
          onChanged: (val) {
            setState(() {
              _includeEntries = val ?? false;
            });
          },
        ),

        const SizedBox(height: 16),

        // Export button
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export Selected to File'),
          onPressed: (_selectedKinds.isEmpty && _selectedProducts.isEmpty && _selectedRecipes.isEmpty)
              ? null
              : _exportSelectedToFile,
        ),
      ],
    );
  }

  // Helper methods

  Future<void> _exportAllToFile() async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      _showSnackBar('Service not ready');
      return;
    }

    try {
      final path = await svc.backupToFile(fileName: 'shiata_full_export.json');
      if (mounted) {
        _showSnackBar('Exported to ${path.split('/').last}');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Export failed: $e');
      }
    }
  }

  Future<void> _exportSelectedToFile() async {
    // TODO: This requires implementing exportSelected() in ImportExportService
    // For now, show a message
    _showSnackBar('Fine-grained export not yet implemented in backend');
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

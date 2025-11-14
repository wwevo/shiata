import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/db_handle.dart';
import '../../data/repo/import_export_service.dart';
import '../kinds/kinds_page.dart';
import '../main_screen_providers.dart';
import '../products/products_page.dart';
import '../recipes/recipes_page.dart';

class BottomControls extends ConsumerWidget {
  const BottomControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handedness = ref.watch(handednessProvider);
    final viewMode = ref.watch(viewModeProvider);

    return BottomAppBar(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // View mode toggle (Overview <-> Calendar)
          IconButton(
            tooltip: viewMode == ViewMode.overview ? 'Switch to Calendar' : 'Switch to Overview',
            onPressed: () {
              ref.read(viewModeProvider.notifier).state =
                  viewMode == ViewMode.overview ? ViewMode.calendar : ViewMode.overview;
            },
            icon: Icon(
              viewMode == ViewMode.overview ? Icons.calendar_month : Icons.bar_chart,
            ),
          ),
          IconButton(
            tooltip: 'Swap handedness',
            onPressed: () {
              ref.read(handednessProvider.notifier).state =
                  handedness == Handedness.left ? Handedness.right : Handedness.left;
            },
            icon: const Icon(Icons.swap_horiz),
          ),
          IconButton(
            tooltip: 'Products',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductTemplatesPage()),
              );
            },
            icon: const Icon(Icons.shopping_basket_outlined),
          ),
          IconButton(
            tooltip: 'Kinds',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KindsPage()),
              );
            },
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Recipes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecipesPage()),
              );
            },
            icon: const Icon(Icons.restaurant_menu_outlined),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
              ),
              onChanged: (q) {
                ref.read(searchQueryProvider.notifier).state = q;
                ref.read(middleModeProvider.notifier).state = q.trim().isEmpty ? MiddleMode.main : MiddleMode.search;
              },
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              final q = ref.read(searchQueryProvider);
              ref.read(middleModeProvider.notifier).state = q.trim().isEmpty ? MiddleMode.main : MiddleMode.search;
            },
            icon: const Icon(Icons.search),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'backup_single':
                  try {
                    final svc = ref.read(importExportServiceProvider);
                    if (svc == null) break;
                    final path = await svc.backupToFile();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved to ${path.split('/').last}')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
                    }
                  }
                  break;
                case 'restore_single':
                  final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Restore backup?'),
                          content: const Text('This will wipe current data and restore from the single-slot backup.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Restore')),
                          ],
                        ),
                      ) ??
                      false;
                  if (confirm != true) return;
                  if (!context.mounted) return;
                  try {
                    final svc = ref.read(importExportServiceProvider);
                    if (svc == null) break;
                    final path = await svc.restoreFromFile();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored from ${path.split('/').last}')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                    }
                  }
                  break;
                case 'wipe_db':
                  final first = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Wipe database?'),
                          content: const Text('This will delete all local data and restart with bootstrap demo data.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Continue')),
                          ],
                        ),
                      ) ??
                      false;
                  if (first != true) return;
                  if (!context.mounted) return;
                  final second = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Are you absolutely sure?'),
                          content: const Text('Wiping the DB cannot be undone. Proceed?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes, wipe')),
                          ],
                        ),
                      ) ??
                      false;
                  if (second != true) return;
                  try {
                    await ref.read(dbHandleProvider.notifier).wipeDb();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database wiped')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to wipe DB: $e')));
                    }
                  }
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'backup_single', child: Text('Backup (single slot)')),
              PopupMenuItem(value: 'restore_single', child: Text('Restore (single slot)')),
              PopupMenuItem(value: 'wipe_db', child: Text('Wipe DB (temporary)')),
            ],
          ),
        ],
      ),
    );
  }
}

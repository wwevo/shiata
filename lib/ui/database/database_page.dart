import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/db_handle.dart';
import '../../data/providers.dart';
import '../../data/repo/import_export_service.dart';

class DatabasePage extends ConsumerWidget {
  const DatabasePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildFullOperationsSection(context, ref),
          const Divider(height: 32),
          _buildQuickBackupSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildFullOperationsSection(BuildContext context, WidgetRef ref) {
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
              onPressed: () => _exportAll(context, ref),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('Import All'),
              onPressed: () => _importAll(context, ref),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Wipe Database'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _wipeDatabase(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickBackupSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Backup (Single Slot)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Single-slot backup saved to device storage. Quick way to save and restore your complete database.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Backup to File'),
              onPressed: () => _backupToFile(context, ref),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Restore from File'),
              onPressed: () => _restoreFromFile(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  // Helper methods for full operations

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service not ready')),
      );
      return;
    }

    try {
      final bundle = await svc.exportBundle();
      final encoder = const JsonEncoder.withIndent('  ');
      final text = encoder.convert(bundle);

      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Export All (JSON)'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: SelectableText(text),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  }
                },
                child: const Text('Copy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importAll(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service not ready')),
      );
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

    if (confirmed != true) return;
    if (!context.mounted) return;

    // Second confirmation - are you sure?
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

    if (reallyConfirmed != true) return;

    try {
      final result = await svc.importBundle(controller.text);
      if (!context.mounted) return;

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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Future<void> _wipeDatabase(BuildContext context, WidgetRef ref) async {
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

    if (first != true) return;
    if (!context.mounted) return;

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database wiped successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to wipe database: $e')),
        );
      }
    }
  }

  // Helper methods for quick backup

  Future<void> _backupToFile(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service not ready')),
      );
      return;
    }

    try {
      final path = await svc.backupToFile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to ${path.split('/').last}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreFromFile(BuildContext context, WidgetRef ref) async {
    final svc = ref.read(importExportServiceProvider);
    if (svc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service not ready')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will wipe current data and restore from the single-slot backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    try {
      final path = await svc.restoreFromFile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored from ${path.split('/').last}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/db/db_handle.dart';
import '../../data/repo/import_export_service.dart';

enum WipeMode {
  blank,
  demo,
  import,
}

class DatabaseAdminPage extends ConsumerStatefulWidget {
  const DatabaseAdminPage({super.key});

  @override
  ConsumerState<DatabaseAdminPage> createState() => _DatabaseAdminPageState();
}

class _DatabaseAdminPageState extends ConsumerState<DatabaseAdminPage>
    with SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Database')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildFullOperationsSection(),
          ),
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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repo/entries_repository.dart';
import '../../domain/widgets/registry.dart';
import '../editors/kind_instance_editor_dialog.dart';
import '../main_screen_providers.dart';
// import '../editors/protein_editor.dart';
// import '../editors/fat_editor.dart';
// import '../editors/carbohydrate_editor.dart';

class SearchResults extends ConsumerWidget {
  const SearchResults({super.key, required this.controller});
  final ScrollController controller;

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(entriesRepositoryProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final q = ref.watch(searchQueryProvider);
    if (repo == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<EntryRecord>>(
      stream: repo.watchSearch(q),
      builder: (context, snapshot) {
        final results = snapshot.data ?? const <EntryRecord>[];
        if (q.trim().isEmpty) {
          return const Center(child: Text('Type to search'));
        }
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No results for "$q"', style: Theme.of(context).textTheme.bodyMedium),
            ),
          );
        }
        return ListView.separated(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final e = results[i];
            final kind = registry.byId(e.widgetKind);
            final color = kind?.accentColor ?? Theme.of(context).colorScheme.primary;
            final icon = kind?.icon ?? Icons.circle;
            // Basic summary from payload
            String summary = '';
            try {
              final map = jsonDecode(e.payloadJson) as Map<String, dynamic>;
              final grams = (map['grams'] as num?)?.toInt();
              if (grams != null) summary = '$grams g';
            } catch (_) {}
            final localTime = DateTime.fromMillisecondsSinceEpoch(e.targetAt, isUtc: true).toLocal();
            return ListTile(
              onTap: () {
/*
                if (e.widgetKind == 'protein') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProteinEditorScreen(entryId: e.id)));
                } else if (e.widgetKind == 'fat') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => FatEditorScreen(entryId: e.id)));
                } else if (e.widgetKind == 'carbohydrate') {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => CarbohydrateEditorScreen(entryId: e.id)));
                }
*/
                final k = registry.byId(e.widgetKind);
                if (k != null) {
/*                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => KindInstanceEditorScreen(kind: k, entryId: e.id)),
                  );*/
                  showDialog(
                    context: context,
                    builder: (_) =>
                        KindInstanceEditorDialog(kind: k, entryId: e.id),
                  );
                }

              },
              leading: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon, size: 18)),
              title: Text('${kind?.displayName ?? e.widgetKind} • ${summary.isEmpty ? '—' : summary}'),
              subtitle: Text('${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}  ${_fmtTime(localTime)}'),
              trailing: const Icon(Icons.chevron_right),
            );
          },
        );
      },
    );
  }
}

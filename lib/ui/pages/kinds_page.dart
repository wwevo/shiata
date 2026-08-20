import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/widgets/registry.dart';
import '../editors/kind_template_editor_dialog.dart';
import '../main_screen_providers.dart';
import '../widgets/entry_list_item_factory.dart';

class KindsPage extends ConsumerWidget {
  const KindsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kindsAsync = ref.watch(kindsListProvider);
    final registry = ref.watch(widgetRegistryProvider);
    final hierarchy = ref.watch(managementHierarchyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kinds'),
        actions: [
          IconButton(
            tooltip: 'Add kind',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (ctx) => KindTemplateEditorDialog(),
              );
            },
          ),
        ],
      ),
      body: kindsAsync.when(
        data: (kinds) {
          if (kinds.isEmpty) {
            return const Center(child: Text('No kinds yet'));
          }
          return ListView.builder(
            itemCount: kinds.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (ctx, i) {
              return EntryListItemFactory.buildEntry(
                context: context,
                ref: ref,
                entry: kinds[i],
                childrenByParent: hierarchy,
                registry: registry,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

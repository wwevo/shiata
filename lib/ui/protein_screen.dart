import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Placeholder screen for the Protein widget.
///
/// Step 1 goal: provide a simple destination we can navigate to from the
/// home screen. This will later be replaced by the real Create/Edit flow.
class ProteinScreen extends ConsumerWidget {
  const ProteinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protein'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.indigo,
              child: const Icon(Icons.fitness_center, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Protein widget placeholder',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This screen will host the create/edit editor in the next steps.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Insert test Protein entry'),
              onPressed: () async {
                final repo = ref.read(entriesRepositoryProvider);
                if (repo == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Database not ready')),
                  );
                  return;
                }
                try {
                  final rec = await repo.create(
                    widgetKind: 'protein',
                    targetAtLocal: DateTime.now(),
                    payload: {
                      'grams': 30,
                    },
                    showInCalendar: true,
                    schemaVersion: 1,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Inserted entry ${rec.id.substring(0, 8)}…')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Insert failed: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

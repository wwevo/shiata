import 'package:flutter/material.dart';

/// Placeholder screen for the Fat widget (same as Protein placeholder for now).
class FatScreen extends StatelessWidget {
  const FatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fat'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.opacity, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Fat widget placeholder',
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
          ],
        ),
      ),
    );
  }
}

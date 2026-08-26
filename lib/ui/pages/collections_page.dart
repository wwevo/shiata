import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/add_floating_action_button.dart';

class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
      ),
      floatingActionButton: const AppAddFloatingActionButton(
        pageId: 'collections',
      ),
      body: const Center(
        child: Text("data"),
      ),
    );
  }
}

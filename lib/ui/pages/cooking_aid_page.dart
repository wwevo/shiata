import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/add_floating_action_button.dart';

class CookingAidPage extends ConsumerWidget {
  const CookingAidPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Aid'),
      ),
      floatingActionButton: const AppAddFloatingActionButton(
        pageId: 'cookingaids',
      ),
      body: const Center(
        child: Text("data"),
      ),
    );
  }
}

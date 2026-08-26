import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CookingAidPage extends ConsumerWidget {
  const CookingAidPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cooking Aid'),
        actions: [

        ],
      ),
      body: Center(
        child: Text("data"),
      )
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/main_screen.dart';
import 'data/db/db_lifecycle.dart';

import 'domain/widgets/registry.dart';
import 'domain/widgets/kinds/protein_kind.dart';
import 'domain/widgets/kinds/fat_kind.dart';

void main() {
  runApp(ProviderScope(
    overrides: [
      widgetRegistryProvider.overrideWithValue(
        WidgetRegistry({
          'protein': const ProteinKind(),
          'fat': const FatKind(),
        }),
      ),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shiata',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DbLifecycleObserver(
        child: Scaffold(
          body: SafeArea(
            top: true,
            bottom: false,
            child: MainScreen(),
          ),
          bottomNavigationBar: BottomControls(),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

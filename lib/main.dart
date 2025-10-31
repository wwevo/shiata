import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/main_screen.dart';
import 'data/db/db_lifecycle.dart';

import 'domain/widgets/registry.dart';
import 'domain/widgets/kinds/protein_kind.dart';
import 'domain/widgets/kinds/fat_kind.dart';
import 'domain/widgets/kinds/carbohydrate_kind.dart';
import 'domain/widgets/kinds/config_driven_kind.dart';

void main() {
  runApp(ProviderScope(
    overrides: [
      widgetRegistryProvider.overrideWithValue(
        WidgetRegistry({
          // Macros (existing)
          'protein': const ProteinKind(),
          'fat': const FatKind(),
          'carbohydrate': const CarbohydrateKind(),
          // Minerals (gray)
          'sodium': ConfigDrivenKind(
            id: 'sodium', displayName: 'Sodium', icon: Icons.opacity, // reuse droplet
            accentColor: Colors.grey, unit: 'mg', minValue: 0, maxValue: 10000,
          ),
          'potassium': ConfigDrivenKind(
            id: 'potassium', displayName: 'Potassium', icon: Icons.battery_charging_full,
            accentColor: Colors.grey, unit: 'mg', minValue: 0, maxValue: 10000,
          ),
          'calcium': ConfigDrivenKind(
            id: 'calcium', displayName: 'Calcium', icon: Icons.blur_on,
            accentColor: Colors.grey, unit: 'mg', minValue: 0, maxValue: 5000,
          ),
          'magnesium': ConfigDrivenKind(
            id: 'magnesium', displayName: 'Magnesium', icon: Icons.bolt,
            accentColor: Colors.grey, unit: 'mg', minValue: 0, maxValue: 2000,
          ),
          'iron': ConfigDrivenKind(
            id: 'iron', displayName: 'Iron', icon: Icons.circle,
            accentColor: Colors.grey, unit: 'mg', minValue: 0, maxValue: 200,
          ),
          'zinc': ConfigDrivenKind(
            id: 'zinc', displayName: 'Zinc', icon: Icons.hexagon,
            accentColor: Colors.grey, unit: 'mg', minValue: 0, maxValue: 200,
          ),
          'phosphorus': ConfigDrivenKind(
            id: 'phosphorus', displayName: 'Phosphorus', icon: Icons.science,
            accentColor: Colors.grey, unit: 'mg', minValue: 0, maxValue: 2000,
          ),
          // Vitamins (green)
          'vitamin_a': ConfigDrivenKind(
            id: 'vitamin_a', displayName: 'Vitamin A', icon: Icons.visibility,
            accentColor: Colors.green, unit: 'ug', minValue: 0, maxValue: 10000,
          ),
          'vitamin_b12': ConfigDrivenKind(
            id: 'vitamin_b12', displayName: 'Vitamin B12', icon: Icons.medical_information,
            accentColor: Colors.green, unit: 'ug', minValue: 0, maxValue: 10000,
          ),
          'vitamin_c': ConfigDrivenKind(
            id: 'vitamin_c', displayName: 'Vitamin C', icon: Icons.local_florist,
            accentColor: Colors.green, unit: 'mg', minValue: 0, maxValue: 5000,
          ),
          'vitamin_d': ConfigDrivenKind(
            id: 'vitamin_d', displayName: 'Vitamin D', icon: Icons.wb_sunny,
            accentColor: Colors.green, unit: 'ug', minValue: 0, maxValue: 1000,
          ),
          'vitamin_e': ConfigDrivenKind(
            id: 'vitamin_e', displayName: 'Vitamin E', icon: Icons.eco,
            accentColor: Colors.green, unit: 'mg', minValue: 0, maxValue: 1000,
          ),
          'vitamin_k': ConfigDrivenKind(
            id: 'vitamin_k', displayName: 'Vitamin K', icon: Icons.grass,
            accentColor: Colors.green, unit: 'ug', minValue: 0, maxValue: 5000,
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/main_screen.dart';
import 'data/db/db_lifecycle.dart';
import 'ui/widgets/bottom_controls.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
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

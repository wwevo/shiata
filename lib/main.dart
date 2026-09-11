import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'data/db/db_lifecycle.dart';
import 'ui/main_screen.dart';
import 'ui/widgets/bottom_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
  }

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
          body: SafeArea(top: true, bottom: false, child: MainScreen()),
          bottomNavigationBar: BottomControls(),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

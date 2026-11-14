import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'data/db/db_lifecycle.dart';
import 'data/providers.dart';
import 'ui/main_screen.dart';
import 'ui/main_screen_providers.dart';
import 'ui/ux_config.dart';
import 'ui/widgets/bottom_controls.dart';
import 'ui/widgets/circle_week_header.dart';
import 'ui/widgets/weekly_calendar.dart';

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
      home: DbLifecycleObserver(
        child: Scaffold(
          body: SafeArea(
            top: true,
            bottom: false,
            child: Column(
              children: [
                // Global weekly header
                Consumer(
                  builder: (context, ref, _) {
                    final headerAnchor = ref.watch(headerCalendarAnchorProvider);
                    final style = ref.watch(headerStyleProvider);
                    final config = ref.watch(uxConfigProvider);

                    // Default day-click handler: navigate to ActiveWeekPage
                    void defaultDayClick(DateTime day) {
                      final monday = day.subtract(Duration(days: day.weekday - 1));
                      ref.read(calendarAnchorProvider.notifier).state = monday;
                      ref.read(headerCalendarAnchorProvider.notifier).state = monday;
                      ref.read(selectedDayProvider.notifier).state = day;
                      ref.read(currentSectionIdProvider.notifier).state = 'active_week';
                    }

                    final header = style.when(
                      data: (s) {
                        if (s == 'circles') {
                          return SizedBox(
                            height: 80,
                            child: CircleWeekHeader(
                              monday: headerAnchor,
                              onDayTap: defaultDayClick,
                            ),
                          );
                        }
                        return SizedBox(
                          height: 80,
                          child: WeeklyCalendar(
                            grid: config.calendarGrid,
                            onDayTap: defaultDayClick,
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    );
                    return header;
                  },
                ),
                const Divider(height: 1),
                // Page content
                Expanded(
                  child: MainScreen(),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomControls(),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/nav_registry.dart';
import 'main_screen_providers.dart';
import 'pages/active_week_page.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(currentSectionIdProvider);
    final registry = ref.watch(navRegistryProvider);
    final pageItem = registry.findPage(activeId);

    if (pageItem == null) {
      return const ActiveWeekPage();
    }

    return pageItem.pageBuilder(context, ref);
  }
}
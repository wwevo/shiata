import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ux_config.dart';
import 'widgets/middle_panel.dart';
import 'widgets/top_sheet_host.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(uxConfigProvider);
    return TopSheetHost(
      config: config,
      childBelow: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: MiddlePanel()),
        ],
      ),
    );
  }
}

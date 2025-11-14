import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main_actions_list.dart';
import '../main_screen_providers.dart';
import 'search_results.dart';
import 'top_sheet_host.dart';

class MiddlePanel extends ConsumerStatefulWidget {
  const MiddlePanel({super.key});
  @override
  ConsumerState<MiddlePanel> createState() => _MiddlePanelState();
}

class _MiddlePanelState extends ConsumerState<MiddlePanel> {
  final _scrollController = ScrollController();
  double _lastDy = 0;
  double _velocity = 0;

  TopSheetHostState? get _host => context.findAncestorStateOfType<TopSheetHostState>();

  void _onDragStart(DragStartDetails d) {
    _lastDy = d.localPosition.dy;
    _velocity = 0;
    _host?.onUserDragStart();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dy = d.localPosition.dy;
    final delta = dy - _lastDy;
    _lastDy = dy;
    _host?.dragBy(delta);
    _velocity = d.primaryDelta ?? 0;
  }

  void _onDragEnd(DragEndDetails d) {
    _host?.settle(d.primaryVelocity ?? _velocity * 1000);
  }

  @override
  Widget build(BuildContext context) {
    final handedness = ref.watch(handednessProvider);

    // Content underlay: regular list (acts as widgets list or search results)
    final mode = ref.watch(middleModeProvider);
    final content = mode == MiddleMode.search
        ? SearchResults(controller: _scrollController)
        : MainActionsList(controller: _scrollController);

    // Overlay: 50/50 split. One half captures vertical drags to control Top; the other is pass-through.
    final overlay = Positioned.fill(
      child: Row(
        children: [
          // Left half
          Expanded(
            child: handedness == Handedness.left
                ? GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                  )
                : const IgnorePointer(ignoring: true, child: SizedBox.expand()),
          ),
          // Right half
          Expanded(
            child: handedness == Handedness.right
                ? GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                  )
                : const IgnorePointer(ignoring: true, child: SizedBox.expand()),
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        overlay,
      ],
    );
  }
}

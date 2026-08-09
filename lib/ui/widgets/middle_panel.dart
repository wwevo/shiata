import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main_actions_list.dart';
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

  TopSheetHostState? get _host =>
      context.findAncestorStateOfType<TopSheetHostState>();

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
    // Content underlay: regular list (acts as widgets list)
    final content = MainActionsList(controller: _scrollController);

    // Overlay: captures vertical drags to control Top.
    final overlay = Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
      ),
    );

    return Stack(fit: StackFit.expand, children: [content, overlay]);
  }
}

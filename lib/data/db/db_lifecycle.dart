import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db_handle.dart';

/// Observes app lifecycle and opens/closes the encrypted DB accordingly.
class DbLifecycleObserver extends StatefulWidget {
  const DbLifecycleObserver({super.key, required this.child});
  final Widget child;

  @override
  State<DbLifecycleObserver> createState() => _DbLifecycleObserverState();
}

class _DbLifecycleObserverState extends State<DbLifecycleObserver>
    with WidgetsBindingObserver {
  ProviderContainer? _container;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ref = _container?.read;
    if (ref == null) return;
    final dbHandle = ref(dbHandleProvider.notifier);

    switch (state) {
      case AppLifecycleState.resumed:
        dbHandle.openDb();
        break;
      case AppLifecycleState.paused:
        dbHandle.closeDb();
        break;
      case AppLifecycleState.detached:
        // App is terminating; ensure DB is closed.
        dbHandle.closeDb();
        break;
      default:
        // Ignore other transient states like inactive to avoid noisy open/close cycles on desktop.
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Attempt initial open on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ref = _container?.read;
      if (ref == null) return;
      ref(dbHandleProvider.notifier).openDb();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final ref = _container?.read;
    if (ref != null) {
      ref(dbHandleProvider.notifier).closeDb();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

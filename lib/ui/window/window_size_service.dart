import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

enum WindowResolutionPreset {
  desktop720(1280, 720, '1280 x 720 (Desktop)', Icons.desktop_windows_outlined),
  desktop1080(1440, 1080, '1440 x 1080 (Desktop)', Icons.desktop_windows_outlined),
  desktop1440(2560, 1440, '2560 x 1440 (Desktop)', Icons.desktop_windows_outlined),
  mobile1080(720, 1080, '720 x 1080 (Mobile)', Icons.phone_android_outlined),
  mobile2560(1080, 2560, '1080 x 2560 (Mobile)', Icons.phone_android_outlined);

  final double width;
  final double height;
  final String label;
  final IconData icon;

  const WindowResolutionPreset(this.width, this.height, this.label, this.icon);
}

class WindowSizeService {
  static bool get isDesktopSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static Future<void> applyResolution(WindowResolutionPreset preset) async {
    if (!isDesktopSupported) return;
    final size = Size(preset.width, preset.height);
    await windowManager.setSize(size);
    await windowManager.center();
  }
}

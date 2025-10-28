import 'dart:io' show Platform;

/// App-wide security toggles and platform policies.
class AppSecurity {
  /// In release builds on desktop (Linux/Windows), fail fast if SQLCipher
  /// library or secure storage backend is unavailable.
  static const bool enforceDesktopEncryption = bool.fromEnvironment(
    'ENFORCE_DESKTOP_ENCRYPTION',
    defaultValue: true,
  );

  /// In debug/profile, show a small banner/warning when running unencrypted on
  /// desktop due to missing SQLCipher or secure storage backend.
  static const bool showDevEncryptionWarning = bool.fromEnvironment(
    'SHOW_DEV_ENCRYPTION_WARNING',
    defaultValue: true,
  );

  /// Returns true if we consider this a desktop platform that needs explicit
  /// SQLCipher dynamic library loading.
  static bool get isDesktop => Platform.isLinux || Platform.isWindows;

  /// Returns true if we are in an environment where SQLCipher should be
  /// pre-bundled and explicitly loaded.
  static bool get requiresExplicitSqlcipherLoad => Platform.isLinux || Platform.isWindows;
}

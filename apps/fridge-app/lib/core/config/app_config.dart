import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  /// Explicit override, e.g. `--dart-define=API_BASE_URL=http://192.168.1.20:8080`
  /// for a phone build or when the gateway runs on another machine.
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// Gateway address.
  ///
  /// On the web the app is served by nginx, which proxies `/api` to the
  /// gateway, so the page origin is always the right base: it works for
  /// `127.0.0.1`, `localhost` and any LAN address the phone opened, and the
  /// browser never makes a cross-origin call.
  ///
  /// Native builds keep the loopback default; a phone needs an explicit
  /// `API_BASE_URL` pointing at the machine running the gateway.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) {
      return _override;
    }
    if (kIsWeb) {
      final page = Uri.base;
      if (page.scheme.startsWith('http') && page.host.isNotEmpty) {
        return page.origin;
      }
    }
    return 'http://127.0.0.1:8080';
  }

  static const connectTimeout = Duration(seconds: 8);
  static const receiveTimeout = Duration(seconds: 12);
}

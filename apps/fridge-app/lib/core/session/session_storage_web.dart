import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_fridge_app/core/session/session_storage_api.dart';

/// Web storage backed by localStorage.
///
/// `flutter_secure_storage` needs WebCrypto, which browsers only expose in a
/// secure context (https or localhost). The app is served over plain http on
/// the LAN, so the secure backend would throw on every write and the login
/// would silently fail. localStorage keeps the session working; tokens are
/// short-lived and the LAN deployment is a development setup.
SessionStorage createSessionStorage() => _PreferencesSessionStorage();

class _PreferencesSessionStorage implements SessionStorage {
  static const _prefix = 'smart_fridge.';

  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('$_prefix$key');
  }

  @override
  Future<void> write(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_prefix$key', value);
  }

  @override
  Future<void> delete(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_prefix$key');
  }
}

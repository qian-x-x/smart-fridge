import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/session/session_storage.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SecureSessionStore();
});

abstract interface class SessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({SessionStorage? storage})
    : _storage = storage ?? createSessionStorage();

  static const _sessionKey = 'smart_fridge.auth_session';

  final SessionStorage _storage;

  @override
  Future<AuthSession?> read() async {
    final raw = await _storage.read(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) {
    return _storage.write(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() => _storage.delete(_sessionKey);
}

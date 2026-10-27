import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';
import 'package:smart_fridge_app/core/session/session_store.dart';
import 'package:smart_fridge_app/features/auth/data/auth_repository.dart';
import 'package:smart_fridge_app/features/auth/domain/auth_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  SessionStore get _store => ref.read(sessionStoreProvider);
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() async {
    final stored = await _store.read();
    if (stored == null || stored.isDemo || !stored.isAccessTokenExpiring) {
      return stored;
    }
    try {
      final refreshed = await _repository.refresh(stored);
      await _store.write(refreshed);
      return refreshed;
    } on ApiFailure catch (error) {
      if (error.statusCode == 401 || error.code == 'UNAUTHORIZED') {
        await _store.clear();
        return null;
      }
      return stored;
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    final session = await _repository.login(
      identifier: identifier,
      password: password,
    );
    await _store.write(session);
    state = AsyncData(session);
  }

  Future<void> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final session = await _repository.register(
      username: username,
      displayName: displayName,
      password: password,
    );
    await _store.write(session);
    state = AsyncData(session);
  }

  Future<void> continueWithDemo() async {
    final session = AuthSession.demo();
    await _store.write(session);
    state = AsyncData(session);
  }

  Future<AuthSession> refreshAccessToken() async {
    final current = state.value ?? await _store.read();
    if (current == null) {
      throw const ApiFailure('登录会话已失效，请重新登录', statusCode: 401);
    }
    if (current.isDemo) {
      return current;
    }
    try {
      final refreshed = await _repository.refresh(current);
      await _store.write(refreshed);
      state = AsyncData(refreshed);
      return refreshed;
    } on ApiFailure catch (error) {
      if (error.statusCode == 401 || error.code == 'UNAUTHORIZED') {
        await _store.clear();
        state = const AsyncData(null);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final current = state.value;
    if (current != null) {
      try {
        await _repository.logout(current);
      } on Object {
        // Local logout still wins when the backend is unavailable.
      }
    }
    await _store.clear();
    state = const AsyncData(null);
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage.dart';
import 'services/auth_service.dart';

/// 登录态。`token == null` 即未登录。
@immutable
class AuthState {
  const AuthState({
    this.token,
    this.cid,
    this.loading = false,
    this.error,
  });

  final String? token;
  final String? cid;
  final bool loading;
  final String? error;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    String? cid,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        token: token ?? this.token,
        cid: cid ?? this.cid,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthController extends Notifier<AuthState> {
  final AuthService _service = const AuthService();

  @override
  AuthState build() => AuthState(token: LocalStorage.instance.authToken);

  /// V2 登录：手机号/用户名 + 密码 + 图形验证码。成功返回 true。
  Future<bool> login({
    required String identifier,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _service.login(
        identifier: identifier,
        password: password,
        captchaId: captchaId,
        captchaCode: captchaCode,
      );
      await LocalStorage.instance.setAuthToken(result.token);
      state = AuthState(token: result.token, cid: result.cid);
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^ApiException\([^)]*\):\s*'), '');
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    await LocalStorage.instance.setAuthToken(null);
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

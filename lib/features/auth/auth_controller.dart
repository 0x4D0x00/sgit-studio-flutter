import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage.dart';
import '../../core/network/ffi/sgit_request_ffi.dart';
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

  /// 登录态标记。真令牌在 FFI 侧会话里（Web 甚至不回传给 Dart），
  /// AuthState.token 只用来表示「已登录」，不参与任何请求。
  static const String _kSessionMark = 'authenticated';

  /// 登录态以 **FFI 侧会话**为准（桌面 = .so，Web = wasm，各自持有真会话），
  /// Dart 不自己判定身份。
  @override
  AuthState build() => AuthState(
        token: SgitRequestFfi.instance.isAuthenticated() ? _kSessionMark : null,
      );

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
      // 桌面端 .so 会回传令牌，落一份本地标记供刷新后判断；Web 端令牌留在 wasm 会话里
      // (result.token 为空)，这里只记一个标记。两端都不用它发请求。
      if (result.token.isNotEmpty) {
        await LocalStorage.instance.setAuthToken(result.token);
      }
      state = AuthState(token: _kSessionMark, cid: result.cid);
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^ApiException\([^)]*\):\s*'), '');
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    // 清 FFI 侧会话(Web = wasm + localStorage;桌面 = 本地标记)。
    SgitRequestFfi.instance.logout();
    await LocalStorage.instance.setAuthToken(null);
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

import 'package:flutter_test/flutter_test.dart';
import 'package:sgit_studio_flutter/core/result/api_exception.dart';
import 'package:sgit_studio_flutter/core/result/auth_failure.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi_types.dart';

/// 鉴权失败的**判据契约**。
///
/// 这组测试守的是两件真实发生过的事故：
/// 1. 令牌过期后应用仍以为已登录，每个请求都失败，用户却永远回不到登录页
///    （`ApiException.isAuthExpired` 从来没人读）；
/// 2. 反方向 —— 业务失败被误判成鉴权失败，把正常使用中的用户踢下线。
///
/// 判错任一个方向都很难在生产日志里看出来，只能靠这里钉死。
void main() {
  group('isAuthFailureMessage', () {
    test('Go 后端的未授权原话都算', () {
      // backend/main/http/distribute.go 的 authenticateUser
      for (final msg in [
        '缺少user_auth_token',
        '无效的user_auth_token: invalid signature',
        '认证失败: 无效的user_auth_token',
      ]) {
        expect(isAuthFailureMessage(msg), isTrue, reason: msg);
      }
    });

    test('令牌过期/吊销/签名无效都算', () {
      // backend/basicinformation/cache/userauthtokens.go
      for (final msg in [
        '认证令牌已过期',
        '认证令牌已被吊销或冻结',
        '认证令牌签名无效',
        '认证令牌格式无效',
      ]) {
        expect(isAuthFailureMessage(msg), isTrue, reason: msg);
      }
    });

    test('Rust/网关的会话缺失与标记都算', () {
      // sgit-ffi 的 err("未登录")、relay 的 [auth_expired] 标记
      for (final msg in [
        '[auth_expired] token expired',
        '未登录',
        '无进程内会话（未登录）',
        '未找到有效的认证信息',
        '认证失败：请重新登录',
        '该账号未在本服务器登录过',
      ]) {
        expect(isAuthFailureMessage(msg), isTrue, reason: msg);
      }
    });

    test('业务失败不算 —— 误判会把正常用户踢下线', () {
      // ⚠️ 尤其注意带 "token"/"api_key" 的业务参数：中转站的厂商密钥
      // 与 user_auth_token 同名同层（distribute.go 的注释里专门提过）。
      for (final msg in [
        '无效的api_key',
        '模型不存在',
        '参数错误: api_key 不能为空',
        'Resource conflict (409)',
        'Server error: 500',
        '网络请求超时',
        null,
        '',
      ]) {
        expect(isAuthFailureMessage(msg), isFalse, reason: '$msg');
      }
    });
  });

  group('ApiException.isAuthExpired', () {
    test('不传标志时按 message 自动识别', () {
      // 各处仓储基本都只给 message（settings_repository_io 的 _decode 等），
      // 自动识别是它们唯一的兜底。
      expect(ApiException('认证令牌已过期').isAuthExpired, isTrue);
      expect(ApiException('模型不存在').isAuthExpired, isFalse);
    });

    test('显式标志优先于 message', () {
      // 有些失败 message 里没有任何关键词（例如本地会话被清），
      // 调用方得能显式声明。
      expect(
        ApiException('会话已失效', isAuthExpired: true).isAuthExpired,
        isTrue,
      );
      expect(
        ApiException('认证失败但已处理', isAuthExpired: false).isAuthExpired,
        isFalse,
      );
    });
  });

  group('AuthFailure.report', () {
    setUp(() => AuthFailure.removeListener(_noopListener));

    test('broadcast 到所有订阅者', () {
      final got = <String>[];
      void a(AuthFailureEvent e) => got.add('a:${e.message}');
      void b(AuthFailureEvent e) => got.add('b:${e.message}');
      AuthFailure.addListener(a);
      AuthFailure.addListener(b);
      addTearDown(() {
        AuthFailure.removeListener(a);
        AuthFailure.removeListener(b);
      });

      AuthFailure.report('测试');
      expect(got, ['a:测试', 'b:测试']);
    });

    test('订阅者抛异常不影响其它订阅者', () {
      // 一个监听者坏掉不能把整条请求链路带崩 —— 本方法的调用点在
      // 请求失败的处理路径上。
      final got = <String>[];
      void bad(AuthFailureEvent e) => throw StateError('boom');
      void good(AuthFailureEvent e) => got.add(e.message);
      AuthFailure.addListener(bad);
      AuthFailure.addListener(good);
      addTearDown(() {
        AuthFailure.removeListener(bad);
        AuthFailure.removeListener(good);
      });

      AuthFailure.report('x');
      expect(got, ['x']);
    });

    test('reportIfAuth 只在命中判据时广播', () {
      var count = 0;
      void l(AuthFailureEvent e) => count++;
      AuthFailure.addListener(l);
      addTearDown(() => AuthFailure.removeListener(l));

      expect(AuthFailure.reportIfAuth('模型不存在'), isFalse);
      expect(count, 0);

      expect(AuthFailure.reportIfAuth('认证令牌已过期'), isTrue);
      expect(count, 1);
    });

    test('取消订阅后不再收到', () {
      var count = 0;
      void l(AuthFailureEvent e) => count++;
      AuthFailure.addListener(l);
      AuthFailure.removeListener(l);

      AuthFailure.report('x');
      expect(count, 0);
    });
  });

  group('FfiFailure（native 的结构化 code）', () {
    test('auth_expired 直接命中', () {
      const f = FfiFailure('认证失败', code: 'auth_expired');
      expect(f.isAuthExpired, isTrue);
    });

    test('其它 code 不算鉴权失败', () {
      expect(const FfiFailure('x', code: 'endpoint_unreachable').isAuthExpired,
          isFalse);
      expect(const FfiFailure('x', code: 'other').isAuthExpired, isFalse);
    });

    test('旧 DLL 没有 code 时不崩，交给调用方降级', () {
      const f = FfiFailure('认证令牌已过期');
      expect(f.code, isNull);
      expect(f.isAuthExpired, isFalse); // code 为 null 时不自作主张
    });

    test('parseFfiError 解析信封', () {
      expect(parseFfiError({'ok': true}), isNull);

      final f = parseFfiError({'error': '未登录', 'code': 'auth_expired'});
      expect(f, isNotNull);
      expect(f!.message, '未登录');
      expect(f.code, 'auth_expired');

      // 旧版 DLL：只有 error，没有 code。
      final legacy = parseFfiError({'error': '未登录'});
      expect(legacy!.code, isNull);
    });
  });
}

void _noopListener(AuthFailureEvent _) {}

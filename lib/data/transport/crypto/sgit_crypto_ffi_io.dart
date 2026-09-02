import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'package:sgit_studio_flutter/data/transport/crypto/sgit_crypto_ffi_types.dart';

// ---- C 函数签名（对齐 sgit_crypto/src/lib.rs 的 extern "C" 导出） ----
typedef _EncryptC = Pointer<Utf8> Function(Pointer<Utf8> data, Pointer<Utf8> pubKeyHex);
typedef _EncryptDart = Pointer<Utf8> Function(Pointer<Utf8> data, Pointer<Utf8> pubKeyHex);

typedef _DecryptC = Pointer<Utf8> Function(Pointer<Utf8> enc, Pointer<Utf8> privKeyHex);
typedef _DecryptDart = Pointer<Utf8> Function(Pointer<Utf8> enc, Pointer<Utf8> privKeyHex);

typedef _GenKeyC = Pointer<Utf8> Function();
typedef _GenKeyDart = Pointer<Utf8> Function();

typedef _FreeC = Void Function(Pointer<Utf8> ptr);
typedef _FreeDart = void Function(Pointer<Utf8> ptr);

/// FFI 封装 sgit_crypto 原生加密库（RSA-OAEP + AES-128-CBC，与 Go 后端字节兼容）。
///
/// 直接调 sgcode 编译的 `sgit_crypto.dll`，避免在 Dart 里重复实现导致对不齐。
/// 详见 memory `sgit-encryption-handshake`。
class SgitCryptoFfi {
  SgitCryptoFfi._(DynamicLibrary lib)
      : _encrypt = lib.lookupFunction<_EncryptC, _EncryptDart>('encrypt_data'),
        _decrypt = lib.lookupFunction<_DecryptC, _DecryptDart>('decrypt_data'),
        _genKey = lib.lookupFunction<_GenKeyC, _GenKeyDart>('generate_key_pair'),
        _free = lib.lookupFunction<_FreeC, _FreeDart>('free_string');

  final _EncryptDart _encrypt;
  final _DecryptDart _decrypt;
  final _GenKeyDart _genKey;
  final _FreeDart _free;

  static SgitCryptoFfi? _instance;
  static SgitCryptoFfi get instance => _instance ??= SgitCryptoFfi._(_open());

  /// 加载动态库（各平台文件名不同）。
  static DynamicLibrary _open() {
    if (Platform.isWindows) return DynamicLibrary.open('sgit_crypto.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libsgit_crypto.dylib');
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libsgit_crypto.so');
    }
    throw UnsupportedError('当前平台不支持 sgit_crypto FFI');
  }

  /// 加密明文，返回 hex 密文。
  String encrypt(String plaintext, String serverPublicKeyHex) {
    final pData = plaintext.toNativeUtf8();
    final pKey = serverPublicKeyHex.toNativeUtf8();
    try {
      final result = _encrypt(pData, pKey);
      if (result == nullptr) throw StateError('加密失败(native 返回空)');
      final out = result.toDartString();
      _free(result);
      return out;
    } finally {
      malloc.free(pData);
      malloc.free(pKey);
    }
  }

  /// 解密 hex 密文，返回明文。
  String decrypt(String hexCiphertext, String userPrivateKeyHex) {
    final pEnc = hexCiphertext.toNativeUtf8();
    final pKey = userPrivateKeyHex.toNativeUtf8();
    try {
      final result = _decrypt(pEnc, pKey);
      if (result == nullptr) throw StateError('解密失败(native 返回空)');
      final out = result.toDartString();
      _free(result);
      return out;
    } finally {
      malloc.free(pEnc);
      malloc.free(pKey);
    }
  }

  /// 生成用户 RSA 密钥对。native 返回 `{"privateKey":"..","publicKey":".."}`。
  SgitKeyPair generateKeyPair() {
    final result = _genKey();
    if (result == nullptr) throw StateError('生成密钥对失败(native 返回空)');
    final jsonStr = result.toDartString();
    _free(result);
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SgitKeyPair(
      privateKeyHex: map['privateKey'].toString(),
      publicKeyHex: map['publicKey'].toString(),
    );
  }
}

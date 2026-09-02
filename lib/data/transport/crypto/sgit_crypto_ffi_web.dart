import 'package:sgit_studio_flutter/data/transport/crypto/sgit_crypto_ffi_types.dart';

/// SgitCryptoFfi 的 **Web 占位实现**（无 dart:ffi/dart:io，Flutter Web 可编译）。
///
/// ⚠️ 临时 stub：Web 端真实加密要接 potagi_crypto 的 WASM 产物
/// （`pkg/potagi_crypto_bg.wasm` + `potagi_crypto.js`，wasm-bindgen 导出
/// `wasm_encrypt_data`/`wasm_decrypt_data` 等），经 JS interop 调用后替换本文件。
/// 现阶段只保证 Web 能编译渲染（见部署方案 Step 1）。
class SgitCryptoFfi {
  SgitCryptoFfi._();

  static final SgitCryptoFfi _instance = SgitCryptoFfi._();
  static SgitCryptoFfi get instance => _instance;

  static const String _notWired = 'Web 端加密尚未接入 potagi_crypto WASM（待接）';

  String encrypt(String plaintext, String serverPublicKeyHex) =>
      throw UnsupportedError(_notWired);

  String decrypt(String hexCiphertext, String userPrivateKeyHex) =>
      throw UnsupportedError(_notWired);

  SgitKeyPair generateKeyPair() => throw UnsupportedError(_notWired);
}

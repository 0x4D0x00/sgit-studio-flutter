/// sgit_crypto_ffi 门面：按平台选择实现，公开 API 不变（调用方零改动）。
///
/// - 桌面/移动（有 dart:io）：`sgit_crypto_ffi_io.dart` —— 走原生 sgit_crypto 动态库。
/// - Web（dart.library.html）：`sgit_crypto_ffi_web.dart` —— 临时占位，待接 potagi_crypto WASM。
///
/// 纯数据类型（SgitKeyPair）从 *_types.dart 无条件导出，两端类型一致。
library;

export 'sgit_crypto_ffi_types.dart';
export 'sgit_crypto_ffi_io.dart'
    if (dart.library.html) 'sgit_crypto_ffi_web.dart';

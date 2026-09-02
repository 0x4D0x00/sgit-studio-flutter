/// sgit_request_ffi 门面：按平台选择实现，公开 API 不变（调用方零改动）。
///
/// - 桌面/移动（有 dart:io）：`sgit_request_ffi_io.dart` —— 走原生 sgit-ffi.dll。
/// - Web（dart.library.html）：`sgit_request_ffi_web.dart` —— 临时占位，待接 Rust。
///
/// 纯数据类型（Captcha / EndpointInfo）从 *_types.dart 无条件导出，两端类型一致。
library;

export 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi_types.dart';
export 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi_io.dart'
    if (dart.library.html) 'sgit_request_ffi_web.dart';

/// sgit_crypto_ffi 的纯数据类型（无 dart:io/dart:ffi），io / web 两端共享。

/// 用户 RSA 密钥对（hex 编码的 PEM）。
class SgitKeyPair {
  const SgitKeyPair({required this.privateKeyHex, required this.publicKeyHex});
  final String privateKeyHex;
  final String publicKeyHex;
}

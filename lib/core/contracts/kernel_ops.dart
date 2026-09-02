/// 内核中继的**动作词汇表** —— 与 gateway 的 `ClientFrame` / hello 的 `ops` 一一对应。
///
/// ## 为什么必须收成一份
///
/// 这里曾经踩过一次很贵的坑：gateway 的 `hello` 报的是
/// `["send","interrupt","steer","approve","ping"]`（**中继动作**），
/// 而 Dart 侧却在检查 `supports('turn/start')`（**app-server 的方法名**）。
/// 两套词汇永远对不上 → 每次发送都被判"内核不支持"而拒绝 → 触发自动重连 →
/// 连接开了又关，每秒好几条，用户看到的是"发消息完全没反应"。
///
/// 更糟的是 mock 当时声明的是 `turn/start` 那一套，**与真 gateway 不一致**，
/// 所以单测全绿、线上全坏。所以：
///
/// 1. 词汇只在本文件定义，能力检查与实际调用**都用它**，不许再出现裸字符串；
/// 2. mock 必须声明与 gateway **完全相同**的词汇（见 `kernel_client_mock.dart`），
///    否则测试就失去了发现这类漂移的能力。
///
/// ⚠️ 中继是**受限动作集**，不是通用 JSON-RPC 转发 —— 网关是多租户边界，
/// 放开任意方法等于把沙箱 app-server 的全部能力暴露给浏览器。加动作要两端同时改。
enum KernelOp {
  /// 起一轮对话（对应 app-server 的 `thread/start` + `turn/start`，
  /// 但**中继层的名字就叫 send**，别用内层名字）。
  send('send'),

  /// 掐掉当前 turn。
  interrupt('interrupt'),

  /// 中途插话，并进当前 turn（不重来）。
  steer('steer'),

  /// 回应审批。
  approve('approve'),

  /// 保活。
  ping('ping');

  const KernelOp(this.wire);

  /// 线上字面值。**与 gateway 的 `ClientFrame` tag 一致**，改一边必须改另一边。
  final String wire;
}

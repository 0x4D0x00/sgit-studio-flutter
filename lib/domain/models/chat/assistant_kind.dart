/// 助理种类 —— 中栏输入框上方那排可切换的「渗透 / 防护 / 竞赛 / 办公」。
///
/// 一个助理对应内核的一个 **scene**（thread 的归属），切助理就是换 scene 重开一轮
/// 对话，与左栏点历史助理走的是同一条路（`ChatController.newChatWithScene`）。
///
/// ⚠️ [sceneId] 是**发给内核的标识**，不是界面文案。改显示名去动 arb，别动这里 ——
/// 改了等于把用户的会话切到另一个场景。
enum AssistantKind {
  pentest('pentest'),
  defense('defense'),
  contest('contest'),
  office('office');

  const AssistantKind(this.sceneId);

  /// 传给内核的 scene id。
  final String sceneId;
}

# 内核 FFI 契约（sgit-studio-flutter ↔ sgcode）

> **两仓共用的唯一事实源。** 改动必须同时改这份文档 + 两仓实现，任何一边先行都算漂移。
>
> - Rust 侧：
>   - **`sgcode/sgcode-rs/sgit-kernel`** —— 平台无关核心：帧编码、delta 合并、背压、
>     app-server 通知映射。**桌面与 Web 共用的唯一实现**（同 `sgit-protocol` 的套路）。
>   - `sgcode/sgcode-rs/sgit-ffi` —— 桌面 cdylib 壳（C ABI + tokio + WS）
>   - `sgcode/sgcode-rs/sgit-ffi-web` —— wasm 壳（wasm_bindgen + web_sys WebSocket）
> - Dart 侧：`lib/data/transport/kernel/`（`kernel_client.dart` 接口 + io/web/mock 三实现）
>
> 帧格式的 golden 测试两边各一份，同一组输入、同样断言：
> `sgit-kernel/src/frame.rs::golden_bytes_match_dart_side`
> ↔ `test/kernel_frame_test.dart`「单帧往返 · 字段与 payload 逐项还原」。
>
> 版本：`FRAME_VERSION = 1`

---

## 0. 为什么是 FFI 而不是 Dart 直连

Flutter 客户端接 sgcode 内核**只走 FFI/WASM**，Dart 侧不许自己开 WebSocket 或 HTTP 打 gateway。

1. **性能**：WS 收包、解密、协议解析、delta 合并全在 Rust 原生线程完成，Dart 只按帧取走已经
   合并好的二进制帧。流式对话的 CPU 大头是 JSON→对象，这一步在 Dart 侧做就废了。
2. **Web 没得选**：Web 上 Dart 没有真多线程（`compute` 是同步执行），重活只能压给 wasm。
3. **安全模型一致**：会话 token 只在 Rust 侧持有、有意不回传 Dart（见
   `features/auth/auth_controller.dart` 的注释）。Dart 直连会破坏这个前提。

⚠️ Web 侧受限：整个 sgcode 编不进 wasm（mio / sqlite），所以 wasm 里的传输层必须用
`web_sys::WebSocket` 条件编译，不能直接搬桌面那份 tokio 实现。

---

## 1. 符号表

现有 5 个符号保留不动。新增 11 个，**桌面与 Web 必须同名同语义**
（现状两边只有 2 个符号重合，本次一并对齐）。

### 1.1 已有（不改）

| 符号 | 说明 |
|---|---|
| `sgit_probe_endpoint()` | 端点探测 |
| `sgit_image_captcha()` | 图形验证码 |
| `sgit_login_v2(...)` | 密码 + 验证码登录 |
| `sgit_request(...)` | sgit-server 统一加密入口 |
| `free_string(ptr)` | 释放 `char*` |

桌面缺 `sgit_is_authenticated` / `sgit_current_cid` / `sgit_logout`（Web 有），本次补齐。

### 1.2 新增 · 冷路径（JSON，低频）

```c
/// 建立到 gateway 的内核连接。Rust 侧负责重连、心跳、背压。
/// cfg_json: { "base_url": "...", "reconnect": true, "max_queue": 4096 }
/// 返回 handle，0 表示失败。
uint64_t sgit_kernel_open(const char* cfg_json);

/// 关闭连接并释放所有缓冲。幂等。
void sgit_kernel_close(uint64_t h);

/// 能力协商结果。调用方**禁止硬编码方法名清单**，UI 按此显隐。
/// 返回 { "frame_version": 1, "methods": ["thread/start", ...], "features": [...] }
char* sgit_kernel_caps(uint64_t h);

/// 投递一次内核请求（非阻塞，立即返回）。应答以 CallResult 帧回来，item_id == req_id。
/// method 为 app-server-protocol 方法名，如 "thread/start"、"turn/start"。
/// 返回 0 成功，负数为错误码。
int32_t sgit_kernel_call(uint64_t h, const char* method,
                         const char* params_json, uint64_t req_id);

/// gateway HTTP 端点桥接（8 个 studio 子页用）。复用同一会话与加密，同步返回。
/// path 如 "/sgcode-skill/list"，method 为 "GET"/"POST"。
/// 返回 JSON 字符串，用完 free_string。
char* sgit_gateway_call(uint64_t h, const char* path,
                        const char* method, const char* body_json);
```

### 1.3 新增 · 热路径（二进制零拷贝，高频）

```c
/// 注册唤醒回调。native 有新帧时调用，Dart 侧只置脏 + scheduleFrame。
/// ⚠️ 可能在任意 native 线程触发 → Dart 侧必须用 NativeCallable.listener。
/// native 侧做合并：两次唤醒间隔 >= 4ms。
void sgit_kernel_set_waker(uint64_t h, void (*waker)(void));

/// 取走当前批次的所有帧。*out 指向一块连续缓冲，内含 n 帧首尾相接。
/// 缓冲归 native 所有；调用方用完必须 sgit_kernel_release。
/// 在 release 之前不得再次 drain（单缓冲）。n == 0 时 *out 为 NULL，无需 release。
uint32_t sgit_kernel_drain(uint64_t h, uint8_t** out, uint32_t* out_len);

/// 归还 drain 拿到的缓冲。
void sgit_kernel_release(uint64_t h, uint8_t* buf);
```

### 1.4 新增 · 控制

```c
/// 中断当前 turn。
int32_t sgit_kernel_interrupt(uint64_t h, const char* turn_id);

/// 中途插话改方向（对应 CLI 的 turn/steer）。
int32_t sgit_kernel_steer(uint64_t h, const char* turn_id, const char* text);

/// 回应审批 / serverRequest。req_id 取自 Approval 帧。
/// decision_json: { "decision": "allow" | "allow_always" | "deny", "note": "..." }
int32_t sgit_kernel_respond(uint64_t h, uint64_t req_id, const char* decision_json);
```

所有 `int32_t` 返回：`0` = 成功，负数 = 错误码，错误详情以 Error 帧投递。

---

## 2. 帧格式

小端序。固定 32 字节头 + 变长 payload。

**对齐规则（Rust 侧必须照做，否则 Dart 从第二帧起全错位）**：
`total_len = 32 + align8(payload_len)`，即 payload 尾部补 0 到 8 的整数倍。
头本身 32 字节已是 8 对齐，所以每一帧的起始偏移恒为 8 的倍数。
`payload_len` 记的是**有效长度**，补的 0 不算在内。

```
偏移  长度  字段         类型   说明
  0    4   total_len    u32    整帧字节数（含头 + 尾部补齐）
  4    1   kind         u8     见 §2.1
  5    1   flags        u8     见 §2.2
  6    2   reserved     u16    置 0
  8    8   seq          u64    单调递增，跨重连不重置；用于丢帧检测
 16    8   item_id      u64    同一 item 的 delta 共享；CallResult 时 == req_id；否则 0
 24    4   payload_len  u32
 28    4   reserved2    u32    置 0
 32    …   payload
```

### 2.1 kind

| 值 | 名称 | payload | 可丢 |
|---|---|---|---|
| `0x00` | `Hello` | JSON，连接就绪 + 协商摘要 | 否 |
| `0x01` | `TurnStarted` | JSON | 否 |
| `0x02` | `TurnCompleted` | JSON `{turn_id, duration_ms, llm_ms, tool_ms}` | 否 |
| `0x03` | `ItemStarted` | JSON（item 元信息：类型、角色） | 否 |
| `0x04` | `ItemDelta` | **裸 UTF-8 文本**（已合并，不套 JSON） | **是** |
| `0x05` | `ItemCompleted` | JSON | 否 |
| `0x06` | `ToolBegin` | JSON（工具名、入参摘要） | 否 |
| `0x07` | `ToolEnd` | JSON（结果、耗时、是否截断） | 否 |
| `0x08` | `ProcessOutput` | **裸 UTF-8** | **是** |
| `0x09` | `Approval` | JSON `{req_id, kind, reason}`，需 `sgit_kernel_respond` 回应。**帧的 `item_id` 指向被审批的那条工具 item** | 否 |
| `0x0A` | `Compacted` | JSON（压缩点信息） | 否 |
| `0x0B` | `ModelRerouted` | JSON | 否 |
| `0x0C` | `CallResult` | JSON，`item_id == req_id` | 否 |
| `0x0D` | `Error` | JSON `{code, message, fatal}` | 否 |
| `0x0E` | `Disconnected` | JSON `{reason, will_retry, retry_in_ms}` | 否 |
| `0x0F` | `TokenUsage` | JSON `{turn_id, input_tokens, cached_input_tokens, output_tokens, total_tokens}` | 否 |

新增 kind 只能追加，不得复用旧值。Dart 侧遇到未知 kind **静默忽略**，不报错。

### 2.1.0 两条只有对着真协议才看得出来的坑

写这份契约时是照 JSON 字段名猜的，接上类型化协议（`sgcode-app-server-protocol`）后
现了四处错，全是"字段名猜错 → 静默取到空值"，自造 JSON 的测试还测不出来：

| 猜的 | 真实 | 后果 |
|---|---|---|
| `params.turnId` | `TurnStartedNotification.turn.id` | turn id 永远空串 |
| `params.to` | `ModelReroutedNotification.to_model` | 改道提示永远空 |
| `outputDelta.chunk`（还以为是 base64） | `.delta`（纯文本） | 命令输出全丢 |
| `turn/completed` 里带 usage | 用量在**独立**的 `thread/tokenUsage/updated` | 用量永远 0 |

由此定两条规矩：
1. **Rust 侧只吃类型化的 `ServerNotification` / `ServerRequest`**，不手解 JSON ——
   字段名交给编译器，内核加通知种类时 `match` 会提醒。
2. **审批请求不带内容**：`CommandExecutionRequestApprovalParams` 里只有 `itemId`，
   命令/补丁全文在之前 `item/started` 推过的那条 item 上。所以 `Approval` 帧的
   `item_id` 指向那条工具 item，客户端把审批卡**挂上去**，而不是自己再显示一份。

### 2.1.1 `item_id` 是不透明句柄，别解析它

app-server 协议里 `item_id` 是**字符串**，帧头里是 `u64`。Rust 侧
（`sgit-kernel/src/session.rs` 的 `IdTable`）做字符串驻留：同一个协议 id 永远映射到
同一个 `u64`，但**这个数字没有任何协议含义**，Dart 侧只能拿它做相等比较（"这条 delta
属于哪个气泡"），不许解析、不许回传给内核。

为什么不在帧里直接放字符串：帧头定长，变长 id 只能塞进 payload，那 Dart 为了认出归属
就必须解 payload —— 热路径又回到 `jsonDecode` 上，整个方案的意义就没了。

`callResult` / `approval` 两类帧的 `item_id` 是另一套语义（分别是 `req_id`），见 §2.1 表格。

### 2.2 flags

| bit | 名称 | 含义 |
|---|---|---|
| 0 | `truncated` | payload 被 native 截断，完整内容需走冷路径取 |
| 1 | `final` | 该 item 的最后一帧 |
| 2 | `binary` | payload 非 UTF-8（预留，当前恒 0） |

---

## 3. native 侧合并器（性能全在这）

Rust 侧在投递前**必须**做完这四件事，Dart 侧不做任何一件：

1. **delta 合并**：同 `item_id` 的连续 `ItemDelta` 在一个帧周期（≥4ms）内拼接成一帧。
   单帧 payload 上限 **64 KB**，超出分帧。
2. **输出截断**：`ToolEnd` / `ProcessOutput` 的 payload 上限 **256 KB**，超出截断并置
   `flags.truncated`。
   > 有先例：超大 rollout 曾把内核 CPU 打满（memory `chat-wont-stop-thread-read-oversized-rollout`）。
   > 前端同样扛不住，必须在 native 就掐掉。
3. **无用事件过滤**：前端不消费的通知（如 `rawResponseItem/completed`）**根本不投递**。
4. **背压**：队列满时只对「可丢」类（`0x04` / `0x08`）做丢弃合并，保留最新累积值；
   **语义事件永不丢**。丢弃时 `seq` 会出现跳跃。

### 唤醒的两条硬规则

1. **最后一帧之后必须再唤醒一次。** turn 收尾（`TurnCompleted`）、被打断、审批回执 ——
   这些"最后一批"帧入队后如果不再调 waker，消费者永远差最后一批，表现是
   「回答显示完了但用量条不出现 / 状态卡在 busy」。
   > mock 通道第一版就是在 `turnEnd` 那一步提前 `return` 掉了 waker 调用，被
   > `test/chat_ui_test.dart` 抓到。Rust 侧同一个坑。
2. **唤醒频率上限 4ms**，但**不得因为限流而丢掉最后一次唤醒** —— 限流器要有尾部触发
   （trailing edge），不能只做前沿合并。

### 丢帧后 Dart 的处理

`seq` 不连续 ⇒ native 因背压丢过 delta。Dart 侧对该 item 走一次冷路径 `thread/read` 补全，
或就地显示"内容已合并"标记。**不许假装没发生**。

---

## 4. Dart 侧调用规范

```dart
// 1) waker 只置脏 + 请一帧，绝不在 native 回调里干活
final _waker = NativeCallable<Void Function()>.listener(() {
  _dirty = true;
  SchedulerBinding.instance.scheduleFrame();
});

// 2) 每帧最多 drain 一次 —— 来 500 条 delta 也只重建一次
SchedulerBinding.instance.addPostFrameCallback((_) {
  if (!_dirty) return;
  _dirty = false;
  final n = _drain();            // 一次拿一批
  if (n > 0) _notifyOnce();      // 一次通知，一次 rebuild
});

// 3) 零拷贝读帧：不复制 native 内存，不产生中间对象
final bytes = outPtr.value.asTypedList(outLen.value);
final view  = ByteData.sublistView(bytes);
```

**禁止**：在 Dart 侧 `jsonDecode` 任何 `ItemDelta`；对每条 delta 单独 `setState`；
在 waker 回调里直接 drain。

---

## 5. Web 侧映射

| 桌面 | Web（wasm_bindgen） |
|---|---|
| `sgit_kernel_drain(h, **out, *len) -> u32` | `sgit_kernel_drain(h) -> Uint8Array`（同一帧格式） |
| `sgit_kernel_set_waker(h, fnptr)` | `sgit_kernel_set_waker(h, jsCallback)` |
| `sgit_kernel_release(h, buf)` | 不需要（GC 管） |
| 其余符号 | 同名，`char*` → `String` |

Dart 侧用 `js_interop` 的 `.toDart` 拿 `Uint8List`，**帧解析代码两端共用一份**。

---

## 6. 版本与兼容

- `sgit_kernel_caps` 返回的 `frame_version` 与 Dart 侧 `FRAME_VERSION` 不一致 → 直接拒绝连接，
  提示升级客户端。不做跨版本兼容降级。
- `methods` 数组是 UI 显隐的依据。app-server-protocol 里有大量 `#[experimental]` 方法，
  **Dart 不许硬编码方法名清单**，否则内核升协议就碎。

---

## 7. 构建

两个 crate 都是**随包分发的库**，与"现网 bin 用 dev profile"的铁律无关：

```bash
# 桌面
cargo build --release -p sgit-ffi          # 产物 → deploy/sync-native.sh

# Web
cd deploy && ./build-wasm.sh               # 内部须带 --release + wasm-opt -Oz
```

⚠️ **必须 `--release`**。流式解析上 dev / release 差一个数量级，这是 FFI 方案的全部意义所在。

**体积预算**：`web/pkg/sgit_ffi_web_bg.wasm` 当前 614 KB，加 WS + 协议后**上限 1 MB**
（Web 首屏已背了 4.1 MB 字体，不能再叠）。超了先 `wasm-opt -Oz`，再砍依赖。

---

## 8. 验收

| 项 | 判据 |
|---|---|
| 符号对齐 | 桌面与 Web 导出符号名与语义逐一相同 |
| 帧格式 | 两仓各有一份 golden 测试，同一批事件产出同样字节 |
| 合并生效 | 1000 条 delta 输入 → drain 帧数 < 60（按 60fps 一秒） |
| 零拷贝 | Dart 侧 profile 中该路径无 `List.copyRange` / `jsonDecode` |
| 截断 | 单条 1 MB 工具输出 → payload ≤ 256 KB 且 `flags.truncated == 1` |
| 背压 | 队列打满时语义事件零丢失，`seq` 跳跃可被 Dart 检出 |

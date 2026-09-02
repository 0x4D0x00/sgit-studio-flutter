# sgit-studio-flutter 架构基准

> 本文件是本仓的**对齐基准**。动手前先读这份，改架构先改这份。
> 内核通信契约另见 [`docs/KERNEL_FFI.md`](docs/KERNEL_FFI.md)（两仓共用）。

## 定位

sgcode 是内核，**CLI 是一种展示方式，本客户端是另一种**。所以：

- 内核有的能力，我们原则上都要有 —— 但**映射成 GUI 惯用交互**，不是照搬 55 个斜杠命令。
- 内核已经算好的（token 用量、耗时、压缩点、审批决策），**消费它，不重算**。
- 一切内核通信走 FFI/WASM，见 `docs/KERNEL_FFI.md`。

---

## 一、六层分工

```
lib/
├── main.dart                      # 只有一行 bootstrap()
├── bootstrap/                     # 启动编排：并行预热 → runApp → 错误兜底
├── app/                           # 应用装配：MaterialApp / DI 根 / observer。零业务
│
├── core/                          # 基础设施。禁 import material，可纯单测
│   ├── config/ contracts/ result/ concurrency/ storage/ logging/ diagnostics/ utils/
│   └── state/                     #   Readable<T> 门面（仅横切状态用，见三）
│
├── data/                          # 【接口层】与后端对话，与 UI 零关系
│   ├── transport/kernel/          #   FFI 内核通道（io / web 两实现 + 帧解析）
│   ├── transport/                 #   其余通道
│   ├── endpoints/ dto/ mappers/ cache/ repositories/
│
├── domain/                        # 【功能层】业务规则，纯 Dart
│   ├── models/ usecases/
│
├── services/                      # 【服务层】应用级横切能力，无 UI
│   ├── auth/ permission/ brand/ config/ notification/ shortcut/
│   ├── command/                   #   命令总线（见四）
│   ├── telemetry/                 #   本地埋点（见五）
│   └── ui_control/                #   AI 控制面（见六）
│
├── design/                        # 【UI 层】设计系统：只有令牌与皮肤，无业务
│   ├── tokens/ themes/ extensions/ effects/
│
├── ui/                            # 【组件层】纯展示。零状态库、零业务
│   ├── primitives/ components/ patterns/ feedback/
│
├── layout/                        # 【布局层】只管空间，不管内容
│   ├── responsive/ metrics/ shell/ panels/ state/ engine/
│
├── features/                      # 【功能页】每个自包含、可整目录删
│   └── <feature>/
│       ├── <feature>_feature.dart #   注册清单：路由/菜单/权限/i18n/命令/UI能力
│       ├── application/           #   controller、notifier
│       └── presentation/{pages,widgets}/
│
├── router/                        # 路由装配：路由表由 feature registry 生成
├── l10n/                          # 多语言
└── platform/                      # 平台差异：桌面窗口 / web / PWA / input
```

### 依赖方向（单向，CI 卡死）

```
features → domain → core        features → ui → design        features → layout
data     → domain → core        services → data / domain

禁止： ui → features      layout → features      design → 任何业务
       core → flutter/material                   任何层 → 具体第三方实现
```

---

## 二、可替换点清单（"拒绝深度捆绑"）

每个第三方 / 外部契约只有一个出入口，换掉只动一处。

| 被捆绑对象 | 隔离位置 | 换掉的代价 |
|---|---|---|
| Riverpod | `features/*/application` + `services/` + 5 个横切门面 | ~10 文件 |
| go_router | `router/`，路由表由 feature registry 生成 | 1 目录 |
| dio | 只在 `data/transport/` | 2 文件 |
| shared_preferences | `core/storage/` 的 KV 抽象背后 | 1 文件 |
| **sgcode 协议** | `data/dto` + `data/mappers`。协议 DTO **不许进 domain/UI** | 只改 mappers |
| Flutter Material | `ui/primitives/` 收口，业务页不直接用 `TextField` 等 | 只改 primitives |
| 后端地址 | 运行时配置，**禁编译期写死** | — |
| 品牌 | `brand.json` 外置优先（已做对） | — |

**静态单例是比状态库更严重的耦合。** `ApiClient.instance`、`LocalStorage.instance` 这类必须全部
换成 `core/contracts` 抽象 + `app/app_providers.dart` 装配。

---

## 三、状态管理：靠分层而非抽象换取可替换性

当前 Riverpod，备选 Signals。**不写通用抽象层** —— 那种抽象会把两个库的能力砍到只剩
`get/set/listen`，两边都用不爽还多一层。

| 层 | 允许碰状态库 | 怎么拿数据 |
|---|---|---|
| `design/` `ui/` `layout/` | **禁止** import 任何状态库、禁止 import `features/` | 构造参数传值 + 回调传出 |
| `features/*/presentation/` | 只在**页面根节点**一个 `Consumer` 取值 | 一页一个订阅点 |
| `features/*/application/`、`services/` | 允许，**且只有这里允许** | Riverpod Notifier |

**例外说明**：`Theme.of(context)`（含 `AppSkin`）与 `AppLocalizations.of(context)` 不算状态库依赖
—— 它们是 Flutter 自带的 `InheritedWidget` 上下文资源，换状态管理库影响不到。`ui/` `layout/`
可以自由用这两个，不必把每个颜色和文案都当参数传下去。

**横切状态住哪里**：主题 / 语言 / 特效 / 布局 / 会话这五样的 controller 一律放 `services/`
（如 `services/layout/layout_controller.dart`），**不放 `layout/` 或 `design/`** —— 那两层按上表
不许 import 状态库。纯组件由 `features/shell/presentation/*_container.dart` 这类容器喂数据。

只对 **5 个横切状态**（主题 / 语言 / 特效等级 / 布局 / 会话）做薄门面：

```dart
// core/state/reactive.dart —— 不依赖任何状态库
abstract interface class Readable<T> {
  T get value;
  void Function() listen(void Function(T) cb);
}
// state/riverpod/  当前实现（~10 行 adapter）
// state/signals/   备用实现，同一份接口
```

**界限说死：只有这 5 个走门面，业务状态直接用 Riverpod，不套壳。**

### 精确订阅

禁裸 `ref.watch(provider)` 取整个大 state，必须 `.select(...)`。

---

## 四、命令总线：一条总线，四个入口

不做两套命令系统。斜杠命令只是 CLI 的展示方式，我们把**内核能力**接出来，给它四个入口：

```
                    ┌─ 输入框打 "/"（斜杠补全，含 ~/.sgitai/commands/ 的用户自定义命令）
CommandBus ─────────┼─ Ctrl+K 命令面板（模糊搜索全部能力）
(sealed UiCommand)  ├─ GUI 控件（按钮/菜单/开关）
                    └─ AI 控制面（ui.dispatch）
```

分支一律用 Dart 3 **switch 表达式** + `sealed class`，拿编译期穷尽性检查：

```dart
UiResult dispatch(UiCommand c) => switch (c) {
      SetThemeMode(:final mode)        => _theme.setMode(mode),
      SetEffectLevel(:final level)     => _effects.setLevel(level),
      TogglePanel(:final id)           => _layout.toggle(id),
      InterruptTurn(:final turnId)     => _kernel.interrupt(turnId),
      SteerTurn(:final turnId, :final text) => _kernel.steer(turnId, text),
      ApplyLayout(:final spec)         => _layoutEngine.apply(spec),
    };
```

---

## 五、埋点：本地诊断设施，不是回传管道

内核侧已有完整 analytics（`sgcode-rs/analytics`，36 类 fact），且**外发通道已在源码层强制关停**。
所以我们：

| 层 | 做法 |
|---|---|
| 内核事件镜像 | 消费 `turn/*`、`item/*`、`thread/compacted`、`process/*`，落本地。不重算 |
| 前端自有 | 只补内核看不见的：① 性能（首帧/帧耗时/jank/请求耗时/rebuild 热点）② 可用性（命令使用、放弃率、错误码分布）③ 交互（面板开合、特效等级分布） |
| 出口 | `Telemetry` sink 抽象，**LocalSink 默认**（本地文件，滚动上限），`NoopSink` 可切。**默认不外发、不引第三方 SDK** |
| 消费 | `/dev/telemetry` 本地看板 + 一键导出排障包 |

---

## 六、AI 控制面

三层，复用第四节的命令总线（所以增量成本很低）。

1. **能力清单（自描述）** —— 每个能力声明 JSON Schema，manifest 由
   `tool/gen_ui_manifest.dart` **从注册表生成**，不手写（手写必过期）。
2. **命令执行** —— 就是 `CommandBus`，AI 只是第四个入口。
3. **声明式布局** —— AI 产 `LayoutSpec` JSON，`layout/engine/` 按**组件白名单**渲染。

护栏（缺一不可）：白名单（未注册 id 一律拒绝，不 fallback）、节点数/深度/体积限额、
Schema 校验失败整份拒绝（不部分应用）、**预览模式**（用户确认才生效）、回滚栈、审计日志、
`ui.resetLayout()` 一键复原。

**授权默认**：主题/字号/语言/特效/面板开合可写；导航跳转与 `ApplyLayout` 需用户确认；
数据类操作一律不进控制面。

---

## 七、编码约定

| 规则 | 落地 |
|---|---|
| 能 switch 绝不 if-elif | 状态一律 `enum`/`sealed class`，分支一律 switch 表达式。CI 卡连续 ≥2 个 `else if` |
| 能并发绝不串联 | 独立 IO 一律 `Future.wait`。CI 扫互不依赖的连续 `await` |
| 重活不在 UI isolate | 桌面 `Isolate.run` + 池；**Web 无真多线程 → 下沉 Rust WASM** |
| 禁魔法数字 | 全走 `design/tokens`。CI 扫裸 `Color(0x`、裸 `Duration(` |
| 禁硬编码文案 | CI 扫 widget 树里的中英文字面量 |
| 禁 `isDark ? A : B` | 一律读 `AppSkin.of(context)`。**唯一合法处是 `design/themes/app_theme.dart`**（主题构建器本身） |
| 单一职责 | 单文件 ≤200 行 |

### 已知例外（有意保留，别当漂移）

- `features/auth/presentation/pages/login_page.dart` —— 450 行，且内部自持一份 `isDark`。
  登录页的配色是**刻意不跟随动态主色**的（1:1 对齐 studio 设计稿，见 `AppColors.login*` 与页内
  `_LoginMetrics`），拆分与令牌化留到接内核之后再动，避免现在唯一能跑通的功能出问题。
| 精确订阅 | 禁裸 `ref.watch` 取大 state |

---

## 八、明确**不做**（防后人加戏）

- ❌ Riverpod/Signals 通用抽象层（只做 5 个横切门面）
- ❌ 插件系统 / 微前端 / 动态下发 Dart 代码
- ❌ 自造状态机框架、DI 框架、路由
- ❌ 把 CLI 的 55 个斜杠命令做成 55 个页面
- ❌ 第三方分析 SDK、任何数据回传
- ❌ GraphQL / 额外 BFF（gateway 就是我们的 BFF）
- ❌ studio 8 子页的**管理版**（只做个人版 per-cid）
- ❌ 死代码留仓

---

## 九、期次

| 期 | 内容 | 仓 |
|---|---|---|
| **P0** | 目录搬迁 + 令牌化 + 切断 UI 层状态库依赖 + 删死代码 + 后端地址改运行时配置 | flutter |
| **P1a** ∥ | FFI 内核会话面（11 符号 + 帧格式 + 合并器 + 符号对齐 + release 构建） | **sgcode** |
| **P1b** ∥ | `KernelClient` 抽象 + 对话 UI + 工具卡 + 审批卡 + 打断/steer。**先用 mock 帧发生器跑通渲染与性能** | flutter |
| **P2** | 两线合流联调 + 会话 CRUD + 能力协商 + 压缩/计划/目标模式 | 两仓 |
| **P3** | 命令总线（斜杠/Ctrl+K/GUI 三入口合一）+ 快捷键 + 反馈服务 | flutter |
| **P4** | 特效分级 + 响应式/密度 + 性能治理 + 本地埋点 + 字体子集化 | flutter |
| **P5** | 8 子页个人版（7 页配置化 + 中转站定制） | flutter |
| **P6** | AI 控制面 + 布局引擎 + 测试基线 + CI 规则全开 | flutter |

P1a / P1b 能并行的前提是 `docs/KERNEL_FFI.md` 已定死 —— 那是整个计划唯一的串行卡点。

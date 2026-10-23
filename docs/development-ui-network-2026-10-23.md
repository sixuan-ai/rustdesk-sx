# RustDesk UI 与网络开发基线

本文保留首次源码导览时的观察。后续用户要求统一使用最新稳定 SDK；环境适配、构建及 OMEN 双屏验收已经完成，以 [Linux 构建验收记录](development-linux-latest-stable-2026-10-23.md) 为当前状态。

## 基线

- 观察日期：2026-10-23；本机目录 `/home/x/code/rustdesk`。
- 官方稳定标签：`1.5.0`，提交 `fada664df7a294d1d1a9ca3e7cd3637069122f17`。
- 本地分支：`codex/stable-1.5.0-dev`；原 `master` 和远端配置保留。
- `libs/hbb_common` 固定为标签记录的 `229b904508364c8997aad0fb5af57effac859f60`。
- 本次只建立源码基线、阅读实现并记录入口，没有修改运行逻辑或部署客户端。

## UI 入口

| 范围 | 文件 / 符号 | 作用 |
| --- | --- | --- |
| 桌面主页 | `flutter/lib/desktop/pages/desktop_home_page.dart` | 主窗口、页面组织 |
| 连接面板 | `flutter/lib/desktop/pages/connection_page.dart`：`onConnect` | 读取目标 ID/IP，发起连接 |
| 连接分发 | `flutter/lib/common.dart`：`connect`、`connectMainDesktop` | 标准化输入、连接类型、强制中继、窗口调度 |
| 远程桌面 | `flutter/lib/desktop/pages/remote_page.dart`：`RemotePage` | 启动会话、画面与输入交互 |
| 远程工具栏 | `flutter/lib/desktop/widgets/remote_toolbar.dart` | 屏幕菜单、显示、键盘、会话操作 |
| 设置页 | `flutter/lib/desktop/pages/desktop_setting_page.dart`：`_NetworkState` | ID/中继服务器、代理等网络选项 |
| 状态与事件 | `flutter/lib/models/model.dart`：`FFI.start` | 添加/启动会话，监听 Rust 事件，更新画面及状态 |
| 平台绑定 | `flutter/lib/models/platform_model.dart`、`native_model.dart` | 原生 FFI；Web 使用条件导入的另一条实现 |

当前桌面界面使用 Flutter；`src/ui/` 是旧 Sciter 界面，不作为本次 UI 开发的首选入口。

## 连接调用链

```text
ConnectionPage.onConnect
  -> common.dart: connect -> connectMainDesktop -> 远程窗口 / RemotePage
  -> model.dart: FFI.start
  -> bind.sessionAddSync / sessionStart（生成的 Dart FFI）
  -> src/flutter_ffi.rs: session_add_sync / session_start
  -> src/flutter.rs: session_add / session_start_
  -> src/client/io_loop.rs: Client::start
  -> src/client.rs: Client::_start
     ├─ IP 或 domain:port：connect_tcp_local
     └─ ID：rendezvous 协调、打洞及中继回退
  -> 登录认证 -> 会话消息 / 视频 / 输入 -> EventToUI 回到 Flutter
```

- `src/client.rs`：传输建立与竞争、直连/中继选择、登录消息。当前版本包含 TCP、UDP/KCP、IPv6、WebRTC 等路径；ID 连接不能简化成单一 TCP 打洞。
- `src/rendezvous_mediator.rs`：被控端注册、协调连接，以及 `direct_server` 直连监听。是否监听由 `direct-server` 等选项控制，端口来自 `direct-access-port`，默认 21118。
- `src/server/connection.rs`：被控端认证、权限和消息处理；`handle_switch_display`、`capture_displays` 处理屏幕请求。
- `libs/hbb_common/protos/rendezvous.proto`：服务器协调协议；`libs/base/protos/message.proto`：会话协议。
- `libs/hbb_common/src/socket_client.rs`：底层 socket 连接工具。

## 与现有使用场景有关的边界

1. 输入 Tailscale IP 时走直接 TCP，不经过 ID 服务器的查找、打洞和中继选择；仍进入会话登录认证流程。应分别验证端口可达、认证、首帧、持续刷新、输入。
2. 直连标志不能等同于应用层加密标志；`src/client/io_loop.rs` 分别读取 `direct` 和 `peer.is_secured()`。后续连接状态 UI 应保留这个区别。
3. Wayland 共享授权与网络连通独立。`libs/scrap/src/wayland/pipewire.rs` 维护 Portal 会话和 `wayland-restore-token`；工具栏只能对已提供的显示器集合执行会话操作，不能假设可绕过系统共享选择。
4. 多窗口可能共享底层会话。`session_start_` 只在首个需要连接的 UI 会话启动 IO；改动重连、关闭、切屏时应保留此生命周期。

## 本机开发环境检查

- `cargo metadata --no-deps --format-version 1`：通过，仅验证工作区清单解析。
- `flutter doctor -v`：全部通过，Linux 桌面基础工具链可用。
- 本机 Flutter `3.47.7` / Dart `3.13.5`，Rust `1.99.1`；该标签普通 Linux CI 指定 Flutter `3.24.5`、Rust `1.75`。后续宜为本仓库单独准备匹配环境，避免更换全局 SDK 影响其他项目。
- 缺少本地生成产物：`src/bridge_generated.rs`、`flutter/lib/generated_bridge.dart`、`flutter/lib/generated_bridge.freezed.dart`。这些文件被 Git 忽略；上游 `.github/workflows/bridge.yml` 固定 FRB codegen `1.80.1` 并上传 bridge artifact。
- `pkg-config` 能找到 GTK、XTest、XRandR、XFixes、XCursor、Xi、ALSA、PulseAudio、GStreamer；未找到 `xdo`、`libpipewire-0.3`、`opus`、`vpx`、`aom`、`libyuv`。这只是 pkg-config 发现结果，不证明库完全未安装，也不是完整构建诊断。
- 检查的常见目录 `/opt/vcpkg`、`/home/x/vcpkg` 不存在，未发现本仓库 Flutter 依赖缓存或构建目录；仍需按上游构建配置准备原生依赖。
- 尚未运行依赖解析、完整编译、自动测试或本分支客户端的远程连接测试，不能把已安装客户端的运行结果当作源码验证。

## 下一步开发顺序

1. 准备隔离、匹配上游的 Linux 构建环境，并取得与当前源码严格匹配的桥接产物；不要把其他版本的桥接文件混入。
2. 先完成未改动基线的编译与本机启动，再以 Tailscale 直连验证认证、持续画面、输入及多屏；ID/中继另行验证。
3. 第一轮 UI 优先检查连接面板、连接状态表达、屏幕选择和网络设置；功能需求明确后做局部修改，避免先重写会话与传输层。
4. 构建并发不超过 6。每次修改分别报告静态检查、编译和实际远程验证结果。

回退源码基线：先保存后续本地改动，再 `git switch master` 和 `git submodule update --init --recursive --jobs 6`。本次没有改变已安装 RustDesk 或远端 OMEN 的运行配置。

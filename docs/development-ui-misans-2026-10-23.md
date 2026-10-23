# RustDesk 桌面 UI：MiSans 与 AAA 参考配色

日期：2026-10-23。基线：`5b2627c15`；开发分支 `codex/stable-1.5.0-dev`。

## 设计与范围

用户提供 `AAA/` 五张参考图：深紫星空、粉紫软质形象、浅色渐变界面、青色和淡金色点缀。本轮采用浅色粉紫连接面板、对应深紫暗色版本，以及原创的矢量连接伙伴。参考图本身不进入应用资源。

配色：纸白 `#FCFAFF`、正文 `#29223D`、交互紫 `#7650BC`、柔粉 `#F3A5E4`、浅青 `#BAEEE8`、暗色底 `#171329`。连接面板 24px 圆角；控件 14px；侧栏 240px。正文与输入仍左对齐。

```text
┌──────────────┬───────────────────────────────────┐
│ RustDesk     │ 控制远程桌面             原创图案 │
│ 你的桌面     │ [ID / IP]  [连接] [更多连接方式]   │
│ ID / 密码    ├───────────────────────────────────┤
│ 状态与帮助   │ 最近连接 / 收藏 / 发现 / 地址簿   │
│              │ 原有设备列表                      │
└──────────────┴───────────────────────────────────┘
```

评审取舍：仅连接面板使用柔光和图案，设备列表保持原有密度；警告保留原内容与入口，改为高对比的素色边框卡。窗口较窄时隐藏装饰，保留输入和连接功能。没有加入装饰动画。保留现有连接、设备筛选、身份验证和自定义客户端 Logo 路径。

## 字体与语言

- `flutter/assets/fonts/misans/` 内置官方完整 TTF：Regular 400、Medium 500、Bold 700，总计约 23MiB。离线可用，字库未经裁剪或修改。
- 来源：<https://hyperos.mi.com/font-download/MiSans.zip>。官方授权：<https://hyperos.mi.com/font/zh/download/>。随资源保存 `LICENSE.pdf` / `LICENSE.txt`；字体保持原版权及单独许可。
- `main.dart` 向 Flutter LicenseRegistry 注册字体授权；桌面“关于”页显示 `MiSans · Xiaomi` 和许可入口。
- 默认翻译 fallback 为 `zh_CN`，Material 控件也默认 `zh-CN`。显式保存的语言由原 Rust 翻译逻辑继续优先处理；Material locale 同步该偏好，支持切回英语或繁体等语言。
- 终端继续使用其原有等宽字体，图标字体也保留。普通 UI 使用 MiSans；原有三处 WorkSans 显式覆盖已同步。

## 已验证

环境沿用本机 Flutter 3.47.7 / Dart 3.13.5 / Rust 1.99.1；Ubuntu 26.04.1、GNOME Wayland、Skia 开发启动器。没有升级 SDK 或依赖版本。

```bash
res/dev/build_linux.sh
cd flutter
flutter test --no-pub --concurrency 2 test/companion_ui_test.dart test/quality_monitor_transport_test.dart test/server_settings_dialog_test.dart test/input_modifier_utils_test.dart test/cursor_replay_test.dart
```

- Linux Debug bundle 构建成功；74 项测试通过，其中 3 项新增测试覆盖中文默认/显式语言和两种主题下的 320/520/900px 连接区域布局及输入。
- 对修改过的 Dart 文件运行 `flutter analyze --no-pub`：无 error；仍有原代码的 warning 和弃用提示。新主题保留旧界面使用的 ColorScheme.background，SDK 对该接口有弃用提示。
- 本机实际窗口检查：800×600 的浅色/暗色首页；1040×720；680×480（窄窗口隐藏图案，侧栏和设备区域可滚动）。检查了设置页、主题切换、更多连接方式菜单及关于页。
- MiSans 字体、授权和 FontManifest 已出现在最终 bundle 中，TTF 与官方压缩包逐字节一致。
- 最终构建重启后的日志未发现 Flutter 布局 overflow 或资源加载异常。真实截图位于 `~/.cache/rustdesk-dev/ui-*.png`，日志也在该缓存目录，不进入 Git。
- 人工主题切换后恢复原“跟随系统”偏好；最终开发客户端仍由本仓库 bundle 运行。

注意：此前版本通过的 OMEN 双屏/输入验收不能替代本轮重新验收。本轮仅验证本机 UI；没有重新完成 OMEN 输入/多屏测试，也没有将 UI 部署到 OMEN。

## 回归面与最小化审阅

| 修改的已有文件 | 变化的已有路径与必要性 |
| --- | --- |
| `flutter/lib/common.dart` | 主题外层接入与 accent；Material locale helper。全局字体、配色和默认中文必须覆盖各窗口。 |
| `flutter/lib/models/platform_model.dart` | 将翻译的系统 locale fallback 改为简体中文，保留 Rust 的已保存语言优先级。 |
| `flutter/lib/main.dart` | 注册字体许可，两个 MaterialApp 入口使用相同 locale。 |
| `flutter/lib/desktop/pages/desktop_home_page.dart` | 首页侧栏背景、宽度、品牌、ID 字号空间、只读值样式、滚动与提示卡；避免新字体裁切和视觉冲突。 |
| `flutter/lib/desktop/pages/connection_page.dart` | 连接面板容器、MiSans、40px 操作按钮；原输入格式化、自动补全、onConnect 和菜单回调未重写。 |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | 关于页显示 MiSans 与许可入口，原蓝色版权卡使用主题的前景/背景配色。 |
| `flutter/lib/desktop/widgets/tabbar_widget.dart` | 两个旧蓝色非选中图标色替换为配套紫色。 |
| `flutter/lib/common/widgets/overlay.dart`, `flutter/lib/mobile/pages/connection_page.dart` | 两处显式字体覆盖同步为 MiSans。 |
| `flutter/pubspec.yaml` | 声明本地字体与授权资源。 |

主题实现与矢量插画分别放在新的独立文件；无 Rust、协议、FFI、鉴权、画面采集或输入转发代码变更。审阅时去掉 Flutter 工具自动添加的 `analysis_options.yaml` 排除段，未夹带格式化清理。

## 限制与回滚

- 本轮未验证 Android/iOS/Web/macOS/Windows 构建，也未逐页检查全部文件传输、终端和远程会话弹窗。全局主题和默认语言会影响这些界面，移动端还有一处显式字体覆盖。
- Linux Debug 本机验收不代表其他平台已通过；硬件编码、发布包及 OMEN 无人值守行为不在本轮验证范围。
- 回滚代码可对本 UI 提交执行 `git revert`（先保留后续工作），再执行构建和启动脚本。系统 RustDesk 未被替换，OMEN 软件和配置未被部署修改。

最终 Debug UI kernel SHA-256：`9f1afe8ed141ca80d6a53f05dd17a62a0bb95b7a7b03a0dbbb2b59946083a504`。

## 连接首页与设备列表细化（2026-10-23）

在 `codex/stable-1.5.0-dev` 上继续完善首页。保留 AAA 参考的粉紫、薄荷配色和 MiSans，集中解决连接面板在宽窗口过度拉伸、设备分类只有图标、空列表缺少层级和更多菜单点击范围过小的问题。

- 连接面板左对齐，最大宽度 980；输入框增加设备图标和实色底，连接按钮填满可用宽度。
- 更多菜单保留原有操作，点击区域扩展到整个 44×44 控件，并补充提示。
- 品牌显示 `RustDesk SX` 和“思玄二次开发版”。
- 桌面设备分类根据剩余宽度显示全部标签、当前标签或纯图标；图标模式仍提供名称与选中状态的无障碍语义。工具条随文字缩放增加高度。
- 桌面空列表使用对应分类图标、标题和原有本地化提示；短窗口可滚动。

### 回归面与最小化检查

逐项检查最终差异，既有文件的变化仅涉及：

| 文件 | 既有路径变化与原因 |
| --- | --- |
| `flutter/lib/desktop/pages/connection_page.dart` | 桌面首页的连接面板尺寸、输入框外观、主按钮尺寸及更多按钮点击范围；原有输入控制器、自动补全、认证和各连接回调保留。 |
| `flutter/lib/desktop/widgets/companion_connection_surface.dart` | 侧栏品牌文字及其可收缩布局；原有绘图保留。 |
| `flutter/lib/common/widgets/peer_tab_page.dart` | 分类条增加宽度测量和桌面标签，桌面高度适配文字缩放；标签组件位于新增的桌面 widgets 文件。移动端和 Web 保留原图标和 32 高度，重排、固定选项、分类切换和持久化回调保留。 |
| `flutter/lib/common/widgets/peers_view.dart` | 仅桌面空数据分支接入新组件；非空设备列表、过滤和缓存，以及移动端/Web 空状态保留。 |
| `flutter/test/companion_ui_test.dart` | 新增品牌窄侧栏、图标分类语义、短窗口大字号空状态共 3 项回归。 |

新文件 `flutter/lib/desktop/widgets/companion_peer_widgets.dart` 只负责表现，不加载设备、不保存状态、不引入依赖。共享文件因嵌套布局产生的缩进变化已经检查，没有顺带修改其他逻辑。Flutter 自动生成的 `analysis_options.yaml` 排除项不纳入提交。

### 验证

在本机 Linux，使用 `/home/x/flutter/bin/flutter`：

```bash
# 从 flutter/ 执行
flutter test test/companion_ui_test.dart --concurrency=2
flutter test --concurrency=2
flutter analyze --no-pub lib/desktop/widgets/companion_peer_widgets.dart lib/desktop/widgets/companion_connection_surface.dart lib/desktop/pages/connection_page.dart lib/common/widgets/peer_tab_page.dart lib/common/widgets/peers_view.dart test/companion_ui_test.dart
PATH="$HOME/.local/share/rustdesk-dev/build-tools:$PATH" RUSTDESK_BUILD_JOBS=2 CMAKE_BUILD_PARALLEL_LEVEL=2 flutter build linux --debug --no-pub
```

- 定向测试 6 项、全套测试 141 项通过。浅/深色连接表单覆盖 320、520、900 宽度；新增品牌与空状态覆盖 1.5 倍文字缩放、240 宽侧栏和 280×160 短窗口。测试中的表单是组件组合，不代表完整首页的小窗口实机验证。
- 定向分析无 error/warning，8 个 info 均为原有 API 的废弃提示。`file_picker` 插件元数据提示仍存在，未在本轮处理。
- Linux Debug 构建通过。通过 `flutter attach` 热更新现有本机客户端，实际渲染截图确认深色大窗口的品牌、连接面板、分类标签和收藏空状态。未重启 OMEN 服务，未重新验证远端画面、键鼠或网络性能。
- 运行截图包含设备标识，留在本机私有缓存，未加入仓库。

### 剩余范围与回滚

本轮未改造非空设备卡片、设置页或远控工具条；完整首页在小窗口、浅色以及 Windows/macOS 上的人工交互仍待后续核对。移动端/Web 未执行构建验证。

仅修改源码和本机 Debug 构建产物；未修改服务、账号或持久配置。回滚时撤销本节对应的 UI 提交并重新执行上述 Debug 构建，再重新启动本机开发客户端。改动保留在当前开发分支，本轮未推送远端。

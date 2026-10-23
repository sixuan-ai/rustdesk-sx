# Linux 最新稳定工具链构建与 OMEN 双屏验收

## Summary

RustDesk 官方稳定标签 `1.5.0` 已在本机使用当前稳定 Flutter/Rust 编译并运行，完成 Tailscale 连接 OMEN、持续画面、键盘、鼠标及 AOC → 内屏 → AOC 切换验证。产物为开发用 Debug bundle，未替换系统安装的客户端。

## Environment

- 日期：2026-10-23；目录 `/home/x/code/rustdesk`；分支 `codex/stable-1.5.0-dev`。
- 上游基线：`fada664df7a294d1d1a9ca3e7cd3637069122f17`；`hbb_common`：`229b904508364c8997aad0fb5af57effac859f60`。
- 本机 Ubuntu 26.04.1，GNOME Wayland，NVIDIA RTX 5060 Ti；Flutter **3.47.7**、Dart **3.13.5**、Rust **1.99.1**、GCC **15.2.0**、Clang **21.1.8**、CMake **4.2.3**。
- 已通过 Flutter 发布索引和 `rustup check` 核对当前稳定 SDK。用户要求统一使用最新稳定环境，未沿用旧版 Flutter；临时下载的 3.24.5 SDK 和压缩包已删除。
- OMEN 为 GNOME Wayland，内屏与 AOC 外屏。本次通过 Tailscale 直连 TCP 21118，`tailscale ping` 显示直接端点约 21 ms；不是中继功能验收。

## Symptoms

1. 初始源码缺生成的 Rust/Dart 桥接文件，缺部分 Linux 原生开发包。
2. 旧主题类型与字体/富文本依赖不兼容新版 Flutter。
3. Freezed 2.5.8 / Analyzer 7.7.1 在 Dart 3.13 下报 `Missing implementation of visitDotShorthandPropertyAccess`。
4. 固定版本 libwebm 的 C++ 源码在 GCC 15 下报 `uint32_t / uint64_t does not name a type`。
5. 首次默认渲染配置的原生窗口为黑色，虽然 Flutter inspector 能重新绘制主界面；切换 Skia / GDK_SCALE=1 后正常。
6. OMEN 等待共享选择时自动锁屏，旧 Portal 请求超时；新会话在未锁定状态下完成双屏选择。

## Investigation / Root cause

- 生成器依赖的旧 Analyzer 不认识当前 SDK 的语法节点，升级生成依赖后成功。没有修改 FFI 协议。
- libwebm 的 `mkvparser.cc` 使用固定宽度整数却未显式包含 `cstdint`，依赖旧标准库的间接包含。添加编译选项后通过。
- Ubuntu `libyuv-dev` 有库和头文件，但无 `libyuv.pc`；构建脚本在用户目录补充元数据，未修改系统库或 `build.rs`。
- 大型 Git 依赖使用精确提交浅拉取。一个 GitHub 传输发生 TLS 截断，HTTP/1.1 重试成功；不据此断言 TLS 故障的唯一原因。
- 渲染方面确认了可用组合：最新 SDK + X11 GTK backend + Skia + GDK_SCALE=1。尚未分别隔离 Impeller、缩放与 NVIDIA/Wayland 的责任，不能宣称已修复 Impeller 本身。
- X11 根窗口截图在 Wayland 返回黑图；Flutter inspector 重绘也不能证明原生窗口实际显示。验收使用 Skia engine 的 `_flutter.screenshot` 获取真实渲染帧，并以目标端测试窗口状态交叉核对。
- 本机观察到 X11/合成器坐标及鼠标加速差异。验证助手用原生 uinput 小步移动并读取反馈，点击前核对目标窗口，未修改用户全局鼠标设置。

## Fix / 可复用命令

安装的开发依赖命令：

```bash
sudo apt-get install -y libxdo-dev libpipewire-0.3-dev libopus-dev libvpx-dev libaom-dev libyuv-dev libclang-dev libxcb-randr0-dev libxcb-shape0-dev libxcb-xfixes0-dev libpam0g-dev libudev-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libayatana-appindicator3-dev nasm libssl-dev libasound2-dev libpulse-dev libxkbcommon-dev
```

APT 为匹配开发包同时升级了系统 systemd/udev 依赖至 `259.9-0ubuntu0.1`；未手动重新配置这些服务。另安装过 `gnome-screenshot` 做诊断，最终验收未依赖它。

桥接生成器匹配本稳定版的 FRB 1.x ABI，不是 Rust SDK 降级：

```bash
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked --jobs 2 --root "$HOME/.local/share/rustdesk-dev/tools"
cd /home/x/code/rustdesk
res/dev/build_linux.sh --generate-bridge
res/dev/run_linux.sh
res/dev/run_linux.sh --connect 100.89.0.1
```

若本机代理可用，可仅为上述构建命令设置 `HTTPS_PROXY=http://127.0.0.1:7897` 和 Git 的临时代理配置，不需要修改全局 Git 配置。其余缺少的 crates 曾从国内镜像预缓存，逐包核对 `Cargo.lock` 的 SHA-256；未改锁定的 Rust 依赖版本。

- `res/dev/build_linux.sh`：使用 PATH 中当前 SDK；默认 2 jobs（允许 1–6）；原生库通过 `linux-pkg-config` 链接系统软件编解码库；局部补齐 libyuv 元数据；`CXXFLAGS=-include cstdint`；CMake 旧插件兼容设置；Ninja 独立限并发。
- `res/dev/run_linux.sh`：默认 Skia、X11 backend、GDK_SCALE=1，仅影响此进程；`--no-server` 避免开发 UI 额外启动本机接收服务。可用 `RUSTDESK_DEV_RENDERER=impeller` 单独调查另一渲染路径，但不属于已通过的运行配置。
- `res/dev/git_shallow_fetch.py`：只给 Cargo 精确提交拉取追加浅拉取及 HTTP/1.1；普通 Git 操作不受影响。
- `res/dev/remote_probe.py`：目标端 GTK 测试窗口，显示时钟、帧标记、输入框和点击计数；状态 JSON 原子写入，SSH 只读核对。
- `res/dev/capture_flutter.py`：调试视图截图，不输出本机 VM service 的认证地址；`--inspector` 仅供重绘诊断。
- `res/dev/native_pointer.py`：已知窗口内的人工验收辅助；需要已有 ydotool 服务与权限。

生成的桥接、依赖、二进制、运行日志和截图仍位于忽略目录或本机缓存，未加入 Git。

## Verification

本机通过：

```bash
res/dev/build_linux.sh
flutter test --no-pub --concurrency 2 test/quality_monitor_transport_test.dart test/server_settings_dialog_test.dart test/input_modifier_utils_test.dart test/cursor_replay_test.dart
bash -n res/dev/build_linux.sh res/dev/run_linux.sh
git diff --check
```

测试在 `flutter/` 下运行：**71 passed**。构建成功生成 `flutter/build/linux/x64/debug/bundle/rustdesk` 和 `lib/librustdesk.so`。核心构建的实际命令为 `cargo rustc --locked --lib --features flutter,linux-pkg-config,unix-file-copy-paste --crate-type cdylib`，随后 `flutter build linux --debug --no-pub`。旧代码仍有弃用及命名警告，未批量修改。

运行进程的 `/proc/<pid>/exe` 与映射库均指向本仓库 bundle，排除了误用系统客户端。产物 SHA-256：

```text
rustdesk: da3d9925460cd16f57ee5a33395fa03d073deae7a94b7fac2cb9b3c55a6b6fe6
lib/librustdesk.so: 7677b568aeb54d7de3ded0ece3320a59c737abd09c7397f575295faf9c98c807
```

OMEN 实际验收：

| 检查 | 结果 |
| --- | --- |
| 永久密码认证、系统 Portal 双屏选择 | 成功；未变更密码 |
| 画面接收及解码 | AV1 软件解码初始化成功，时钟/帧标记持续更新 |
| AOC 输入 | `OMEN-AOC-stable-150`，目标端 JSON 核对一致 |
| 内屏输入 | `OMEN-internal-stable-150`，目标端 JSON 核对一致 |
| 内屏鼠标 | 点击计数 1 |
| AOC 鼠标 | 切回后再次点击，计数从 1 增至 2 |
| 多屏 | AOC → 内屏 → AOC；两个画面标签与内容匹配 |
| 持续刷新 | AOC 可见帧标记从 190、258、373 增至 383；清理前两窗口 JSON 均为 432 |

远端在清理过期共享请求时重启过 `rustdesk.service`；最终仍为 active。临时 GTK 窗口与防空闲进程均已结束。当前连接保留在 AOC，缩放改为适应窗口。未把新二进制部署到 OMEN。

## Remaining risk / rollback

- 仅验证 Linux 本机 Debug、Skia 及 Tailscale IP 直连；未验证 Release 包、硬件编解码、ID/中继、其他平台、声音/剪贴板/传文件或重启后的无人值守共享。
- Wayland 的系统共享授权和锁屏约束仍然存在；未修改系统安全策略。测试期间临时阻止空闲仅用于验收，现已解除。
- SDK 与系统依赖保留作为开发环境。退出开发客户端即可重新使用原安装客户端；系统 RustDesk 包未覆盖。
- 源码回退先保存后续改动，再切回原 `master` 并同步子模块。渲染配置只在启动脚本的子进程中生效，无需回退全局 SDK/桌面设置。
- 若要恢复旧显示偏好，在远程工具栏把 Scale adaptive 改回 Scale original；需要改变共享范围时，通过 OMEN 系统 Portal 重新选择。
- 现有运行代码变更仅 `flutter/lib/common.dart` 的两套主题构造 API；`flutter/pubspec.yaml`/lock 更新编译所需依赖。连接、认证、输入、抓屏与传输 Rust 实现均未修改。

NAS 知识条目（已写入并读回核验）：`experience/2026-10-23-rustdesk-1-5-0-flutter-3-47-linux-build-and-tailscale-dual-m.md`。

# RustDesk SX · 思玄二次开发版

面向中文桌面体验、Linux Wayland 和高分辨率远控的 RustDesk 衍生版本。

基于 [RustDesk 1.5.0](https://github.com/rustdesk/rustdesk/tree/1.5.0)，由 **转瞬之澜（思玄） / [Max Stark（@sixuan-ai）](https://github.com/sixuan-ai)** 独立维护，保留上游 Git 历史、版权与 AGPL-3.0 许可证。

[下载预览版](https://github.com/sixuan-ai/rustdesk-sx/releases) · [安装与使用](#安装与使用) · [源码构建](#源码构建) · [开发记录](#开发记录) · [反馈问题](https://github.com/sixuan-ai/rustdesk-sx/issues)

> 当前阶段：**Linux 开发预览**。已发布 Ubuntu 26.04 x86_64 包；持续 4K60 尚未达标，其他平台尚无本分支验证的发布包。

## 下载

当前发布：[`v2.1.0`](https://github.com/sixuan-ai/rustdesk-sx/releases/tag/v2.1.0)，更新日期 **2026-10-26**。

| 文件 | 用途 |
| --- | --- |
| [Ubuntu 26.04 安装包（.deb）](https://github.com/sixuan-ai/rustdesk-sx/releases/download/v2.1.0/rustdesk-sx_2.1.0_amd64.deb) | 安装后通过桌面入口或 `rustdesk-sx` 启动 |
| [Linux x86_64 便携包（.tar.gz）](https://github.com/sixuan-ai/rustdesk-sx/releases/download/v2.1.0/rustdesk-sx-2.1.0-linux-x86_64-ubuntu26.04.tar.gz) | 解压后通过 `run.sh` 启动 |
| [SHA256SUMS](https://github.com/sixuan-ai/rustdesk-sx/releases/download/v2.1.0/SHA256SUMS) / [BUILD-INFO.json](https://github.com/sixuan-ai/rustdesk-sx/releases/download/v2.1.0/BUILD-INFO.json) | 文件校验、精确源码提交、编译特性与运行依赖 |

**两个包均面向 Ubuntu 26.04 x86_64，依赖 glibc ≥ 2.43、FFmpeg 8 和对应系统库，不适用于 Ubuntu 24.04。** 便携包也依赖系统库。Windows、macOS、ARM 及其他 Linux 发行版未提供此次验证包。

发布包对应源码标签；`main` 上的后续提交不会自动更新已发布的二进制。思玄版自本次起使用独立版本号 **`2.1.0`**，应用显示、安装包和发行标签统一；上游基线仍记录为 RustDesk 1.5.0。

## 这一版做了什么

| 方向 | 当前内容与范围 |
| --- | --- |
| 中文桌面 UI | 默认简体中文、MiSans 字体、粉紫／薄荷配色；完善连接首页、设备卡片、搜索反馈和状态提示 |
| 原生 Wayland 客户端 | 已在 Ubuntu 26.04 / GNOME Wayland 开发环境运行和验证；不代表所有合成器、所有 Linux 发行版都已适配 |
| 剪贴板与中文输入 | 文本剪贴板路径，以及本机输入法选词后发送到远端的中文输入辅助；各有独立验证记录 |
| Tailscale / IP 直连 | 通过 Tailscale IP 实测远控；Tailscale 由用户单独安装和配置，本项目不内置组网服务 |
| 高分辨率与多屏 | Linux 4K H.265 / NVENC / CUDA 链路、多屏切换和解码器资源管理有实测记录；持续 4K60 仍在优化 |
| 无人值守与唤醒 | 包含 DRM 抓屏库和可选服务配置；OMEN GNOME Wayland 已验证熄屏唤醒、锁屏输入系统密码，以及断线/服务重启恢复 |
| 性能分析 | 可选的逐屏采集、像素转换、编解码、提交与队列监测；实验性性能开关不默认启用 |

这些是当前分支的实现与已有验证范围，不是对所有硬件和平台的兼容承诺。文件传输等上游功能的继承，也不等于本分支已完成相应平台的专项回归。

### 界面预览

![思玄版设备组件浅色与深色预览](res/screenshots/rustdesk-sx-components.png)

上图由实际 Flutter 组件与 MiSans 渲染，使用示例设备数据，展示设备卡片、搜索无匹配和 ID 服务器状态；**不是完整首页截图，也不是在线设备实测结果**。设计与验证过程见 [UI 开发记录](docs/development-ui-misans-2026-10-23.md)。

## 安装与使用

### Ubuntu 26.04 安装包

下载 `.deb` 后，在下载目录执行：

```bash
sudo apt install ./rustdesk-sx_2.1.0_amd64.deb
rustdesk-sx
```

安装包使用独立的程序目录与桌面入口，不安装、替换或启停现有 RustDesk 系统服务。**应用仍使用 RustDesk 的用户配置位置**，已有账号和设备设置可能共用，不应把独立安装路径理解为配置隔离。

无人值守被控端需要主动启用系统服务，具体命令与回退步骤见包内 `README.zh-CN.txt` 和[本次发布记录](docs/releases/2026-10-26-version-2.1.0.md)。启用会重启现有 RustDesk 连接；屏幕唤醒后仍由用户输入系统密码，不会自动解锁。便携包推荐仅作客户端。

卸载应用：`sudo apt remove rustdesk-sx`；启用过无人值守服务的用户须先按发布记录回退服务配置。这不会自动清除用户配置。

### 便携包

下载 `.tar.gz` 后执行：

```bash
tar -xzf rustdesk-sx-2.1.0-linux-x86_64-ubuntu26.04.tar.gz
cd rustdesk-sx-2.1.0-linux-x86_64-ubuntu26.04
./run.sh
```

仅启动客户端可使用 `./run.sh --no-server`。请保留同目录的 `lib/`、`data/` 和启动脚本；不要只复制一个可执行文件。

### 通过 Tailscale 连接

1. 两台设备先通过各自的 Tailscale 加入可互通的网络。
2. 被控端运行 RustDesk，并允许“IP 直接访问”；访问策略、端口和认证按被控端配置。
3. 在思玄版连接框输入目标设备的 Tailscale IP，完成 RustDesk 密码或授权流程。
4. 若被控端使用 Portal 抓屏，首次按系统提示选择共享屏幕并勾选记住；已启用本包 DRM 无人值守服务的 OMEN 无需再次点击分享。仍需验证目标系统的支持情况。

底部的 **ID 服务器状态**不代表 Tailscale/IP 直连是否可用；等待被控端选择共享屏幕，也不应直接判断为客户端卡死。Tailscale 组网不会替代 RustDesk 认证；Portal 授权与 DRM 系统服务是不同的被控路径。

### 仅直连模式（main 源码）

适用于只通过 Tailscale/IP 或显式 `host:port` 连接、不使用 RustDesk ID／中继服务的场景。**当前下载页的 v2.1.0 包尚未包含此源码更新。**

先退出 RustDesk，备份 `~/.config/rustdesk/RustDesk2.toml`，在已有 `[options]` 内加入（不要重复建立该节，也不要覆盖其他选项）：

```toml
[options]
direct-only = 'Y'
```

随后重启。此模式跳过 ID 注册、NAT／ID 测速及公共 ID 回退；数字设备 ID 无法用于连接，请输入 Tailscale/IP 或 `host:port`。设备卡片显示直连端口是否可达，这不等同于已通过远控认证。

原有账号 API、密码和设备记录仍保留；需要接受直连的设备继续启用原有“IP 直接访问”。账号／组网服务与 RustDesk ID／中继服务是独立职责。修改模式需要重启，不要用“停止服务”代替它。回滚到不支持此选项的旧版本前，应恢复备份的 ID／中继配置。

源码同时包含 Linux 主窗口退出前的后台事件清理，以及验证码逐字输入的焦点修复。一次正常关闭／重启未复现此前崩溃，Flutter 原生退出警告仍存在；详细验证范围见[直连与退出记录](docs/incidents/2026-10-30-local-direct-only-and-shutdown.md)。

## 验证状态与已知限制

截至 **2026-10-26**：

- 2026-10-23 的源码 Flutter 测试 **144 项通过**，包含 UI、输入及其他现有模块的回归；这不是 144 项真实远控场景验收。
- 当前发布包已完成优化 Release 构建、随包 ELF 动态依赖检查、解压后的版本入口与校验和检查，以及当前主机的 apt 模拟安装。
- Linux Debug / Release 的 4K H.265 硬件链路有此前的实测记录；**本次打包未重新执行完整图形界面、远端键鼠或多屏回归**。
- **持续 4K60 尚未达标**；提交回调帧率不等于合成器实际呈现帧率。双屏同时稳定 4K60、长期低显存及弱网画质仍需继续验证。
- 2.1.0 沿用此前 OMEN 实测的 DRM/DRM-wake 实现和固定抓屏库，已确认熄屏、锁屏手动登录和服务重启恢复；注销 GDM、整机重启、挂起恢复及其他硬件未验证。Debug 的“连接中”呈现问题尚未定位，发布使用 Release。仍未完全去除 X11 依赖。
- 公共包使用系统 GTK，未包含开发机针对 GTK 3.24.52 的私有 AT-SPI 修复；相关系统问题可能仍影响图形交互。

具体平台、测试负载与证据分别见 [发布验证记录](docs/releases/2026-10-26-version-2.1.0.md)和[性能对照记录](docs/incidents/2026-10-23-release-pipewire-clock-baseline.md)。

## 源码构建

发布主分支为 `main`；持续开发分支为 `codex/stable-1.5.0-dev`。获取本项目源码与子模块：

```bash
git clone --branch main --recurse-submodules https://github.com/sixuan-ai/rustdesk-sx.git
cd rustdesk-sx
```

2026-10-30 已验证源码构建工具链为 Ubuntu 26.04.1、Flutter **3.47.9** / Dart **3.13.7**、Rust **1.99.1**。开发方向是当前稳定工具链；这里记录的是验证版本，不代表任意后续 SDK 都已验证。当前桌面 UI 使用 **Flutter**，不使用旧 Sciter 构建步骤。

先按 [Linux 构建记录](docs/development-linux-latest-stable-2026-10-23.md)准备 Rust、Flutter Linux 桌面工具链、原生开发依赖及代码生成器。`flutter_rust_bridge_codegen 1.80.1` 用于匹配上游稳定基线的桥接 ABI；首次检出需生成被 Git 忽略的桥接文件。

```bash
# 首次构建：生成桥接并构建带硬件编解码的 Debug bundle
RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh --generate-bridge
res/dev/run_linux.sh

# 后续构建优化 Release，需已有桥接产物
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release res/dev/build_linux.sh
RUSTDESK_DEV_BUILD_MODE=release res/dev/run_linux.sh
```

硬件编解码路径依赖系统 FFmpeg 开发库；省略 `RUSTDESK_DEV_HWCODEC=1` 可构建不启用该可选路径的版本。默认并发 2，上限 6。产物位于 `flutter/build/linux/x64/{debug,release}/bundle/`；开发启动器与可分发安装包用途不同，无人值守构建还需 `RUSTDESK_DEV_DRM=1` 及固定版本 libdrmtap；打包入口见 [发布记录](docs/releases/2026-10-26-version-2.1.0.md)。

## 开发记录

| 文档 | 内容 |
| --- | --- |
| [二次开发说明](FORK.md) | 上游基线、维护来源、许可与分支说明 |
| [UI 与网络代码导览](docs/development-ui-network-2026-10-23.md) | 源码入口与模块关系 |
| [中文 UI / MiSans](docs/development-ui-misans-2026-10-23.md) | 参考设计、组件迭代与测试范围 |
| [原生 Wayland](docs/development-native-wayland-2026-10-23.md) | Linux 客户端启动和运行验证 |
| [剪贴板与中文输入](docs/development-wayland-text-2026-10-23.md) | 文本路径、输入法与实际验收 |
| [最新性能对照](docs/incidents/2026-10-23-release-pipewire-clock-baseline.md) | Debug / Release、采集节拍与当前 4K60 限制 |
| [无人值守预览包发布](docs/releases/2026-10-26-version-2.1.0.md) | 编译、依赖、打包、验证和回滚 |

后续重点是继续完善桌面交互、减少 X11 依赖、定位高分辨率吞吐瓶颈，并逐步扩大平台与安装验证范围。反馈问题时，请说明系统/桌面会话、显卡、软件版本、连接方式和复现步骤；不要提交密码、令牌或完整用户配置。

## 来源与许可

这是独立维护的二次开发版本。上游项目为 [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk)，稳定基线为 `1.5.0`；上游官方服务、商店版本和社区不由本仓库维护。

- 项目代码沿用 [GNU AGPL-3.0](LICENCE)，保留上游作者版权和来源说明。
- MiSans 保留小米及字体作者的版权，适用其[独立字体许可与来源说明](flutter/assets/fonts/misans/README.md)。
- Flutter、其他依赖及资源按各自许可提供，不因“思玄版”署名而转移版权。

更完整的维护与来源说明见 [FORK.md](FORK.md)。其他语言的历史 README 保留上游参考内容，当前思玄版状态以本页和日期明确的开发记录为准。

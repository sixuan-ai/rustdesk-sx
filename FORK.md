# RustDesk · 思玄二次开发版

- 项目仓库：https://github.com/sixuan-ai/rustdesk-sx
- 二次开发维护：**转瞬之澜（思玄）**。
- GitHub 账号：[Max Stark（@sixuan-ai）](https://github.com/sixuan-ai)。
- 上游项目：[rustdesk/rustdesk](https://github.com/rustdesk/rustdesk)。
- 思玄版当前版本：`2.1.0`，使用独立版本号，不再沿用上游版本加 SX 日期后缀。
- 上游稳定基线：`1.5.0`，提交 `fada664df7a294d1d1a9ca3e7cd3637069122f17`。
- 发布主分支：`main`；持续开发分支：`codex/stable-1.5.0-dev`。
- 说明日期：2026-10-23。

## 来源与许可

本项目是 RustDesk 的独立衍生版本，保留上游 Git 历史、原作者版权声明和根目录 [LICENCE](LICENCE) 的 GNU Affero General Public License v3。由本仓库维护者提供的代码修改沿用该许可。请在再分发与修改时保留适用的许可证和来源说明。

RustDesk 名称及原有标识属于其原权利人；本仓库通过“思玄二次开发版”区分维护来源。上游 README 中的官方商业服务、社区和下载地址属于上游项目。

第三方依赖和资源按各自许可提供，不因本项目署名而转移版权。特别是随应用附带的未修改 MiSans 字体，保留[字体来源与版权说明](flutter/assets/fonts/misans/README.md)及 LICENSE.pdf／LICENSE.txt，不能将字体单独声明为 AGPL 代码或本项目原创资源。

## 修改方向

- 中文桌面界面、MiSans 字体和桌面主题调整。
- 原生 Wayland 启动、GTK 输入法环境适配、文本剪贴板和中文输入辅助。
- 逐屏采集、转换、编解码、提交和发送队列的可选监测。
- PipeWire 已映射帧比较复用、Linux 多屏解码器资源生命周期管理。
- 当前稳定 Rust／Flutter SDK、系统 FFmpeg 的硬件编解码适配，以及匹配的 Debug／Release 构建入口。

这些修改的入口和验证范围见 `docs/development-*.md` 及 `docs/incidents/` 下的日期记录。实验性并行转换、NVENC 参数和 appsink 时钟开关没有因为公开发布而改成默认启用。

## 构建入口

```bash
git clone --recurse-submodules https://github.com/sixuan-ai/rustdesk-sx.git
cd rustdesk-sx
```

本分支最近验证环境为 Ubuntu 26.04.1／GNOME Wayland、Flutter 3.47.7、Rust 1.99.1。使用当前稳定 SDK，FRB 代码生成器 `1.80.1` 则须与本稳定基线的桥接 ABI 匹配。原生依赖、代码生成和隔离补丁的配置见 [Linux 构建记录](docs/development-linux-latest-stable-2026-10-23.md)。首次检出需生成被 Git 忽略的桥接文件：

```bash
RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh --generate-bridge
res/dev/run_linux.sh
```

后续已有桥接产物时：

```bash
RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release res/dev/build_linux.sh
RUSTDESK_DEV_BUILD_MODE=release res/dev/run_linux.sh
```

构建默认两项并发，上限六项。硬件路径需要所述系统 FFmpeg 开发库；省略 `RUSTDESK_DEV_HWCODEC=1` 则不启用该可选构建路径。开发启动器对进程应用原生 Wayland／Skia 设置，独立测试包不等于系统安装包。

## 已验证范围与当前限制

Linux Debug 和完整 Release 已构建、运行，并通过 Tailscale IP 直连实测 3840×2160 的 H.265／NVENC／CUDA 链路。中文输入辅助、文本剪贴板和多屏切换有各自日期明确的验收记录；不能将一次测试概括为所有平台、所有 Wayland 合成器均可用。

**持续 4K60 尚未达标。** 最新对照仍观察到源端供帧不足和 Release 提交等待；队列没有溢出或解码错误，不等于画面已达到物理显示 60 FPS。具体样本和测试负载见[最新性能验证](docs/incidents/2026-10-23-release-pipewire-clock-baseline.md)。

Wayland 的桌面共享选择属于被控端系统授权流程；出现提示时应在被控端选择共享屏幕。等待共享授权与网络连接失败或客户端卡死须分别判断。

源码和 Linux x86_64 / Ubuntu 26.04 开发预览包通过 [GitHub Releases](https://github.com/sixuan-ai/rustdesk-sx/releases) 提供；本分支的 Windows、macOS、移动端打包，以及长期低显存／双屏同时 4K60 等场景没有在本轮验证。二进制发布应附带对应源码版本、许可和适用的第三方声明。

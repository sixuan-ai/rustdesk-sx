# RustDesk SX 首个 Linux 下载包

发布版本：`v1.5.0-sx.20261023.1`；包版本：`1.5.0+sx.20261023.1`。发布位置：
https://github.com/sixuan-ai/rustdesk-sx/releases/tag/v1.5.0-sx.20261023.1

源码发布分支为 `main`，本机继续在 `codex/stable-1.5.0-dev` 开发。上游 1.5.0 历史和原有分支保留。该版本作为开发预览发布，不触发上游的普通版本标签自动构建流程。

## 构建和打包

在 Ubuntu 26.04.1 LTS x86_64 开发机上构建；使用当前系统 FFmpeg 8 和带 `hwcodec` 的 Flutter Release 路径，并发限制为 2：

```bash
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
```

将 Flutter 自动补入的 `analysis_options.yaml` 排除项恢复到仓库状态，确认所需源码已提交且工作区干净，再执行：

```bash
python3 res/dev/package_linux_release.py \
  --version 1.5.0+sx.20261023.1 \
  --output /home/x/.cache/rustdesk-dev/releases/v1.5.0-sx.20261023.1 \
  --flutter-root /home/x/flutter
```

脚本只复制 Release bundle 的可执行文件、lib、data，以及项目/字体/Flutter 许可，不复制用户配置、日志和认证数据。包里不包含开发机的 GTK 私有库，不引用开发机绝对运行路径。输出包括：

- Linux x86_64 / Ubuntu 26.04 便携 `.tar.gz`，解压运行 `./run.sh`。
- `rustdesk-sx` `.deb`，用 `sudo apt install ./包名.deb` 安装，桌面或 `rustdesk-sx` 启动。
- `BUILD-INFO.json`、中文说明和 `SHA256SUMS`。

打包过程对全部随包 ELF 执行 `ldd` 检查，使用 `dpkg-shlibdeps` 从符号元数据生成依赖，并对便携入口执行 `--version` 冒烟检查。包版本写入元数据，界面基础版本仍保留上游的 1.5.0。JSON 记录精确 Git 提交及子模块版本，公开源码可按对应标签递归克隆重建。

`.deb` 使用独立的 `/usr/lib/rustdesk-sx`、`/usr/bin/rustdesk-sx` 和桌面入口，无安装脚本，不启停/替换系统服务。应用本身仍使用 RustDesk 的用户配置位置，不能据此认为账号和设备设置已隔离。

## 发布验证与边界

对最终包检查 Debian 元数据与文件清单，在临时目录解压后核对启动版本和 `SHA256SUMS`；使用 apt 模拟安装检查当前主机的依赖解析，不执行实际安装。发布后核对远端 `main`/标签提交，以及 GitHub 附件 SHA-256。

源码 UI 回归测试 144 项已通过；Release 构建/动态依赖检查/版本入口不等于新包已经通过完整图形交互和远端网络回归。本次不重启当前 OMEN 远控会话。持续 4K60 仍未达标；Wayland 被控端仍依赖系统共享授权。

当前仅提供 Ubuntu 26.04 x86_64 包，不宣称兼容 Ubuntu 24.04。系统 GTK 3.24.52 的已知 AT-SPI 问题仍取决于发行版修复情况；便携包中的说明明确指出没有打包开发机的私有 GTK 修复。Windows/macOS/ARM 和其他 Linux 发行版的打包与安装待单独验证。

## 变更范围与回滚

新增 `res/dev/package_linux_release.py` 是独立打包入口；README 的思玄版下载链接不再指向上游程序，FORK 文档增加 `main` 和平台范围。没有修改客户端协议、运行时代码、CI 或系统服务。

本机卸载 `sudo apt remove rustdesk-sx`，便携包删除解压目录；不删除用户配置。GitHub 主分支如需回滚，使用后续 revert 提交保留历史；发布包可撤回对应 Release 附件。原开发分支继续保留。

# Wayland 高分辨率逐屏监测与硬件验证

## 范围与测量边界

开发分支 `codex/stable-1.5.0-dev`；基线 `e62221774`。
本机 Ubuntu 26.04.1 / GNOME Wayland，Flutter 3.47.7、Rust 1.99.1；
OMEN 通过 Tailscale IP 直连 TCP 21118。两端 NVIDIA，OMEN RTX 4060 Laptop。

新增开关 `RUSTDESK_DISPLAY_METRICS=1`，默认关闭，不改变现有队列容量、
丢帧/刷新策略、协议或 FPS 控制。日志级别须允许 info，例如 `RUST_LOG=info`。
Linux root 服务通过 sudo 切换桌面用户时，只在此开关启用时传递监测变量与
日志过滤设置；不扩大其它环境变量的传递范围。

| 日志事件 | 字段与含义 |
| --- | --- |
| `display_metrics` | 每个显示器收到消息速率、提交回调速率、解码后尺寸、实际解码实现/硬件设备类型、队列当前与峰值积压、溢出、丢弃、解码错误；队列等待、解码/转换、Flutter 提交回调的 p50/p95/max。 |
| `server_display_metrics` | 每屏采集调用、像素转换、编码、服务入队的 p50/p95/max。采集调用包括 WouldBlock，不是显示器传感器延迟；入队不含网络写入。 |
| `server_video_queue_metrics` | 视频消息已有入队时刻到 dequeue 的等待 p95，以及 send 路径耗时 p95；`shared_queue_peak` 是同一连接所有显示器共用的队列深度，按正在发送的屏幕关联，不能理解为独立逐屏队列长度。 |

队列时间使用本端单调时钟，不依赖两机时钟同步。客户端关键帧仍走原有
mpsc 通道，其它帧仍走原有 ArrayQueue，只附带接收时刻；pending 同时包含
两条路径的待处理消息。客户端 pending 不包含正在解码的消息。

每窗口每阶段最多 512 个样本，正常 60/144 FPS 窗口可全部覆盖；超出后只保留
窗口前 512 个样本。日志最多每屏约每秒一条，空闲客户端窗口仍可报告零帧。
汇总工具报告“窗口 p95 的均值/最大值”，不能当成全部帧混合后的 p95。

**提交回调 FPS 不等于合成器实际呈现 FPS。** 当前没有端到端玻璃到玻璃延迟、
Flutter raster/compositor presentation acknowledgement 或丢帧呈现统计。
H.265 协商名称本身不证明硬件路径；需要结合编码器创建日志、
`decoder=ffmpeg/hevc/AV_HWDEVICE_TYPE_CUDA` 和按进程 GPU 引擎观测。
服务端 `hardware_encoder` 使用既有 EncoderApi 标志，实际名称仍以成功创建
编码器的日志为准。`stream_write_p95_ms` 包含 dequeue 后的通知处理与 Stream
send 调用，不代表对方已经解码或显示。

## 构建与运行

```bash
RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh
# 先等待主窗口完成初始化，再用第二条命令打开连接。
env -u DISPLAY RUSTDESK_DISPLAY_METRICS=1 RUST_LOG=info res/dev/run_linux.sh
# 另一个终端：
env -u DISPLAY res/dev/run_linux.sh --connect 100.89.0.1
python3 res/dev/summarize_display_metrics.py /path/to/private.log --skip-windows 15
```

硬件构建仍使用 Cargo.lock 固定 hwcodec revision，在私有 Cargo home 复制
hwcodec checkout 后应用可审阅补丁，其它缓存保留原位置。没有改共享 Cargo
checkout、子模块或锁文件。`hwcodec-system-ffmpeg.patch` 以 pkg-config 动态
链接系统 FFmpeg；`hwcodec-ffmpeg8-api.patch` 兼容移除的 profile 常量和
AVFrame.key_frame。未启用 `RUSTDESK_DEV_HWCODEC` 时仍是原软件构建命令。
本机 libavcodec 62.11.100，libavutil 60.8.100，libavformat 62.3.100。
构建并发 2，脚本仍限制不超过 6。

在启动远控前立即传 `--connect` 曾两次在 GDK Wayland EGL surface 的
`wl_proxy_get_version` 路径崩溃；先启动主窗口、再发送连接请求能够连接。
这是本次发现的启动限制，未用监测改动重构窗口生命周期。

## 动态负载

`res/dev/video_load_probe.py --monitor INDEX --seconds 90` 是临时原生 GTK3 /
GStreamer gltestsrc → gltransformation → gtkglsink 的旋转色条负载，自动退出，
每秒报告源端 sink FPS / drop rate。需 GStreamer gtkglsink、gltestsrc、
gltransformation、fpsdisplaysink 及 Python GI。先现场读取 GDK monitor 列表，
不能假定历史索引；本次 AOC 为 0，内部屏为 1。物理模式由 Mutter
GetCurrentState 确认，不能使用 Xrandr 虚拟像素值代替。

本次 GTK/GStreamer 默认 GL 共享上下文失败，使用以下**仅作用于测试进程**的
环境启动成功：

```bash
env GST_GL_PLATFORM=egl GST_GL_WINDOW=wayland GST_GL_API=gles2 GDK_GL=gles \
  GDK_BACKEND=wayland XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  /usr/bin/python3 video_load_probe.py --monitor 0 --seconds 90
```

早期 Cairo 文字源自身仅约 24 FPS，未作为 60 FPS 验收源；为其补装的
python3-gi-cairo 保留在 OMEN，最终 GPU 源不依赖它。GPU 源的 sink 统计仍不
等于合成器实际呈现确认；本次源也未稳定 60 FPS，因此不能据此推导纯链路
满速上限。管线报错会打印错误并返回非零，不能把进程启动视为测试通过。

## 回退

本机停止开发客户端，备份 bundle 位于私有缓存
`~/.cache/rustdesk-dev/bundle-before-display-metrics/`；软件路径可不设置硬件构建
开关重新构建。停止程序后再更新 bundle，避免覆盖正在映射的动态库。

OMEN 测试采用 `/opt/rustdesk-metrics-verification` 独立 bundle 和 `/run` 临时
服务覆盖，不修改已安装 `/usr/share/rustdesk` 文件。恢复命令：

```bash
sudo rm /run/systemd/system/rustdesk.service.d/90-development-verification.conf
sudo systemctl daemon-reload
sudo systemctl restart rustdesk
systemctl show rustdesk -p ActiveState -p MainPID
```

测试临时窗会自动退出；可按记录的测试 PID 提前终止。保留其他应用和服务。


## 本次实际结果（2026-10-23）

本机 debug bundle / 原生 Wayland / Skia，Tailscale UDP direct 探测
12、12、27 ms；RustDesk 走 Tailscale IP TCP 21118。保留两端其它工作负载，
不当作空载或严格等负载 A/B。外屏物理模式 3840×2160@144 Hz、缩放 1.5，
内屏 2560×1440@60 Hz、缩放 1.25。

客户端接收开始后的 15–75 秒之间日志窗口作为统计区间；受窗口边界影响，
两组客户端覆盖约 60.98 秒。以下耗时均是**各窗口 p95 的均值**，不是合并帧
分布的 p95；已排除启动/切屏窗口。

| 项目 | 30 FPS 基线 | 请求 60 FPS |
| --- | --- | --- |
| 画质 / 编码 | balanced / H.265 / 4:2:0 | custom=33 / H.265 / 4:2:0 |
| 初始 quality ratio | 0.67 | 0.66 |
| 实际尺寸 | 3840×2160 | 3840×2160 |
| 客户端回调数 / 统计秒数 | 887 / 60.983 | 878 / 60.984 |
| 收到 / 提交回调 FPS | 14.55 / 14.55 | 14.40 / 14.40 |
| 客户端队列等待 | 0.99 ms | 0.22 ms |
| 客户端解码与转换 | 9.61 ms | 9.04 ms |
| Flutter 提交回调 | 29.43 ms | 8.63 ms |
| 服务端采集调用 | 33.48 ms | 17.79 ms |
| 服务端像素转换 | 7.70 ms | 8.00 ms |
| 服务端编码 | 16.49 ms | 17.52 ms |
| 服务端发送队列等待 | 0.36 ms | 0.35 ms |
| 服务端 send 路径 | 1.76 ms | 1.71 ms |
| 客户端积压峰值 / 溢出 / 丢弃 / 解码错误 | 1 / 0 / 0 / 0 | 1 / 0 / 0 / 0 |
| 服务端共用队列峰值（dequeue 后观测） | 0 | 0 |

均衡档不会把磁盘保存的 custom-fps 自动带入握手，源码只在 custom 画质中
加载该参数；60 组已改 custom=33，服务器 OptionMessage 日志确认收到
custom_fps=60，后续既有反馈又调整为 51、54 等值。33 对应 ratio=0.66，
尽量接近均衡 0.67，但两档 ABR 下限不同，不能宣称严格同质 A/B。

60 组源端 sink 15–75 秒 59 个窗口均值 **44.15 FPS**，范围 36.58–52.39，
自身未稳住 60；30 组源端全程平均约 42.49。**4K60 未通过验收**，不能把
这里的 14–15 当作链路的固定物理上限，也不能声称已经定位唯一根因。
采集调用含等帧 / 空帧，服务端有比编码次数更多的 capture 调用。后续应
分离 PipeWire 源帧 PTS/间隔、重复帧、map/copy、有效帧和实际 QoS 目标 FPS，
再决定拷贝优化；当前没有证据支持优先重写传输协议。

硬件通路确认：
- OMEN 成功创建 `HWRAM(... name: "hevc_nvenc", width:3840,height:2160)`；
  按 RustDesk 进程的 pmon 编码引擎峰值：30 组 24%，60 组 13%。
- 客户端持续成功出帧且 `decoder=ffmpeg/hevc/AV_HWDEVICE_TYPE_CUDA`。
  固定 hwcodec C++ 代码在 hwaccel 分支要求 hw_frames_ctx 并成功完成
  av_hwframe_transfer_data，才会调用上层成功回调，因此不是仅列举能力。
  本机该次 pmon 解码引擎采样为 0%，未拿它证明吞吐或 60 FPS 能力。
- 内屏单独显示、双屏同时显示、再回 AOC 成功；display 1 实际为 2560×1440，
  同为 CUDA 解码；双屏中两路回调和尺寸同时上报。短时检查内屏最高收到
  38 FPS、外屏约 13–15，未做双屏稳定 60 FPS 或相同图像负载的完整压测。
- 已读取本机 Flutter 渲染帧，确认两屏画面可见及 AOC 旋转色条在远端画面中。
  私有截图和完整日志均未加入 Git / 知识库。
- PipeWire 已协商 BGRx / 3840×2160，maxFramerate 约 144，framerate=0/1；
  不能由此断言源端固定 15 FPS。

运行恢复：OMEN 已移除临时 /run 覆盖并恢复 `/usr/bin/rustdesk --service` 与
`/usr/share/rustdesk/rustdesk --server`，服务 active。临时负载 PID 均已退出。
本机只恢复 image_quality、custom_image_quality、custom-fps 三个测试偏好，
没有覆盖凭据或其他设置；最终回到 AOC，监测关闭，H.265 连接仍出帧，
检查期间没有 display_metrics 日志，GTK 主/子窗口均报告 GdkWaylandDisplay。

## 验证命令与回归面

- `RUSTDESK_DEV_HWCODEC=1 res/dev/build_linux.sh`：通过，Rust cdylib 与 Flutter
  Linux debug bundle 均完成；系统旧弃用/命名等 warning 未作为本次范围清理。
- `cargo test --locked --lib --features flutter,linux-pkg-config,unix-file-copy-paste,hwcodec client::display_metrics::tests`：2 passed；使用构建脚本相同的私有 Cargo home、系统 FFmpeg 开关、pkg-config 路径和 2 jobs 环境。
- `cargo test --locked --lib --features flutter,linux-pkg-config,unix-file-copy-paste client::display_metrics::tests`：2 passed，未启用 hwcodec 的最终软件特性组合也完成编译与测试，2 jobs。
- Python `py_compile`、`bash -n res/dev/build_linux.sh`、`git diff --cached --check`：通过。
- 两个依赖补丁 `patch --dry-run --batch -p1`：通过；调整补丁上下文后重新生成
  隔离依赖，三个受影响源文件与已实测硬件构建使用的文件逐字节相同。

| 修改的既有文件 | 必要的行为边界 |
| --- | --- |
| src/client.rs | 为两种已有视频队列附接收时刻；在既有解码/回调处采样；保留原队列行为。start_video_thread 仅有 io_loop 一个调用者。 |
| src/client/io_loop.rs | 按既有每屏线程持有可选监测器，接收/溢出计数与已有状态定时器输出。 |
| libs/scrap/src/common/codec.rs | 只读返回实际解码实现与设备类型，避免把 H.265 标签误当硬解。 |
| src/server.rs | 注册独立视频监测模块。 |
| src/server/video_service.rs | 采集/转换/编码/入队薄采样钩子；只向本文件两个 handle_one_frame 调用传可选状态。 |
| src/server/connection.rs | 利用既有视频入队 Instant，记录 dequeue 等待、共用队列深度与 send 路径耗时。 |
| src/platform/linux.rs | opt-in 时向 sudo 桌面子进程传递监测/日志开关，解决根服务启用但子进程静默的问题。 |
| res/dev/build_linux.sh | 可选启用 hwcodec 并使用隔离的系统 FFmpeg 兼容依赖；关闭时原软件特性列表不变。 |

没有更改协议、加密、认证、剪贴板、输入、帧参考依赖、已有拥塞控制策略、
共享 trait、Cargo.lock 或子模块。当前采样按单活动远控会话解释；多会话同
屏号需按进程/独立日志区分，尚未实现跨会话相关 ID。Release、合成器实际
呈现 FPS、受控满速源、双屏满载以及 CPU/GPU 零拷贝仍未验收。

本机硬件 bundle 核心库 SHA-256：
`9a14acc2e8db35215987058a8b1da9fdea3dba5685b4ca8f16a74bfdc3a0276a`。
性能原始采样和按窗口筛选结果留在 `~/.cache/rustdesk-dev/` 的
`case-30-client.log`、`case-30-server.log`、`case-60-client.log`、
`case-60-server.log`；这些文件只有性能事件，不包含 VM URL 或认证配置。

相关 NAS 知识库已去重并追加到
`experience/2026-10-23-rustdesk-1-5-0-flutter-3-47-linux-build-and-tailscale-dual-m.md`；
只记录已确认的构建修复与验证边界，不上传原始日志或截图。

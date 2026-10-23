#!/usr/bin/env python3
"""Package an already-built SX Linux Release bundle; never installs or starts services."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--bundle', type=Path,
                        default=ROOT / 'flutter/build/linux/x64/release/bundle')
    parser.add_argument('--flutter-root', type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9][A-Za-z0-9.+~-]*', args.version):
        parser.error('Invalid release version')
    if platform.machine() != 'x86_64':
        parser.error('This packaging path currently targets Linux x86_64 only')
    for item in ('rustdesk', 'lib/librustdesk.so', 'lib/libapp.so',
                 'data/flutter_assets/NOTICES.Z'):
        if not (args.bundle / item).is_file():
            parser.error(f'Missing Release bundle file: {item}')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    name = f'rustdesk-sx-{args.version}-linux-x86_64-ubuntu26.04'
    archive = output / f'{name}.tar.gz'
    deb = output / f'rustdesk-sx_{args.version}_amd64.deb'
    if archive.exists() or deb.exists():
        parser.error('Refusing to overwrite existing release assets')
    if run('git', 'status', '--porcelain', cwd=ROOT):
        parser.error('Commit release sources and restore generated build files before packaging')
    commit = run('git', 'rev-parse', 'HEAD', cwd=ROOT)
    source = f'https://github.com/sixuan-ai/rustdesk-sx/tree/{commit}'
    with tempfile.TemporaryDirectory(prefix='rustdesk-sx-package-') as tmp:
        work = Path(tmp)
        portable = work / name
        portable.mkdir()
        shutil.copy2(args.bundle / 'rustdesk', portable / 'rustdesk')
        for directory in ('lib', 'data'):
            shutil.copytree(args.bundle / directory, portable / directory, symlinks=True)
        for link in portable.rglob('*'):
            if link.is_symlink() and not link.resolve().is_relative_to(portable):
                raise RuntimeError(f'Bundle symlink points outside payload: {link.name}')
        licenses = portable / 'licenses'
        licenses.mkdir()
        for item in ('LICENCE', 'FORK.md'):
            shutil.copy2(ROOT / item, licenses / item)
        shutil.copytree(ROOT / 'flutter/assets/fonts/misans', licenses / 'MiSans',
                        ignore=shutil.ignore_patterns('*.ttf'))
        shutil.copy2(args.flutter_root / 'LICENSE', licenses / 'Flutter-LICENSE')
        shutil.copy2(args.flutter_root / 'bin/cache/artifacts/engine/linux-x64-release/LICENSE.flutter_gtk.md',
                     licenses / 'Flutter-engine-LICENSE.md')
        launcher = portable / 'run.sh'
        launcher.write_text('''#!/bin/sh
set -eu
app_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export LD_LIBRARY_PATH="$app_dir/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = wayland ]; then
    export GDK_BACKEND="${GDK_BACKEND:-wayland}"
    case "${XDG_CURRENT_DESKTOP:-}" in
        *GNOME*) export RUSTDESK_WAYLAND_CLIPBOARD="${RUSTDESK_WAYLAND_CLIPBOARD:-1}" ;;
    esac
fi
export RUSTDESK_DEV_RENDERER="${RUSTDESK_DEV_RENDERER:-skia}"
exec "$app_dir/rustdesk" "$@"
''')
        launcher.chmod(0o755)
        # Ask Debian's symbol metadata for every shipped ELF, including Flutter plugins.
        # Bundled Flutter/Rust libraries have no distro shlibs entry; their own dependencies
        # are still inspected because each library is passed explicitly as an ELF input.
        (work / 'debian').mkdir()
        (work / 'debian/control').write_text('Source: rustdesk-sx\nSection: net\nPriority: optional\nMaintainer: Max Stark <sixuan-ai@users.noreply.github.com>\n\nPackage: rustdesk-sx\nArchitecture: amd64\nDescription: RustDesk SX desktop client\n')
        elfs = [portable / 'rustdesk'] + sorted((portable / 'lib').glob('*.so'))
        env = os.environ.copy()
        env['LD_LIBRARY_PATH'] = str(portable / 'lib')
        for elf in elfs:
            links = run('ldd', str(elf), env=env)
            if 'not found' in links:
                raise RuntimeError(f'Unresolved runtime dependency in {elf.name}')
        dep_output = run('dpkg-shlibdeps', '-O', '--ignore-missing-info',
                         '-l' + str(portable / 'lib'),
                         *['-e' + str(elf) for elf in elfs], cwd=work)
        depends = next(line.split('=', 1)[1] for line in dep_output.splitlines()
                       if line.startswith('shlibs:Depends='))
        depends += ', gstreamer1.0-pipewire'
        manifest = {
            'project': 'RustDesk · 思玄二次开发版', 'maintainer': 'Max Stark / sixuan-ai',
            'release_version': args.version, 'upstream_version': '1.5.0',
            'source_commit': commit, 'source_url': source,
            'target': 'Linux x86_64 / Ubuntu 26.04',
            'build_host_os': platform.freedesktop_os_release().get('PRETTY_NAME'),
            'rustc': run('rustc', '--version'),
            'submodules': run('git', 'submodule', 'status', '--recursive', cwd=ROOT).splitlines(),
            'build_features': ['flutter', 'linux-pkg-config', 'unix-file-copy-paste', 'hwcodec'],
            'runtime_dependencies': depends,
            'verification': 'Release build, ELF dependency resolution and --version smoke check; remote session not retested',
        }
        (portable / 'BUILD-INFO.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
        (portable / 'README.zh-CN.txt').write_text(f'''RustDesk · 思玄二次开发版 {args.version}
维护：转瞬之澜（思玄） / Max Stark（sixuan-ai）
源码：{source}

这是 Linux x86_64 / Ubuntu 26.04 开发预览包，使用系统 FFmpeg 8。
Ubuntu 24.04、Windows、macOS 和其他架构未验证，不属于此包的兼容范围。
依赖：{depends}

便携版：解压后执行 ./run.sh；仅运行客户端可执行 ./run.sh --no-server。
Debian 包：sudo apt install ./rustdesk-sx_{args.version}_amd64.deb
桌面入口：RustDesk · 思玄二次开发版；终端入口：rustdesk-sx。
.deb 不安装、替换或启停系统 RustDesk 服务，可与已有程序使用不同安装路径。
本版本仍使用 RustDesk 的用户配置位置，可能共享已有账号/设备设置。
卸载：sudo apt remove rustdesk-sx；便携版删除解压目录即可。

Wayland 被控端仍需通过系统共享选择器授权。持续 4K60 尚未达标。
本包使用系统 GTK；未打包开发机的 GTK 3.24.52 AT-SPI 私有修复，
系统存在该问题时仍可能受影响，详见源码中的 res/dev/build_gtk3_a11y_fix.sh。
界面的基础版本号仍为 1.5.0，衍生发布版本和精确源码提交见 BUILD-INFO.json。
许可：AGPL-3.0；MiSans、Flutter 等各保留原许可，见 licenses/ 与 data/flutter_assets/NOTICES.Z。
完整构建：按源码开发文档获取子模块和依赖，然后执行：
RUSTDESK_DEV_HWCODEC=1 RUSTDESK_DEV_BUILD_MODE=release RUSTDESK_BUILD_JOBS=2 res/dev/build_linux.sh
''')
        smoke = run(str(launcher), '--version', env=env, timeout=30)
        if '1.5.0' not in smoke:
            raise RuntimeError('Unexpected Release --version result')
        deb_root = work / 'deb'
        payload = deb_root / 'usr/lib/rustdesk-sx'
        shutil.copytree(portable, payload, symlinks=True)
        binaries = deb_root / 'usr/bin'
        binaries.mkdir(parents=True)
        (binaries / 'rustdesk-sx').write_text('#!/bin/sh\nexec /usr/lib/rustdesk-sx/run.sh "$@"\n')
        (binaries / 'rustdesk-sx').chmod(0o755)
        applications = deb_root / 'usr/share/applications'
        applications.mkdir(parents=True)
        (applications / 'rustdesk-sx.desktop').write_text('[Desktop Entry]\nType=Application\nName=RustDesk SX\nName[zh_CN]=RustDesk · 思玄二次开发版\nExec=rustdesk-sx\nIcon=rustdesk-sx\nTerminal=false\nCategories=Network;RemoteAccess;\n')
        icons = deb_root / 'usr/share/icons/hicolor/256x256/apps'
        icons.mkdir(parents=True)
        shutil.copy2(ROOT / 'res/128x128@2x.png', icons / 'rustdesk-sx.png')
        control = deb_root / 'DEBIAN'
        control.mkdir()
        size = sum(p.stat().st_size for p in deb_root.rglob('*') if p.is_file()) // 1024
        (control / 'control').write_text(f'Package: rustdesk-sx\nVersion: {args.version}\nArchitecture: amd64\nMaintainer: Max Stark <sixuan-ai@users.noreply.github.com>\nSection: net\nPriority: optional\nHomepage: https://github.com/sixuan-ai/rustdesk-sx\nInstalled-Size: {size}\nDepends: {depends}\nDescription: RustDesk SX desktop client for Ubuntu 26.04\n Maintained by sixuan-ai. Does not install or modify system services.\n')
        subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(deb_root), str(deb)], check=True)
        with tarfile.open(archive, 'w:gz') as tar:
            tar.add(portable, arcname=name)
        (output / 'BUILD-INFO.json').write_text((portable / 'BUILD-INFO.json').read_text())
        (output / 'README.zh-CN.txt').write_text((portable / 'README.zh-CN.txt').read_text())
    assets = [archive, deb, output / 'BUILD-INFO.json', output / 'README.zh-CN.txt']
    (output / 'SHA256SUMS').write_text(''.join(
        f'{hashlib.file_digest(p.open("rb"), "sha256").hexdigest()}  {p.name}\n' for p in assets))
    print(f'Packaged {args.version} at {commit}: {archive.name}, {deb.name}')


if __name__ == '__main__':
    main()

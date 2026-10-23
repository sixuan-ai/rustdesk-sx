#!/usr/bin/env python3
"""Prepare an isolated patched git checkout; never alter the shared Cargo cache."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tomllib

repo = Path(__file__).resolve().parents[2]
lock = tomllib.loads((repo / 'Cargo.lock').read_text())
source = next(p['source'] for p in lock['package'] if p['name'] == 'hwcodec')
commit = source.split('#')[1]
original = Path(os.environ.get('CARGO_HOME', Path.home() / '.cargo')).resolve()
patch = repo / 'res/dev/patches/hwcodec-system-ffmpeg.patch'
identity = hashlib.sha256(patch.read_bytes() + commit.encode()).hexdigest()[:12]
patches = [patch, repo / 'res/dev/patches/hwcodec-ffmpeg8-api.patch']
patch_identity = hashlib.sha256(b''.join(p.read_bytes() for p in patches)).hexdigest()
dev = Path(os.environ.get('RUSTDESK_DEV_ROOT', Path.home() / '.local/share/rustdesk-dev'))
target = dev / ('cargo-hwcodec-' + identity)
# Copy only hwcodec. Other immutable checkout caches, downloads and credentials
# retain Cargo's usual locations, without copying or printing credentials.
for name in ('registry', 'bin', 'config.toml', 'credentials.toml'):
    origin = original / name
    dest = target / name
    target.mkdir(parents=True, exist_ok=True)
    if origin.exists() and not dest.exists():
        dest.symlink_to(origin, target_is_directory=origin.is_dir())
(target / 'git/checkouts').mkdir(parents=True, exist_ok=True)
if not (target / 'git/db').exists():
    (target / 'git/db').symlink_to(original / 'git/db', target_is_directory=True)
found = False
for origin in (original / 'git/checkouts').iterdir():
    dest = target / 'git/checkouts' / origin.name
    if not origin.name.startswith('hwcodec-'):
        if not dest.exists():
            dest.symlink_to(origin, target_is_directory=True)
        continue
    for checkout in origin.iterdir():
        if not checkout.is_dir() or not commit.startswith(checkout.name):
            continue
        found = True
        copied = dest / checkout.name
        marker = copied / '.rustdesk-system-ffmpeg'
        if not marker.exists() or marker.read_text().strip() != patch_identity:
            actual = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
            if actual != commit:
                raise SystemExit('hwcodec cache does not match Cargo.lock')
            if copied.exists():
                shutil.rmtree(copied)
            shutil.copytree(checkout, copied, symlinks=True)
            for patch_file in patches:
                subprocess.run(['patch', '--batch', '-p1', '-i', str(patch_file)], cwd=copied, check=True, stdout=subprocess.DEVNULL)
            marker.write_text(patch_identity + '\n')
if not found:
    raise SystemExit('Run cargo fetch --locked before preparing hwcodec')
print(target)

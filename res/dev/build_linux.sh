#!/usr/bin/env bash
# Build a development bundle with the system's current stable Flutter/Rust.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
dev_root="${RUSTDESK_DEV_ROOT:-$HOME/.local/share/rustdesk-dev}"
jobs="${RUSTDESK_BUILD_JOBS:-2}"
[[ "$jobs" =~ ^[1-6]$ ]] || { echo 'RUSTDESK_BUILD_JOBS must be 1..6' >&2; exit 1; }
mkdir -p "$dev_root/pkgconfig" "$dev_root/build-tools"

# Ubuntu ships libyuv headers/libraries without a .pc file. Describe the
# installed package locally rather than changing system files or build.rs.
if ! pkg-config --exists libyuv; then
  multiarch="$(gcc -print-multiarch)"
  version="$(awk '/^#define LIBYUV_VERSION / {print $3}' /usr/include/libyuv/version.h)"
  cat > "$dev_root/pkgconfig/libyuv.pc" <<EOF
prefix=/usr
libdir=/usr/lib/$multiarch
includedir=/usr/include
Name: libyuv
Description: System libyuv development package
Version: $version
Libs: -L\${libdir} -lyuv
Cflags: -I\${includedir}
EOF
fi
export PKG_CONFIG_PATH="$dev_root/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CARGO_BUILD_JOBS="$jobs" CARGO_PROFILE_DEV_DEBUG=0
export CMAKE_BUILD_PARALLEL_LEVEL="$jobs" CMAKE_POLICY_VERSION_MINIMUM=3.5
# The pinned libwebm parser uses uint32_t/uint64_t without including cstdint;
# GCC 15 no longer supplies those names through its other standard headers.
export CXXFLAGS="${CXXFLAGS:-} -include cstdint"

# Flutter invokes Ninja directly, so CMAKE_BUILD_PARALLEL_LEVEL alone does not
# limit its compiler processes. Keep the wrapper local to this build command.
cat > "$dev_root/build-tools/ninja" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/ninja -j "${RUSTDESK_BUILD_JOBS:-2}" "$@"
EOF
chmod +x "$dev_root/build-tools/ninja"
ln -sf "$PWD/res/dev/git_shallow_fetch.py" "$dev_root/build-tools/git"
export RUSTDESK_BUILD_JOBS="$jobs"
export PATH="$dev_root/build-tools:$dev_root/tools/bin:$PATH"

flutter --version
rustc --version
pkg-config --exists gtk+-3.0 opus vpx aom libyuv gstreamer-1.0
(cd flutter && flutter pub get)
if [[ "${1:-}" == --generate-bridge ]]; then
  # FRB 1.x matches this stable source's ABI; this is not a Rust SDK pin.
  [[ "$(flutter_rust_bridge_codegen --version)" == *1.80.1* ]] || exit 1
  RUST_LOG=info flutter_rust_bridge_codegen \
    --rust-input ./src/flutter_ffi.rs \
    --dart-output ./flutter/lib/generated_bridge.dart --skip-add-mod-to-lib --no-build-runner \
    --llvm-path "${LIBCLANG_PATH:-/usr/lib/llvm-$(clang -dumpversion | cut -d. -f1)/lib}"
  (cd flutter && dart run build_runner build --delete-conflicting-outputs \
    --build-filter lib/generated_bridge.freezed.dart)
fi
test -s src/bridge_generated.rs
test -s flutter/lib/generated_bridge.dart
# Match build.py: FRB 1.x expects DartPort's post callback as Uint8.
sed -i 's/ffi.NativeFunction<ffi.Bool Function(DartPort/ffi.NativeFunction<ffi.Uint8 Function(DartPort/g' \
  flutter/lib/generated_bridge.dart
# The Flutter runner loads the cdylib; avoid also linking unused static/rlib
# outputs declared for other platforms in Cargo.toml.
cargo rustc --locked --lib --features flutter,linux-pkg-config,unix-file-copy-paste \
  --crate-type cdylib
(cd flutter && flutter build linux --debug --no-pub)
test -x flutter/build/linux/x64/debug/bundle/rustdesk
echo "Bundle: $PWD/flutter/build/linux/x64/debug/bundle/rustdesk"

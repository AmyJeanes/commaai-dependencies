#!/usr/bin/env bash
# Windows only: PyPI ships libdatachannel-py (teleoprtc's WebRTC binding) wheels for Linux and macOS but not
# Windows, and there is no sdist. Build it from the pinned tag with the MSYS2 clang64 toolchain into dist/.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$DIR"

VERSION="2026.1.0.dev2"  # keep in step with openpilot's uv.lock
SRC="$DIR/libdatachannel-py-src"

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) echo "libdatachannel-py: PyPI has wheels for this platform, nothing to build"; exit 0 ;; esac

if [ ! -d "$SRC/.git" ]; then
  rm -rf "$SRC"
  git clone --depth 1 --branch "$VERSION" https://github.com/shiguredo/libdatachannel-py "$SRC"
fi
git -C "$SRC" fetch --depth 1 origin "refs/tags/$VERSION"
git -C "$SRC" checkout --force FETCH_HEAD
# upstream's CMake assumes MSVC on Windows (.lib names, /bigobj, static CRT); MinGW clang wants the POSIX branches
git -C "$SRC" apply --ignore-whitespace "$DIR/mingw.patch"

export CMAKE_GENERATOR=Ninja CC=clang CXX=clang++
# libsrtp builds with -Werror and prints winsock's unsigned long ntohl() with %x (-Wno-format would be overridden by its -Wall)
export CFLAGS="-Wno-error=format"
export CMAKE_BUILD_PARALLEL_LEVEL="$(nproc 2>/dev/null || echo 4)"
# _deps (MbedTLS and libdatachannel, fetched and built by the package's own CMake) is kept between builds
uv build --wheel --python 3.12 --out-dir "$DIR/../dist" "$SRC"

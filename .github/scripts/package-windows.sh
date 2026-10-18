#!/bin/sh
# Assemble a portable Windows build. Run from the repository root in an MSYS2
# UCRT64 shell after ./configure && make.
#
# The layout follows installer/DVDStyler.iss: executables and DLLs in bin\,
# data directories one level up, because the application looks for its data
# next to the executable and then in the parent directory.
#
# Usage: package-windows.sh [output-dir]
# Prints the path of the created zip on the last line of stdout.
set -eu

: "${MINGW_PREFIX:?run this in an MSYS2 MinGW shell}"
OUT=$(cd "${1:-.}" && pwd)
VERSION=$(sed -n 's/^AC_INIT(\[DVDStyler\],\[\([^]]*\)\].*/\1/p' configure.ac)
[ -n "$VERSION" ] || { echo "cannot read version from configure.ac" >&2; exit 1; }
NAME=DVDStyler-$VERSION-win64-portable

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
STAGE=$WORK/install
ROOT=$WORK/$NAME

make install DESTDIR="$STAGE" >/dev/null
PREFIX=$(sed -n 's/^prefix = //p' Makefile)

mkdir -p "$ROOT/bin" "$ROOT/etc"
cp "$STAGE$PREFIX/bin/dvdstyler.exe" "$MINGW_PREFIX/bin/ffmpeg.exe" "$ROOT/bin/"
cp -R "$STAGE$PREFIX/share/dvdstyler/." "$ROOT/"
cp -R "$STAGE$PREFIX/share/locale" "$ROOT/locale"
# fontconfig locates its configuration relative to its DLL (..\etc\fonts).
cp -R "$MINGW_PREFIX/etc/fonts" "$ROOT/etc/"
cp COPYING ChangeLog README "$ROOT/"
cp installer/README-windows-portable.txt "$ROOT/README-Windows.txt"

# Bundle every DLL the executables load from the MinGW prefix (ldd recurses).
ldd "$ROOT"/bin/*.exe | sed -n "s|.* => \($MINGW_PREFIX/bin/[^ ]*\.dll\) .*|\1|Ip" | sort -u |
	while read -r dll; do cp "$dll" "$ROOT/bin/"; done

# Every dependency must now resolve inside the package or to Windows itself.
# Run with a PATH that excludes MSYS2 so nothing resolves from the build tree.
DEPS=$(PATH=/c/Windows/System32:/c/Windows "$MINGW_PREFIX/bin/ntldd.exe" -R "$ROOT"/bin/*.exe)
# API-set names (api-ms-win-*, ext-ms-*) are resolved by the loader, not files.
if echo "$DEPS" | grep -Eiv '^[[:space:]]*(api|ext)-ms-' | grep -Ei 'not found|msys64' >&2; then
	echo "unresolved or non-bundled DLLs (see above)" >&2
	exit 1
fi

(cd "$WORK" && zip -qr -9 "$OUT/$NAME.zip" "$NAME")
echo "$OUT/$NAME.zip"

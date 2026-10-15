#!/bin/sh
# Build a self-contained source tarball from the committed HEAD.
#
# `make dist` cannot be used: locale/Makefile.in is hand-written and has no
# distdir rule. This mirrors build_release.sh (pre-run autogen, pre-generate
# the bison/flex parser, drop the PDFs) but packages this checkout instead of
# cloning the old SourceForge repository.
#
# Usage: make-source-tarball.sh [output-dir]
# Prints the path of the created tarball on the last line of stdout.
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$(cd "${1:-.}" && pwd)
VERSION=$(sed -n 's/^AC_INIT(\[DVDStyler\],\[\([^]]*\)\].*/\1/p' "$ROOT/configure.ac")
[ -n "$VERSION" ] || { echo "cannot read version from configure.ac" >&2; exit 1; }
MODULE=DVDStyler-$VERSION

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git -C "$ROOT" archive --format=tar --prefix="$MODULE/" HEAD | tar -x -C "$WORK"
SRC=$WORK/$MODULE
rm -rf "$SRC/.github"
rm -f "$SRC"/docs/*.pdf

(cd "$SRC" && ./autogen.sh && rm -rf autom4te.cache)
(cd "$SRC/src" && bison -y -o dvdvmy.c -d -p dvdvm dvdvmy.y && flex -s -B -Cem -odvdvml.c -Pdvdvm dvdvml.l)

tar -C "$WORK" -cjf "$OUT/$MODULE.tar.bz2" "$MODULE"
echo "$OUT/$MODULE.tar.bz2"

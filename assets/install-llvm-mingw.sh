#!/usr/bin/env bash

set -ex
set -o pipefail

VERSION=20220323
CROSS_ROOT=/opt/llvm-windows
CROSS_TRIPLE=x86_64-w64-mingw32

DOWNLOAD_URL=https://github.com/mstorsjo/llvm-mingw/releases/download/${VERSION}/llvm-mingw-${VERSION}-msvcrt-ubuntu-18.04-x86_64.tar.xz

mkdir -p ${CROSS_ROOT} && wget -qO- "${DOWNLOAD_URL}" | tar Jxvf - --strip 1 -C ${CROSS_ROOT}/ > /dev/null

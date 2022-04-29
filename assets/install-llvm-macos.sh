#!/usr/bin/env bash

set -ex
set -o pipefail

# https://www.dropbox.com/s/dk2e7tmd2u14my3/llvm-osxcross-20220425-darwin20.4_11.3.tar.xz?dl=1
# https://www.dropbox.com/s/w0pc5oatddrxzj3/MacOSX11.3.sdk.tar.xz?dl=1

CROSS_ROOT=/opt/llvm-macos
#LLVM_VERSION=14.0.0 INSTALL_DIR="${CROSS_ROOT}" /buildscripts/install-llvm-linux.sh
#cp -lr /opt/llvm-linux $CROSS_ROOT

# Build arguments

OSXCROSS_REPO="tpoechtrager/osxcross"
OSXCROSS_REVISION="610542781e0eabc6968b0c0719bbc8d25c992025"
DARWIN_OSX_VERSION_MIN="10.9"
DARWIN_SDK_VERSION="11.3"
DARWIN_SDK_URL="https://www.dropbox.com/s/w0pc5oatddrxzj3/MacOSX${DARWIN_SDK_VERSION}.sdk.tar.xz"
CROSS_ROOT=/opt/llvm-macos

mkdir -p "/tmp/osxcross"
cd "/tmp/osxcross"
curl -sLo osxcross.tar.gz "https://codeload.github.com/${OSXCROSS_REPO}/tar.gz/${OSXCROSS_REVISION}"
tar --strip=1 -xzf osxcross.tar.gz
rm -f osxcross.tar.gz
curl -sLo tarballs/MacOSX${DARWIN_SDK_VERSION}.sdk.tar.xz "${DARWIN_SDK_URL}"
TARGET_DIR="${CROSS_ROOT}" UNATTENDED=1 PATH=${CROSS_ROOT}/bin:$PATH LDFLAGS="-L"${CROSS_ROOT}/lib" -Wl,-rpath,'\$\${ORIGIN}/../lib'" ./build.sh
mv tools "${CROSS_ROOT}/"
ln -sf ../tools/osxcross-macports ${CROSS_ROOT}/bin/omp
ln -sf ../tools/osxcross-macports ${CROSS_ROOT}/bin/osxcross-macports
ln -sf ../tools/osxcross-macports ${CROSS_ROOT}/bin/osxcross-mp
sed -i -e "s%exec cmake%exec /usr/bin/cmake%" ${CROSS_ROOT}/bin/osxcross-cmake
rm -rf /tmp/osxcross
rm -rf "${CROSS_ROOT}/SDK/MacOSX${DARWIN_SDK_VERSION}.sdk/usr/share/man"

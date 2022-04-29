FROM debian:bullseye-slim
MAINTAINER Sidaf <sion.dafydd@gmail.com> (https://github.com/sidaf)

# Setup base debian system

# temporarily disable dpkg fsync to make building faster.
RUN if [ ! -e /etc/dpkg/dpkg.cfg.d/docker-apt-speedup ]; then         \
      echo force-unsafe-io > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup; \
    fi

# keep system compact, don't save downloaded packages
RUN if [ ! -e /etc/apt/apt.conf.d/docker-clean ]; then         \
      echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
    > /etc/apt/apt.conf.d/docker-clean && \
      echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
    >> /etc/apt/apt.conf.d/docker-clean && \
      echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' \
    >> /etc/apt/apt.conf.d/docker-clean; \
    fi

# prevent initramfs updates from trying to run grub and lilo.
ENV INITRD no

# replace the 'ischroot' tool to make it always return true.
# prevent initscripts updates from breaking /dev/shm.
RUN dpkg-divert --local --rename --add /usr/bin/ischroot && \
    ln -sf /bin/true /usr/bin/ischroot

RUN set -x; \
 DEBIAN_FRONTEND=noninteractive                        \
 && apt-get update                                     \
 && apt-get dist-upgrade --yes                         \
 && apt-get install --yes -q --no-install-recommends   \
        autoconf                                       \
        autogen                                        \
        automake                                       \
        autotools-dev                                  \
        bc                                             \
        bison                                          \
        build-essential                                \
        bzip2                                          \
        ca-certificates                                \
        ccache                                         \
        curl                                           \
        dirmngr                                        \
        distcc                                         \
        file                                           \
        flex                                           \
        gettext                                        \
        gzip                                           \
        gnupg                                          \
        osslsigncode                                   \
        libc-dev                                       \
        libcurl4-gnutls-dev                            \
        libexpat1-dev                                  \
        libssl-dev                                     \
        libtool                                        \
        libxml2-dev                                    \
        lzma-dev                                       \
        make                                           \
        pkg-config                                     \
        pax                                            \
        python-is-python3                              \
        python3-dev                                    \
        python3-pip                                    \
        patch                                          \
        rsync                                          \
        ssh                                            \
        software-properties-common                     \
        vim                                            \
        wget                                           \
        xz-utils                                       \
        zip                                            \
        zlib1g-dev                                     \
 && apt-get clean autoclean --yes                      \
 && apt-get autoremove --yes                           \
 && rm -rf /var/lib/{apt,dpkg,cache,log}

# Setup cross-compile environments

WORKDIR /usr/src

# Install gosu

COPY assets/install-gosu-binary.sh assets/install-gosu-binary-wrapper.sh /buildscripts/
RUN \
  set -x && \
  /buildscripts/install-gosu-binary.sh && \
  /buildscripts/install-gosu-binary-wrapper.sh && \
  rm -rf /buildscripts

# Install git

ARG GIT_VERSION=2.36.0
COPY assets/build-and-install-git.sh /buildscripts/
RUN /buildscripts/build-and-install-git.sh && \
  rm -rf /buildscripts

# Install cmake

ARG CMAKE_VERSION=3.23.1
COPY assets/build-and-install-cmake.sh /buildscripts/
RUN /buildscripts/build-and-install-cmake.sh && \
  rm -rf /buildscripts
COPY assets/cmake.sh /usr/local/bin/cmake
COPY assets/ccmake.sh /usr/local/bin/ccmake

# Install custom bash prompt

COPY assets/install-liquidprompt-binary.sh /buildscripts/
RUN /buildscripts/install-liquidprompt-binary.sh && \
  rm -rf /buildscripts

# Install ninja

COPY assets/install-python-packages.sh assets/build-and-install-ninja.sh /buildscripts/
RUN PYTHON=$([ -e /opt/python/cp38-cp38/bin/python ] && echo "/opt/python/cp38-cp38/bin/python" || echo "python3") && \
  /buildscripts/install-python-packages.sh -python ${PYTHON} && \
  /buildscripts/build-and-install-ninja.sh -python ${PYTHON} && \
  rm -rf /buildscripts

# Install Linux cross-tools

COPY assets/install-llvm-linux.sh /buildscripts/
RUN LLVM_VERSION=14.0.0 INSTALL_DIR="/opt/llvm-linux/" /buildscripts/install-llvm-linux.sh && \
  cp -lr /opt/llvm-linux /opt/llvm-macos && \
  rm -rf /buildscripts

# Install Windows cross-tools

COPY assets/install-llvm-mingw.sh /buildscripts/
RUN /buildscripts/install-llvm-mingw.sh && \
  rm -rf /buildscripts

# Install macOS cross-tools

COPY assets/install-llvm-macos.sh assets/install-llvm-linux.sh /buildscripts/
RUN /buildscripts/install-llvm-macos.sh && \
  rm -rf /buildscripts

# Create symlinks for triples

ENV LINUX_TRIPLES=x86_64-linux-gnu,i686-linux-gnu
ENV DARWIN_TRIPLES=x86_64h-apple-darwin20.4,x86_64-apple-darwin20.4
ENV WINDOWS_TRIPLES=i686-w64-mingw32,x86_64-w64-mingw32
ENV CROSS_TRIPLE=x86_64-linux-gnu

COPY assets/toolchain.cmake /crossbuild/
ENV CMAKE_TOOLCHAIN_FILE /crossbuild/toolchain.cmake

COPY assets/linux-wrapper assets/linux-emulator /opt/llvm-linux/bin/
COPY assets/windows-wrapper assets/windows-emulator /opt/llvm-windows/bin/
COPY assets/macos-wrapper assets/macos-emulator /opt/llvm-macos/bin/

RUN \
    mkdir -p /usr/x86_64-linux-gnu;                                                                          \
    for triple in $(echo ${LINUX_TRIPLES} | tr "," " "); do                                                  \
      mkdir -p /usr/$triple/bin &&                                                                             \
      for bin in clang clang++ gcc g++ cc c99 c11 c++ as; do                                                 \
          ln -sf /opt/llvm-linux/bin/linux-wrapper /opt/llvm-linux/bin/$triple-$bin;                         \
      done &&                                                                                                  \
      for bin in addr2line ar ranlib nm objcopy objdump readelf strings strip windres dlltool; do            \
          ln -sf /opt/llvm-linux/bin/llvm-$bin /opt/llvm-linux/bin/$triple-$bin || true;                     \
      done &&                                                                                                  \
      ln -sf /opt/llvm-linux/bin/clang-cpp /usr/$triple/bin/cpp &&                                             \
      ln -sf /opt/llvm-linux/bin/ld.lld /opt/llvm-linux/bin/$triple-ld &&                                      \
      for bin in /opt/llvm-linux/bin/$triple-*; do                                                           \
        ln -sf $bin /usr/$triple/bin/$(basename $bin | sed "s/$triple-//");                                  \
      done &&                                                                                                  \
      ln -s /usr/$triple /usr/x86_64-linux-gnu/$triple &&                                                      \
      ln -sf /opt/llvm-linux/bin/linux-emulator /usr/$triple/bin/$triple-emulator;                           \
    done &&                                                                                                  \
    for triple in $(echo ${WINDOWS_TRIPLES} | tr "," " "); do                                                \
      mkdir -p /usr/$triple/bin &&                                                                             \
      for bin in /opt/llvm-windows/bin/$triple-*; do                                                         \
        ln -f /opt/llvm-windows/bin/windows-wrapper /usr/$triple/bin/$(basename $bin | sed "s/$triple-//");  \
      done &&                                                                                                  \
      ln -s /usr/$triple /usr/x86_64-linux-gnu/$triple &&                                                      \
      ln -sf /opt/llvm-windows/bin/clang-cpp /usr/$triple/bin/cpp &&                                           \
      ln -sf /opt/llvm-windows/bin/windows-emulator /usr/$triple/bin/$triple-emulator;                       \
    done &&                                                                                                  \
    for triple in $(echo ${DARWIN_TRIPLES} | tr "," " "); do                                                 \  
      mkdir -p /usr/$triple/bin;                                                                             \
      for bin in /opt/llvm-macos/bin/$triple-*; do                                                           \
        ln -f /opt/llvm-macos/bin/macos-wrapper /usr/$triple/bin/$(basename $bin | sed "s/$triple-//");      \
      done &&                                                                                                  \
      ln -sf /opt/llvm-macos/SDK/MacOSX11.3.sdk/usr /usr/x86_64-linux-gnu/$triple;                           \
      for bin in gcc c99 c11; do                                                                             \
        ln -sf /usr/$triple/bin/clang /usr/$triple/bin/$bin;                                                 \
      done;                                                                                                  \
      ln -sf /usr/$triple/bin/c++ /usr/$triple/bin/g++ &&                                                      \
      ln -sf /opt/llvm-macos/bin/clang-cpp /usr/$triple/bin/cpp &&                                             \
      ln -sf /opt/llvm-macos/bin/macos-emulator /usr/$triple/bin/$triple-emulator;                           \
    done

# Setup image entry scripts

COPY assets/entrypoint.sh assets/crossbuild.sh /crossbuild/

RUN echo "root:root" | chpasswd
WORKDIR /work
ENTRYPOINT ["/crossbuild/entrypoint.sh"]

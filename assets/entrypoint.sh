#!/usr/bin/env bash

# This is the entrypoint script for the dockerfile. Executed in the
# container at runtime.

if [[ $# == 0 ]]; then
    # Presumably the image has been run directly, so help the user get
    # started by outputting the dockcross script
    if [[ -n $DEFAULT_CROSSBUILD_IMAGE ]]; then
        head -n 2 /crossbuild/crossbuild.sh
        echo "DEFAULT_CROSSBUILD_IMAGE=$DEFAULT_CROSSBUILD_IMAGE"
        tail -n +4 /crossbuild/crossbuild.sh |
          sed -e "s@sidaf\/crossbuild@${DEFAULT_CROSSBUILD_IMAGE}@g"
    else
        cat /crossbuild/crossbuild.sh
    fi
    exit 0
fi

# alternative names mapping
case "${CROSS_TRIPLE}" in
    x86_64-pc-linux-gnu|x86_64-linux-gnu|linux|x86_64|amd64)
	CROSS_TRIPLE="x86_64-linux-gnu" ;;
    i686-pc-linux-gnu|i686-linux-gnu|i686|linux32)
	CROSS_TRIPLE="i686-linux-gnu" ;;
    x86_64-apple-darwin|osx|osx64|darwin|darwin64|macos)
	CROSS_TRIPLE="x86_64-apple-darwin20.4" ;;
    x86_64h-apple-darwin|osx64h|darwin64h|x86_64h|macos64h)
	CROSS_TRIPLE="x86_64h-apple-darwin20.4" ;;
    x86_64-w64-mingw32|windows|win64)
	CROSS_TRIPLE="x86_64-w64-mingw32" ;;
    i686-w64-mingw32|win32)
	CROSS_TRIPLE="i686-w64-mingw32" ;;
    *)
	echo "${CROSS_TRIPLE} is not supported." && exit 1 ;;
esac

export CROSS_MACHINE="${CROSS_TRIPLE%%-*}"
export CROSS_OPERATING_SYSTEM="${CROSS_TRIPLE##*-}"

# store original PATH and LD_LIBRARY_PATH
if [ -z ${PATH_ORIGIN+x} ]; then export PATH_ORIGIN=${PATH}; fi
if [ -z ${LD_LIBRARY_PATH_ORIGIN+x} ]; then export LD_LIBRARY_PATH_ORIGIN=${LD_LIBRARY_PATH}; fi

# configure environment
if [ -n "${CROSS_TRIPLE}" ]; then

    if [[ "${CROSS_OPERATING_SYSTEM}" == "darwin"* ]]; then
        export CROSS_ROOT="/opt/llvm-macos"
        export CROSS_OPERATING_SYSTEM="Darwin"
    elif [ "${CROSS_OPERATING_SYSTEM}" = "mingw32" ]; then
        export CROSS_ROOT="/opt/llvm-windows"
        export CROSS_OPERATING_SYSTEM="Windows"
    else
        export CROSS_ROOT="/opt/llvm-linux"
        export CROSS_OPERATING_SYSTEM="Linux"
    fi

    export PATH="/usr/${CROSS_TRIPLE}/bin:${PATH_ORIGIN}"
    #export LD_LIBRARY_PATH="/usr/x86_64-linux-gnu/${CROSS_TRIPLE}/lib:${LD_LIBRARY_PATH_ORIGIN}"
    export LD_LIBRARY_PATH="${CROSS_ROOT}/lib:${LD_LIBRARY_PATH_ORIGIN}"

    export AS=/usr/${CROSS_TRIPLE}/bin/as
    export AR=/usr/${CROSS_TRIPLE}/bin/ar
    export CC=/usr/${CROSS_TRIPLE}/bin/clang
    export CPP=/usr/${CROSS_TRIPLE}/bin/cpp
    export CXX=/usr/${CROSS_TRIPLE}/bin/clang++
    export LD=/usr/${CROSS_TRIPLE}/bin/lld
    export OBJCOPY=/usr/${CROSS_TRIPLE}/bin/objcopy
    export RANLIB=/usr/${CROSS_TRIPLE}/bin/ranlib
    export STRIP=/usr/${CROSS_TRIPLE}/bin/strip
fi

# If we are running docker natively, we want to create a user in the container
# with the same UID and GID as the user on the host machine, so that any files
# created are owned by that user. Without this they are all owned by root.
# The dockcross script sets the BUILDER_UID and BUILDER_GID vars.
if [[ -n $BUILDER_UID ]] && [[ -n $BUILDER_GID ]]; then

    groupadd -o -g "$BUILDER_GID" "$BUILDER_GROUP" 2> /dev/null
    useradd -o -m -g "$BUILDER_GID" -u "$BUILDER_UID" "$BUILDER_USER" 2> /dev/null
    export HOME=/home/${BUILDER_USER}
    shopt -s dotglob
    cp -r /root/* $HOME/
    chown -R $BUILDER_UID:$BUILDER_GID $HOME

    # Enable passwordless sudo capabilities for the user
    chown root:$BUILDER_GID "$(which gosu)"
    chmod +s "$(which gosu)"; sync

    # Execute project specific pre execution hook
    if [[ -e /work/.crossbuild ]]; then
       gosu $BUILDER_UID:$BUILDER_GID /work/.crossbuild
    fi

    # Run the command as the specified user/group.
    exec gosu $BUILDER_UID:$BUILDER_GID "$@"
else
    # Execute project specific pre execution hook
    if [[ -e /work/.crossbuild ]]; then
       /work/.crossbuild
    fi

    # Just run the command as root.
    exec "$@"
fi

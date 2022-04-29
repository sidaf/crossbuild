#!/usr/bin/env bash

DEFAULT_CROSSBUILD_IMAGE=sidaf/crossbuild # DO NOT MOVE THIS LINE (see entrypoint.sh)

#------------------------------------------------------------------------------
# Helpers
#
err() {
    echo -e >&2 "ERROR: $*\n"
}

die() {
    err "$*"
    exit 1
}

has() {
    # eg. has command update
    local kind=$1
    local name=$2

    type -t $kind:$name | grep -q function
}

# If OCI_EXE is not already set, search for a container executor (OCI stands for "Open Container Initiative")
if [ -z "$OCI_EXE" ]; then
    if which docker >/dev/null 2>/dev/null; then
        OCI_EXE=docker
    elif which podman >/dev/null 2>/dev/null; then
        OCI_EXE=podman
    else
        die "Cannot find a container executor. Search for docker and podman."
    fi
fi

#------------------------------------------------------------------------------
# Command handlers
#
command:update-image() {
    $OCI_EXE pull $FINAL_IMAGE
}

help:update-image() {
    echo "Pull the latest $FINAL_IMAGE ."
}

command:update-script() {
    if cmp -s <( $OCI_EXE run --rm $FINAL_IMAGE ) $0; then
        echo "$0 is up to date"
    else
        echo -n "Updating $0 ... "
        $OCI_EXE run --rm $FINAL_IMAGE > $0 && echo ok
    fi
}

help:update-script() {
    echo "Update $0 from $FINAL_IMAGE ."
}

command:update() {
    command:update-image
    command:update-script
}

help:update() {
    echo "Pull the latest $FINAL_IMAGE, and then update $0 from that."
}

command:help() {
    if [[ $# != 0 ]]; then
        if ! has command $1; then
            err \"$1\" is not an crossbuild command
            command:help
        elif ! has help $1; then
            err No help found for \"$1\"
        else
            help:$1
        fi
    else
        cat >&2 <<ENDHELP
Usage: $(basename $0) [options] [--] command [args]

By default, run the given *command* in an crossbuild Docker container.

The *options* can be one of:

    --args|-a           Extra args to the *docker run* command
    --image|-i          Docker cross-compiler image to use
    --config|-c         Bash script to source before running this script


Additionally, there are special update commands:

    update-image
    update-script
    update

For update command help use: $(basename $0) help <command>
ENDHELP
        exit 1
    fi
}

#------------------------------------------------------------------------------
# Option processing
#

if [[ $# == 0 ]]; then
    command:help
    exit
fi

special_update_command=''
while [[ $# != 0 ]]; do
    case $1 in

        --)
            shift
            break
            ;;

        --args|-a)
            ARG_ARGS="$2"
            shift 2
            ;;

        --config|-c)
            ARG_CONFIG="$2"
            shift 2
            ;;

        --image|-i)
            ARG_IMAGE="$2"
            shift 2
            ;;
        update|update-image|update-script)
            special_update_command=$1
            break
            ;;
        -*)
            err Unknown option \"$1\"
            command:help
            exit
            ;;

        *)
            break
            ;;

    esac
done

# The precedence for options is:
# 1. command-line arguments
# 2. environment variables
# 3. defaults

# Source the config file if it exists
DEFAULT_CROSSBUILD_CONFIG=~/.crossbuild
FINAL_CONFIG=${ARG_CONFIG-${CROSSBUILD_CONFIG-$DEFAULT_CROSSBUILD_CONFIG}}

[[ -f "$FINAL_CONFIG" ]] && source "$FINAL_CONFIG"

# Set the docker image
FINAL_IMAGE=${ARG_IMAGE-${CROSSBUILD_IMAGE-$DEFAULT_CROSSBUILD_IMAGE}}

# Handle special update command
if [ "$special_update_command" != "" ]; then
    case $special_update_command in

        update)
            command:update
            exit $?
            ;;

        update-image)
            command:update-image
            exit $?
            ;;

        update-script)
            command:update-script
            exit $?
            ;;

    esac
fi

if [ -z "${CROSS_TRIPLE}" ]; then
    BASENAME="$(basename "$0")"
    CROSS_TRIPLE="${BASENAME%-*}"
fi

# Set the docker run extra args (if any)
FINAL_ARGS=${ARG_ARGS-${CROSSBUILD_ARGS}}

# Bash on Ubuntu on Windows
UBUNTU_ON_WINDOWS=$([ -e /proc/version ] && grep -l Microsoft /proc/version || echo "")
# MSYS, Git Bash, etc.
MSYS=$([ -e /proc/version ] && grep -l MINGW /proc/version || echo "")
# CYGWIN
CYGWIN=$([ -e /proc/version ] && grep -l CYGWIN /proc/version || echo "")

if [ -z "$UBUNTU_ON_WINDOWS" -a -z "$MSYS" ]; then
    USER_IDS=(-e BUILDER_UID="$( id -u )" -e BUILDER_GID="$( id -g )" -e BUILDER_USER="$( id -un )" -e BUILDER_GROUP="$( id -gn )")
fi

# Change the PWD when working in Docker on Windows
if [ -n "$UBUNTU_ON_WINDOWS" ]; then
    WSL_ROOT="/mnt/"
    CFG_FILE=/etc/wsl.conf
	if [ -f "$CFG_FILE" ]; then
		CFG_CONTENT=$(cat $CFG_FILE | sed -r '/[^=]+=[^=]+/!d' | sed -r 's/\s+=\s/=/g')
		eval "$CFG_CONTENT"
		if [ -n "$root" ]; then
			WSL_ROOT=$root
		fi
	fi
    HOST_PWD=`pwd -P`
    HOST_PWD=${HOST_PWD/$WSL_ROOT//}
elif [ -n "$MSYS" ]; then
    HOST_PWD=$PWD
    HOST_PWD=${HOST_PWD/\//}
    HOST_PWD=${HOST_PWD/\//:\/}
elif [ -n "$CYGWIN" ]; then
    for f in pwd readlink cygpath ; do
        test -n "$(type "${f}" )" || { echo >&2 "Missing functionality (${f}) (in cygwin)." ; exit 1 ; } ;
    done ;
    HOST_PWD="$( cygpath -w "$( readlink -f "$( pwd ;)" ; )" ; )" ;
else
    HOST_PWD=$PWD
    [ -L $HOST_PWD ] && HOST_PWD=$(readlink $HOST_PWD)
fi

# Mount Additional Volumes
if [ -z "$SSH_DIR" ]; then
    SSH_DIR="$HOME/.ssh"
fi

HOST_VOLUMES=
if [ -e "$SSH_DIR" -a -z "$MSYS" ]; then
    if test -n "${CYGWIN}" ; then
      HOST_VOLUMES+="-v $(cygpath -w ${SSH_DIR} ; ):/home/$(id -un)/.ssh" ;
    else
      HOST_VOLUMES+="-v $SSH_DIR:/home/$(id -un)/.ssh" ;
    fi ;
fi

#------------------------------------------------------------------------------
# Now, finally, run the command in a container
#
TTY_ARGS=
tty -s && [ -z "$MSYS" ] && TTY_ARGS=-ti
CONTAINER_NAME=crossbuild_$RANDOM
$OCI_EXE run $TTY_ARGS --name $CONTAINER_NAME \
    -e CROSS_TRIPLE=${CROSS_TRIPLE} \
    -v "$HOST_PWD":/work \
    $HOST_VOLUMES \
    "${USER_IDS[@]}" \
    $FINAL_ARGS \
    $FINAL_IMAGE "$@"
run_exit_code=$?

# Attempt to delete container
rm_output=$($OCI_EXE rm -f $CONTAINER_NAME 2>&1)
rm_exit_code=$?
if [[ $rm_exit_code != 0 ]]; then
  if [[ "$CIRCLECI" == "true" ]] && [[ $rm_output == *"Driver btrfs failed to remove"* ]]; then
    : # Ignore error because of https://circleci.com/docs/docker-btrfs-error/
  else
    echo "$rm_output"
    exit $rm_exit_code
  fi
fi

exit $run_exit_code

################################################################################
#
# Although possible, this image is not intended to be run directly.
#
# To create a helper script for this image, run the following command
# substituting "<target-triplet>" with the required target triplet or alias
# e.g. x86_64-w64-mingw32
#
# $ docker run --rm sidaf/crossbuild > <target-triplet>-crossbuild
# $ chmod +x <target-triplet>-crossbuild
#
# You may then wish to move the "<target-triplet>-crossbuild" script to your PATH.
#
################################################################################

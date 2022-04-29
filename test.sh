#!/bin/bash
set -eo pipefail

# A POSIX variable
OPTIND=1 # Reset in case getopts has been used previously in the shell.

while getopts "d:" opt; do
    case "$opt" in
        d)  DOCKER_REPO=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

LINUX_TRIPLES="x86_64-linux-gnu i686-pc-linux-gnu"
DARWIN_TRIPLES="x86_64-apple-darwin x86_64h-apple-darwin"
WINDOWS_TRIPLES="x86_64-w64-mingw32 i686-w64-mingw32"
DOCKER_TEST_ARGS="--rm -v $(pwd)/test:/test -w /test"

for triple in ${DARWIN_TRIPLES} ${LINUX_TRIPLES} ${WINDOWS_TRIPLES} ${ALIAS_TRIPLES}; do
    docker run ${DOCKER_TEST_ARGS} -e CROSS_TRIPLE=${triple} ${DOCKER_REPO} make test;
done

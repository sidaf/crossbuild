# crossbuild
Multiarch cross compiling environment

[![actions](https://github.com/multiarch/crossbuild/actions/workflows/actions.yml/badge.svg)](https://github.com/multiarch/crossbuild/actions/workflows/actions.yml)

This is a multiarch Docker build environment image.
You can use this image to produce binaries for multiple architectures.

## Supported targets

Triple                 | Aliases                              | linux |  osx  | windows
-----------------------|--------------------------------------|-------|-------|--------
x86_64-linux-gnu       | **(default)**, linux, amd64, x86_64  |   X   |       |
i686-linux-gnu         | i686, linux32                        |   X   |       |
x86_64-apple-darwin    | macos, osx, osx64, darwin, darwin64  |       |   X   |
x86_64h-apple-darwin   | macos64h, osx64h, darwin64h, x86_64h |       |   X   |
x86_64-w64-mingw32     | windows, win64                       |       |       |   X
i686-w64-mingw32       | win32                                |       |       |   X

## Using crossbuild

### Shorthand

To create a helper script for this image, run the following command substituting "<target-triplet>" with the required target triplet or alias e.g. x86_64-w64-mingw32. This can be repeated for other target triplets / aliases.

```console
docker run --rm sidaf/crossbuild > <target-triplet>-crossbuild
chmod +x <target-triplet>-crossbuild
```

You may then wish to move the "<target-triplet>-crossbuild" script to your PATH.

### Longhand

#### x86_64

```console
$ docker run --rm -v $(pwd):/workdir sidaf/crossbuild make helloworld
cc helloworld.c -o helloworld
$ file helloworld
helloworld: ELF 64-bit LSB  executable, x86-64, version 1 (SYSV), dynamically linked (uses shared libs), for GNU/Linux 2.6.32, BuildID[sha1]=9cfb3d5b46cba98c5aa99db67398afbebb270cb9, not stripped
```

Misc: using `cc` instead of `make`

```console
$ docker run --rm -v $(pwd):/workdir sidaf/crossbuild cc test/helloworld.c
```

#### darwin x86_64

```console
$ docker run -it --rm -v $(pwd):/workdir -e CROSS_TRIPLE=x86_64-apple-darwin  sidaf/crossbuild make helloworld
o64-clang     helloworld.c   -o helloworld
$ file helloworld
helloworld: Mach-O 64-bit executable x86_64
```

#### windows i386

```console
$ docker run -it --rm -v $(pwd):/workdir -e CROSS_TRIPLE=i686-w64-mingw32  sidaf/crossbuild make helloworld
o32-clang     helloworld.c   -o helloworld
$ file helloworld
helloworld: PE32 executable (console) Intel 80386, for MS Windows
```

#### windows x86_64

```console
$ docker run -it --rm -v $(pwd):/workdir -e CROSS_TRIPLE=x86_64-w64-mingw32  sidaf/crossbuild make helloworld
o64-clang     helloworld.c   -o helloworld
$ file helloworld
helloworld: PE32+ executable (console) x86-64, for MS Windows
```

## Using crossbuild in a Dockerfile

```Dockerfile
FROM sidaf/crossbuild
RUN git clone https://github.com/bit-spark/objective-c-hello-world
ENV CROSS_TRIPLE=x86_64-apple-darwin
WORKDIR /workdir/objective-c-hello-world
RUN crossbuild ./compile-all.sh
```

## Credit

This project is inspired by
* [multiarch/crossbuild](https://github.com/multiarch/crossbuild)
* [steeve/cross-compiler](https://github.com/steeve/cross-compiler)
* [silkeh/docker-clang](https://github.com/silkeh/docker-clang)
* [mstorsjo/llvm-mingw/](https://github.com/mstorsjo/llvm-mingw/)
* [tpoechtrager/osxcross](https://github.com/tpoechtrager/osxcross)
* [dockcross/dockcross](https://github.com/dockcross/dockcross)

## Legal note

OSX/Darwin/Apple builds: 
**[Please ensure you have read and understood the Xcode license
   terms before continuing.](https://www.apple.com/legal/sla/docs/xcode.pdf)**


## License

MIT

set(CMAKE_SYSTEM_NAME $ENV{CROSS_OPERATING_SYSTEM})
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR $ENV{CROSS_MACHINE})

set(cross_triple $ENV{CROSS_TRIPLE})
set(cross_root $ENV{CROSS_ROOT})

set(CMAKE_AS $ENV{AS})
set(CMAKE_AR $ENV{AR})
set(CMAKE_C_COMPILER $ENV{CC})
set(CMAKE_CXX_COMPILER $ENV{CXX})
set(CMAKE_ASM_COMPILER $ENV{CC})
set(CMAKE_OBJCOPY $ENV{OBJCOPY})
set(CMAKE_RANLIB $ENV{RANLIB})
set(CMAKE_STRIP $ENV{STRIP})

set(CMAKE_CXX_FLAGS "-I ${cross_root}/include/")

set(CMAKE_FIND_ROOT_PATH ${cross_root})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)

set(CMAKE_CROSSCOMPILING_EMULATOR ${cross_triple}-emulator)

# universal toolchain file for toolchain build environment

#######################################################
# custom variables for toolchain infrastructure

string(REGEX REPLACE ".*/(.*)\\.cmake" "\\1" TOOLCHAIN_ARCH "${CMAKE_CURRENT_LIST_FILE}")
set(TOOLCHAINS_ROOT "${CMAKE_CURRENT_LIST_DIR}")
set(TOOLCHAIN_ROOT "${CMAKE_CURRENT_LIST_DIR}/${TOOLCHAIN_ARCH}")

set(TOOLCHAIN_IS_CLANG OFF)
if (TOOLCHAIN_ARCH MATCHES "-apple-" OR TOOLCHAIN_ARCH MATCHES "-unknown-linux-")
  set(TOOLCHAIN_ROOT "${CMAKE_CURRENT_LIST_DIR}/clang-toolchain")
  set(TOOLCHAIN_IS_CLANG ON)
endif()

# separator for environment variables containing search paths
if (CMAKE_HOST_WIN32)
  set(TOOLCHAIN_PSEP ";")
   # Windows does not find the executables if the ".exe" suffix is missing
  set(CMAKE_EXECUTABLE_SUFFIX ".exe")
else()
  set(TOOLCHAIN_PSEP ":")
endif()


#######################################################
# detect CPU/system

string(REGEX REPLACE "-.*"        ""    CMAKE_SYSTEM_PROCESSOR "${TOOLCHAIN_ARCH}")
string(REGEX REPLACE ".*-([^-]*)-[^-]*" "\\1" CMAKE_SYSTEM_NAME "${TOOLCHAIN_ARCH}")
string(REGEX REPLACE ".*-"        ""    TOOLCHAIN_ABI "${TOOLCHAIN_ARCH}")

if (CMAKE_SYSTEM_NAME STREQUAL "w64")
  set(CMAKE_SYSTEM_NAME Windows)
elseif (CMAKE_SYSTEM_NAME STREQUAL "none" OR CMAKE_SYSTEM_NAME STREQUAL "unknown")
  set(CMAKE_SYSTEM_NAME Generic)
elseif (CMAKE_SYSTEM_NAME STREQUAL "apple")  
  # This is LLVM-based for now, since there is no aarch64-apple-darwin-gcc yet. Use a single LLVM dir for multiple targets
  set(CMAKE_SYSTEM_NAME Darwin)
else()
  set(CMAKE_SYSTEM_NAME Linux)
endif()

set(CMAKE_SYSTEM_VERSION 1)

set(TOOLCHAIN_PREFIX "${TOOLCHAIN_ARCH}")
if (TOOLCHAIN_ABI MATCHES "gnu")
  # the pre-built glibc toolchain uses a nonstandard tool prefix
  string(REGEX REPLACE "-linux-" "-buildroot-linux-" TOOLCHAIN_PREFIX "${TOOLCHAIN_ARCH}")
endif()


#######################################################
# basic settings

set(BUILD_SHARED_LIBRARIES OFF)
set(BUILD_SHARED_LIBS OFF)
set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
set(CMAKE_INSTALL_LIBDIR "lib")
if (CMAKE_HOST_WIN32)
  # this fixes some build scripts that do not expect cross-compilation
  set(CMAKE_COMPILER_IS_MINGW ON)
endif()


#######################################################
# tool invocation configuration

set(TOOLCHAIN_EXTRA_C_FLAGS "" CACHE STRING "Extra flags to pass to all C/C++ compiler invocations")
set(TOOLCHAIN_EXTRA_ASM_FLAGS "" CACHE STRING "Extra flags to pass to all assembler invocations")
set(TOOLCHAIN_EXTRA_LINKER_FLAGS "" CACHE STRING "Extra flags to pass to all linker invocations")
mark_as_advanced(TOOLCHAIN_EXTRA_C_FLAGS TOOLCHAIN_EXTRA_ASM_FLAGS TOOLCHAIN_EXTRA_LINKER_FLAGS)

set(TOOLCHAIN_COMMON_ASM_FLAGS "-isystem ${CGET_PREFIX}/include")
set(TOOLCHAIN_COMMON_C_FLAGS "-isystem ${CGET_PREFIX}/include -O2")
set(TOOLCHAIN_COMMON_LINKER_FLAGS " -L${CGET_PREFIX}/lib")

# static (musl/mingw) vs. dynamic (glibc) linking
if (TOOLCHAIN_ABI MATCHES "gnu")
  # "-rpath=$ORIGIN" makes dynamically linked distribution easier
  string(APPEND TOOLCHAIN_COMMON_LINKER_FLAGS " -Wl,-rpath=\\$ORIGIN")

elseif (CMAKE_SYSTEM_NAME STREQUAL "Windows")
  # mingw has regex not built in, also sometimes ssp is required
  set(CMAKE_C_STANDARD_LIBRARIES "-lssp -lregex" CACHE STRING "")
  set(CMAKE_CXX_STANDARD_LIBRARIES "-lssp -lregex" CACHE STRING "")
  string(APPEND TOOLCHAIN_COMMON_LINKER_FLAGS " -static --static")

elseif (TOOLCHAIN_IS_CLANG)
  string(APPEND TOOLCHAIN_COMMON_C_FLAGS " --sysroot=${TOOLCHAIN_ROOT}/lib/clang/18/lib/${TOOLCHAIN_ARCH}")
  string(APPEND TOOLCHAIN_COMMON_LINKER_FLAGS " --sysroot=${TOOLCHAIN_ROOT}/lib/clang/18/lib/${TOOLCHAIN_ARCH}")

else()
  string(APPEND TOOLCHAIN_COMMON_LINKER_FLAGS " -static --static")

endif()

set(CMAKE_ASM_FLAGS_INIT "${TOOLCHAIN_COMMON_ASM_FLAGS}")
set(CMAKE_ASM_FLAGS_RELEASE_INIT "${TOOLCHAIN_EXTRA_ASM_FLAGS}")
set(CMAKE_ASM_FLAGS_DEBUG_INIT "${TOOLCHAIN_EXTRA_ASM_FLAGS}")
set(CMAKE_ASM_FLAGS_RELWITHDEBINFO_INIT "${TOOLCHAIN_EXTRA_ASM_FLAGS}")
set(CMAKE_ASM_FLAGS_MINSIZEREL_INIT "${TOOLCHAIN_EXTRA_ASM_FLAGS}")

set(CMAKE_C_FLAGS_INIT "${TOOLCHAIN_COMMON_C_FLAGS}")
set(CMAKE_C_FLAGS_RELEASE_INIT "-O3 -flto -ffat-lto-objects ${TOOLCHAIN_EXTRA_C_FLAGS}")
set(CMAKE_C_FLAGS_DEBUG_INIT "-Og -ggdb -g3 ${TOOLCHAIN_EXTRA_C_FLAGS}")
set(CMAKE_C_FLAGS_RELWITHDEBINFO_INIT "-O3 -ggdb -g3 ${TOOLCHAIN_EXTRA_C_FLAGS}")
set(CMAKE_C_FLAGS_MINSIZEREL_INIT "-Os ${TOOLCHAIN_EXTRA_C_FLAGS}")

set(CMAKE_CXX_FLAGS_INIT "${CMAKE_C_FLAGS_INIT}")
set(CMAKE_CXX_FLAGS_RELEASE_INIT "${CMAKE_C_FLAGS_RELEASE_INIT}")
set(CMAKE_CXX_FLAGS_DEBUG_INIT "${CMAKE_C_FLAGS_DEBUG_INIT}")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO_INIT "${CMAKE_C_FLAGS_RELWITHDEBINFO_INIT}")
set(CMAKE_CXX_FLAGS_MINSIZEREL_INIT "${CMAKE_C_FLAGS_MINSIZEREL_INIT}")

set(CMAKE_EXE_LINKER_FLAGS_INIT "${TOOLCHAIN_COMMON_LINKER_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE_INIT "-O3 -flto -ffat-lto-objects ${TOOLCHAIN_EXTRA_LINKER_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG_INIT "-Og ${TOOLCHAIN_EXTRA_LINKER_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO_INIT "-O3 -s ${TOOLCHAIN_EXTRA_LINKER_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL_INIT "-Os -s ${TOOLCHAIN_EXTRA_LINKER_FLAGS}")

set(CMAKE_LINK_SEARCH_START_STATIC ON)
set(CMAKE_LINK_SEARCH_END_STATIC ON)
set(CMAKE_C_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-gcc${CMAKE_EXECUTABLE_SUFFIX}")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-g++${CMAKE_EXECUTABLE_SUFFIX}")
set(CMAKE_ASM_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-gcc${CMAKE_EXECUTABLE_SUFFIX}")
set(CMAKE_AR "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-gcc-ar${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
set(CMAKE_RANLIB "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-ranlib${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
set(CMAKE_NM "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-nm${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
set(CMAKE_OBJCOPY "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-objcopy${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
set(CMAKE_OBJDUMP "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-objdump${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
set(CMAKE_STRIP "${TOOLCHAIN_ROOT}/${TOOLCHAIN_PREFIX}/bin/strip${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
set(CMAKE_LINKER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-ld${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
set(CMAKE_RC_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-windres${CMAKE_EXECUTABLE_SUFFIX}")
set(CMAKE_INSTALL_NAME_TOOL "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-install_name_tool${CMAKE_EXECUTABLE_SUFFIX}")

if (TOOLCHAIN_IS_CLANG)
  set(CMAKE_C_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-clang${CMAKE_EXECUTABLE_SUFFIX}")
  set(CMAKE_CXX_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-clang++${CMAKE_EXECUTABLE_SUFFIX}")
  set(CMAKE_ASM_COMPILER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-clang${CMAKE_EXECUTABLE_SUFFIX}")
  set(CMAKE_LINKER "${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_PREFIX}-clang++${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
  set(CMAKE_AR "${TOOLCHAIN_ROOT}/bin/llvm-ar${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
  set(CMAKE_RANLIB "${TOOLCHAIN_ROOT}/bin/llvm-ranlib${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
  set(CMAKE_STRIP "${TOOLCHAIN_ROOT}/bin/llvm-strip${CMAKE_EXECUTABLE_SUFFIX}" CACHE STRING "" FORCE)
endif()

#######################################################
# search paths

set(ENV{PATH} "\
${TOOLCHAINS_ROOT}/bin\
${TOOLCHAIN_PSEP}\
${TOOLCHAIN_ROOT}/bin\
${TOOLCHAIN_PSEP}\
${TOOLCHAIN_ROOT}/${TOOLCHAIN_PREFIX}/bin\
")
set(CMAKE_FIND_ROOT_PATH
  "${TOOLCHAIN_ROOT}/${TOOLCHAIN_PREFIX}"
  "${TOOLCHAIN_ROOT}"
  "${CGET_PREFIX}"
  "${TOOLCHAINS_ROOT}"
  "${TOOLCHAIN_ROOT}/SDK/MacOSX11.1.sdk"
)
set(CMAKE_PROGRAM_PATH "${TOOLCHAINS_ROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

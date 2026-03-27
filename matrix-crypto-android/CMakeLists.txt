cmake_minimum_required(VERSION 3.22.1)
project(matrix_crypto_bridge)

# Set Rust build directory
set(RUST_BUILD_DIR "${CMAKE_SOURCE_DIR}/../matrix-crypto-core/target")

# Add prebuilt Rust library
add_library(matrix_crypto_core STATIC IMPORTED)

# Determine the target architecture
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(RUST_TARGET "aarch64-linux-android")
    set(LIB_PATH "${RUST_BUILD_DIR}/${RUST_TARGET}/release/libmatrix_crypto_core.a")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(RUST_TARGET "armv7-linux-android")
    set(LIB_PATH "${RUST_BUILD_DIR}/${RUST_TARGET}/release/libmatrix_crypto_core.a")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(RUST_TARGET "x86_64-linux-android")
    set(LIB_PATH "${RUST_BUILD_DIR}/${RUST_TARGET}/release/libmatrix_crypto_core.a")
elseif(ANDROID_ABI STREQUAL "x86")
    set(RUST_TARGET "i686-linux-android")
    set(LIB_PATH "${RUST_BUILD_DIR}/${RUST_TARGET}/release/libmatrix_crypto_core.a")
else()
    message(FATAL_ERROR "Unsupported ABI: ${ANDROID_ABI}")
endif()

set_target_properties(matrix_crypto_core PROPERTIES
    IMPORTED_LOCATION "${LIB_PATH}"
)

# Create JNI bridge library
add_library(matrix_crypto_jni SHARED
    src/main/jni/matrix_crypto_jni.cpp
)

# Link against Rust library
target_link_libraries(matrix_crypto_jni
    matrix_crypto_core
    log
)

# Set include directories
target_include_directories(matrix_crypto_jni PRIVATE
    "${RUST_BUILD_DIR}/${RUST_TARGET}/release"
)

# Set C++ standard
set_target_properties(matrix_crypto_jni PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
)

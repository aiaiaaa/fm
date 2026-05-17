# Native module for X.FM spectrum analyzer
# Decodes AAC ADTS frames to PCM via OH_AudioCodec, then runs FFT to produce
# 16 frequency bands suitable for visualization.

cmake_minimum_required(VERSION 3.5.0)
project(xfm_spectrum)

set(CMAKE_CXX_STANDARD 17)
set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

add_library(xfm_spectrum SHARED
    napi_init.cpp
    aac_decoder.cpp
    fft.cpp
    spectrum.cpp
)

target_link_libraries(xfm_spectrum PUBLIC
    libace_napi.z.so
    libnative_media_acodec.so
    libnative_media_codecbase.so
    libnative_media_core.so
    libhilog_ndk.z.so
)

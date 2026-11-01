#!/bin/sh
# Builds libnaimport. Run inside a box that has cmake + ninja (distrobox `omtbuild`):
#   native/build.sh linux      -> addons/naimport/bin/libnaimport.linux.template_release.x86_64.so
#   native/build.sh android    -> addons/naimport/bin/libnaimport.android.template_release.arm64.so   (needs the NDK: sdkmanager "ndk;27.2.12479018")
set -e
H=$(cd "$(dirname "$0")" && pwd); cd "$H"; ./fetch-deps.sh
case "$1" in
linux) cmake -S . -B build-linux -GNinja -DCMAKE_BUILD_TYPE=Release && cmake --build build-linux -j8 ;;
android)
  NDK=${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/27.2.12479018}
  cmake -S . -B build-android -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_STL=c++_static -DGODOTCPP_TARGET=template_release
  cmake --build build-android -j8 ;;
*) echo "usage: build.sh linux|android"; exit 2 ;;
esac

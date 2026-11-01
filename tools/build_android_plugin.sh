#!/bin/bash
# Builds the SharedImport Android plugin AAR -> addons/sharedimport/bin/sharedimport.aar
# Needs: tools/setup_android_build.sh run once, a JDK 17 (JAVA_HOME) and the Android SDK (ANDROID_HOME).
set -e
cd "$(dirname "$0")/.."
export JAVA_HOME=${JAVA_HOME:-$HOME/.local/share/jdk/jdk-17.0.21+9}
export ANDROID_HOME=${ANDROID_HOME:-$HOME/Android/Sdk}
P=android/plugins/sharedimport
[ -d android/build/gradle ] || tools/setup_android_build.sh
mkdir -p $P/gradle; cp -r android/build/gradle/wrapper $P/gradle/; cp android/build/gradlew $P/gradlew; chmod +x $P/gradlew
echo "sdk.dir=$ANDROID_HOME" > $P/local.properties
(cd $P && timeout 900 ./gradlew --no-daemon -q assembleRelease)
mkdir -p addons/sharedimport/bin
cp $P/build/outputs/aar/sharedimport-release.aar addons/sharedimport/bin/sharedimport.aar
echo "built addons/sharedimport/bin/sharedimport.aar"

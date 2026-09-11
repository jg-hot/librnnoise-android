#!/usr/bin/env bash
set -o xtrace

BUILD_DIR="./build"
rm -rf "$BUILD_DIR/"

./android-build.sh
./android-package.sh

ARTIFACT="rnnoise-android"

mvn deploy:deploy-file \
    -Durl="https://maven.pkg.github.com/jg-hot/librnnoise-android" \
    -DrepositoryId="gpr:librnnoise-android" \
    -Dfile="${BUILD_DIR}/$ARTIFACT.aar" \
    -DpomFile="./android/$ARTIFACT.pom" \
    -Dpackaging=aar \

# or if installing to maven local
# mvn install:install-file \
#     -Dfile="${BUILD_DIR}/$ARTIFACT.aar" \
#     -DpomFile="./android/$ARTIFACT.pom" \
#     -Dpackaging=aar \

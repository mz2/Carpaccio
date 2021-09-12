#!/bin/bash

set -x
set -e

NAME=$1xcodebuild archive -workspace . \
  -scheme Carpaccio -arch x86_64 -arch arm64 \
  -derivedDataPath .build \
  -archivePath Release-macOS \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES ONLY_ACTIVE_ARCH=NO | xcpretty

xcodebuild -create-xcframework \
  -framework Release-macOS.xcarchive/Products/usr/local/lib/Carpaccio.framework \
  -output Carpaccio.xcframework
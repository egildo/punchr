#!/bin/sh
# Spike: builds build/PunchrShelf.app (host + File Provider extension), ad-hoc signed. Run from anywhere.
#   experiments/shelf/build.sh            build
#   experiments/shelf/build.sh register   also register with Launch Services and PlugInKit
set -e
cd "$(dirname "$0")"
A=../../build/PunchrShelf.app/Contents; E=$A/PlugIns/ShelfProvider.appex/Contents
rm -rf ../../build/PunchrShelf.app; mkdir -p $A/MacOS $E/MacOS
cp App-Info.plist $A/Info.plist; cp Ext-Info.plist $E/Info.plist
swiftc -O -swift-version 5 -module-name Shelf main.swift -framework FileProvider -o $A/MacOS/Shelf
swiftc -O -swift-version 5 -parse-as-library -module-name ShelfProvider Shelf.swift \
  -framework FileProvider -Xlinker -e -Xlinker _NSExtensionMain -o $E/MacOS/ShelfProvider
codesign -f -s - --entitlements ext.entitlements $A/PlugIns/ShelfProvider.appex
codesign -f -s - --entitlements app.entitlements ../../build/PunchrShelf.app
if [ "$1" = register ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R ../../build/PunchrShelf.app
  pluginkit -a $A/PlugIns/ShelfProvider.appex
  pluginkit -m -v -i local.punchr.shelf.provider
fi

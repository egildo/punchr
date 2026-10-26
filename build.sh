#!/bin/sh
# Build Punchr.app with the Command Line Tools only (no Xcode), ad-hoc signed; the extension is sandboxed.
# The app's executable is the punchr command; build/punchr links to it.
#   ./build.sh            builds build/Punchr.app and build/punchr
#   ./build.sh check      also builds and runs the checks, in a temporary folder
#   ./build.sh register   also registers it with Launch Services and PlugInKit (then enable it, restart Finder)
set -e
cd "$(dirname "$0")"
A=build/Punchr.app/Contents; E=$A/PlugIns/PunchrFinder.appex/Contents
rm -rf build/Punchr.app; mkdir -p $A/MacOS $E/MacOS
cp Support/App-Info.plist $A/Info.plist; cp Support/Ext-Info.plist $E/Info.plist
swiftc -O -module-name Punchr Sources/core/*.swift Sources/shelf/Links.swift Sources/app/main.swift -framework Cocoa -o $A/MacOS/Punchr
swiftc -O -parse-as-library -module-name PunchrFinder Sources/finder/FinderSync.swift \
  -framework FinderSync -framework Cocoa -Xlinker -e -Xlinker _NSExtensionMain -o $E/MacOS/PunchrFinder
# The shelf template: copied, renamed and signed per shelf at run time, never registered itself.
T=$A/Resources/Shelf.app/Contents; P=$T/PlugIns/ShelfProvider.appex/Contents
mkdir -p $T/MacOS $P/MacOS
cp Support/Shelf-Info.plist $T/Info.plist; cp Support/ShelfProvider-Info.plist $P/Info.plist
swiftc -O -swift-version 5 -module-name Shelf Sources/shelf/main.swift Sources/shelf/Links.swift -framework FileProvider -o $T/MacOS/Shelf
swiftc -O -swift-version 5 -parse-as-library -module-name ShelfProvider Sources/shelf/Provider.swift Sources/shelf/Links.swift \
  -framework FileProvider -Xlinker -e -Xlinker _NSExtensionMain -o $P/MacOS/ShelfProvider
codesign -f -s - --entitlements Support/shelf-provider.entitlements $T/PlugIns/ShelfProvider.appex
codesign -f -s - --entitlements Support/shelf.entitlements $A/Resources/Shelf.app
codesign -f -s - --entitlements Support/extension.entitlements $A/PlugIns/PunchrFinder.appex
codesign -f -s - build/Punchr.app
ln -sf Punchr.app/Contents/MacOS/Punchr build/punchr
if [ "$1" = check ]; then
  swiftc -O -module-name Checks Sources/core/*.swift Sources/shelf/Links.swift Sources/checks/main.swift -framework Cocoa -o build/checks
  build/checks
fi
if [ "$1" = register ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R build/Punchr.app
  pluginkit -a $A/PlugIns/PunchrFinder.appex
  pluginkit -m -i local.punchr.findersync
fi

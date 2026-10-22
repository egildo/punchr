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
swiftc -O -module-name Punchr Sources/core/*.swift Sources/app/main.swift -framework Cocoa -o $A/MacOS/Punchr
swiftc -O -parse-as-library -module-name PunchrFinder Sources/finder/FinderSync.swift \
  -framework FinderSync -framework Cocoa -Xlinker -e -Xlinker _NSExtensionMain -o $E/MacOS/PunchrFinder
codesign -f -s - --entitlements Support/extension.entitlements $A/PlugIns/PunchrFinder.appex
codesign -f -s - build/Punchr.app
ln -sf Punchr.app/Contents/MacOS/Punchr build/punchr
if [ "$1" = check ]; then
  swiftc -O -module-name Checks Sources/core/*.swift Sources/checks/main.swift -framework Cocoa -o build/checks
  build/checks
fi
if [ "$1" = register ]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R build/Punchr.app
  pluginkit -a $A/PlugIns/PunchrFinder.appex
  pluginkit -m -i local.punchr.findersync
fi

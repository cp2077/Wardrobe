#!/bin/bash
rm -rf build
mkdir build
cd build
mkdir -p bin/x64/plugins/cyber_engine_tweaks/mods/Wardrobe/
cp ../init.lua bin/x64/plugins/cyber_engine_tweaks/mods/Wardrobe/init.lua
cp -r ../Modules bin/x64/plugins/cyber_engine_tweaks/mods/Wardrobe/
zip -r bin.zip bin
rm -rf bin

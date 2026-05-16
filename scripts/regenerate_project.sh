#!/bin/sh
set -eu

xcodegen generate
LC_ALL=C perl -0pi -e 's/objectVersion = 77;/objectVersion = 60;/g; s/preferredProjectObjectVersion = 77;/preferredProjectObjectVersion = 60;/g' Coins.xcodeproj/project.pbxproj

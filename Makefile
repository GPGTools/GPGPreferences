PROJECT = GPGPreferences
TARGET = GPGPreferences
CONFIG = Release

include Dependencies/GPGTools_Core/make/default

all: compile

update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -
update-libmac:
	@cd Dependencies/Libmacgpg; git pull origin lion; cd -
update-me:
	@git pull
update: update-core update-libmac update-me

compile:
	@echo "  * Building...(can take some minutes)";
	@xcodebuild -project GPGPreferences.xcodeproj -target GPGPreferences -configuration Release build

install: compile
	@echo "  * Installing...";
	@mkdir -p ~/Library/PreferencePanes >> build.log 2>&1
	@rm -rf ~/Library/PreferencePanes/GPGPreferences.prefPane >> build.log 2>&1
	@cp -r build/Release/GPGPreferences.prefPane ~/Library/PreferencePanes >> build.log 2>&1

dmg: update compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh

test: compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh auto

clean:
	xcodebuild -project GPGPreferences.xcodeproj -target GPGPreferences -configuration Release clean > /dev/null
	xcodebuild -project GPGPreferences.xcodeproj -target GPGPreferences -configuration Debug clean > /dev/null
	@rm -f build.log

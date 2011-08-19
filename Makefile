all: compile

update-core:
	@cd Dependencies/GPGTools_Core; git pull origin master; cd -
update-libmac:
	@cd Dependencies/Libmacgpg; git pull origin lion; cd -
update-me:
	@git pull
update: update-core update-libmac update-me

compile:
	@echo "(have a look at build.log for details)";
	@echo "" > build.log
	@echo "  * Building...(can take some minutes)";
	@xcodebuild -project GPGTools_Preferences.xcodeproj -target GPGTools -configuration Release build >> build.log 2>&1

install: compile
	@echo "  * Installing...";
	@mkdir -p ~/Library/PreferencePanes >> build.log 2>&1
	@rm -rf ~/Library/PreferencePanes/GPGTools.prefPane >> build.log 2>&1
	@cp -r build/Release/GPGTools.prefPane ~/Library/PreferencePanes >> build.log 2>&1

dmg: update compile
	@./Dependencies/GPGTools_Core/scripts/create_dmg.sh $(pwd)

clean:
	xcodebuild -project GPGTools_Preferences.xcodeproj -target GPGTools -configuration Release clean > /dev/null
	xcodebuild -project GPGTools_Preferences.xcodeproj -target GPGTools -configuration Debug clean > /dev/null

check-all-warnings: clean-GPGTools_Preferences
	make | grep "warning: "

check-warnings: clean-GPGTools_Preferences
	make | grep "warning: "|grep -v "#warning"


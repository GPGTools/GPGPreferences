all: compile

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

dmg: compile
	@./Installer/create_dmg.sh

clean:
	xcodebuild -project GPGTools_Preferences.xcodeproj -target GPGTools -configuration Release clean > /dev/null
	xcodebuild -project GPGTools_Preferences.xcodeproj -target GPGTools -configuration Debug clean > /dev/null

check-all-warnings: clean-GPGTools_Preferences
	make | grep "warning: "

check-warnings: clean-GPGTools_Preferences
	make | grep "warning: "|grep -v "#warning"


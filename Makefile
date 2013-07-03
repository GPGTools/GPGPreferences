PROJECT = GPGPreferences
TARGET = GPGPreferences
PRODUCT = GPGPreferences
MAKE_DEFAULT = Dependencies/GPGTools_Core/newBuildSystem/Makefile.default
VPATH = build/$(CONFIG)/GPGPreferences.prefPane/Contents/MacOS
NEED_LIBMACGPG = 1


-include $(MAKE_DEFAULT)

.PRECIOUS: $(MAKE_DEFAULT)
$(MAKE_DEFAULT):
	@bash -c "$$(curl -fsSL https://raw.github.com/GPGTools/GPGTools_Core/master/newBuildSystem/prepare-core.sh)"

init: $(MAKE_DEFAULT)


$(PRODUCT): Source/* Resources/* Resources/*/* GPGPreferences.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)

install: $(PRODUCT)
	@echo "Installing GPGPreferences into $(INSTALL_ROOT)Library/PreferencePanes"
	@mkdir -p "$(INSTALL_ROOT)Library/PreferencePanes"
	@rsync -rltDE "build/$(CONFIG)/GPGPreferences.prefPane" "$(INSTALL_ROOT)Library/PreferencePanes"
	@echo Done
	@echo "In order to use GPGPreferences, please don't forget to install MacGPG2 and Libmacgpg."




PROJECT = GPGPreferences
TARGET = GPGPreferences
PRODUCT = GPGPreferences.prefPane
MAKE_DEFAULT = Dependencies/GPGTools_Core/newBuildSystem/Makefile.default

-include $(MAKE_DEFAULT)

.PRECIOUS: $(MAKE_DEFAULT)
$(MAKE_DEFAULT):
	@bash -c "$$(curl -fsSL https://raw.github.com/GPGTools/GPGTools_Core/master/newBuildSystem/prepare-core.sh)"

init: $(MAKE_DEFAULT)

update: update-libmacgpg

pkg: pkg-libmacgpg

clean-all: clean-libmacgpg

$(PRODUCT): Source/* Resources/* Resources/*/* GPGPreferences.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)


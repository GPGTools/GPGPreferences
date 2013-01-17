PROJECT = GPGPreferences
TARGET = GPGPreferences
PRODUCT = GPGPreferences.prefPane

include Dependencies/GPGTools_Core/newBuildSystem/Makefile.default


update: update-libmacgpg

pkg: pkg-libmacgpg

clean-all: clean-libmacgpg

$(PRODUCT): Source/* Resources/* Resources/*/* GPGPreferences.xcodeproj
	@xcodebuild -project $(PROJECT).xcodeproj -target $(TARGET) -configuration $(CONFIG) build $(XCCONFIG)


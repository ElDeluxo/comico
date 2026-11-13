TARGET := iphone:clang:11.4:9.0
ARCHS := armv7 arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Comico

Comico_FILES = \
    src/main.m \
    src/AppDelegate.m \
    src/Models/Comic.m \
    src/Models/Chapter.m \
    src/Services/FavoritesManager.m \
    src/Services/ImageCache.m \
    src/Services/APIService.m \
    src/Services/TLSHTTPClient.m \
    src/Views/ComicGridCell.m \
    src/Views/ChapterCell.m \
    src/Controllers/HomeViewController.m \
    src/Controllers/ComicDetailViewController.m \
    src/Controllers/ReaderViewController.m \
    src/Controllers/FavoritesViewController.m \
    src/Controllers/MainTabBarController.m \
    $(wildcard vendor/mbedtls/library/*.c)

Comico_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
Comico_CFLAGS = -O2 -Isrc -Isrc/Models -Isrc/Services -Isrc/Views -Isrc/Controllers -Ivendor/mbedtls/include -Ivendor/mbedtls/library -Wno-unused-function -Wno-deprecated-declarations -Wno-macro-redefined
Comico_OBJCFLAGS = -fobjc-arc
Comico_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/application.mk

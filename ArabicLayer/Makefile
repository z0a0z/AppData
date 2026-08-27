ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AppDataArabic
AppDataArabic_FILES = AppDataArabic.xm
AppDataArabic_FRAMEWORKS = UIKit Foundation
AppDataArabic_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

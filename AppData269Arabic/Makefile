ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AppDataArabic
AppDataArabic_FILES = Tweak.xm
AppDataArabic_CFLAGS = -fobjc-arc
AppDataArabic_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

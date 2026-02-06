TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RobloxExecutor
RobloxExecutor_FILES = Tweak.mm
RobloxExecutor_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
RobloxExecutor_FRAMEWORKS = UIKit WebKit Foundation
RobloxExecutor_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

TARGET    := iphone:clang:latest:14.0
ARCHS     = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyMockTweak

MyMockTweak_FILES = Tweak.x
MyMockTweak_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function -Wno-deprecated
MyMockTweak_FRAMEWORKS = UIKit Photos CoreLocation Contacts

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Preferences
include $(THEOS_MAKE_PATH)/aggregate.mk

TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MyMockTweakPrefs
MyMockTweakPrefs_FILES = PRMPrefsListController.m
MyMockTweakPrefs_CFLAGS = -fobjc-arc
MyMockTweakPrefs_FRAMEWORKS = UIKit
MyMockTweakPrefs_PRIVATE_FRAMEWORKS = Preferences

MyMockTweakPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk

# 把 PreferenceLoader 入口装到 /Library/PreferenceLoader/Preferences/
# rootless 环境下 THEOS_STAGING_DIR 会自动带 /var/jb 前缀，相对路径会被正确处理。
after-stage::
	@echo "[stage] PreferenceLoader entry"
	mkdir -p "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences"
	cp MyMockTweak.plist "$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MyMockTweak.plist"

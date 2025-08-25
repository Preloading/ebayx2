TARGET := iphone:clang:latest:6.0
INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EBayX

EBayX_FILES = Tweak.x
EBayX_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

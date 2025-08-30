TARGET := iphone:clang:latest:6.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EBayX

EBayX_FILES = Tweak.x
EBayX_CFLAGS = -fobjc-arc \
    -I$(THEOS_PROJECT_DIR)/libs/curl/headers \
    -I$(THEOS_PROJECT_DIR)/libs/openssl/headers
EBayX_LDFLAGS = \
    -L$(THEOS_PROJECT_DIR)/libs/curl/libs \
    -L$(THEOS_PROJECT_DIR)/libs/openssl/libs \
    -lcurl -lssl -lcrypto -lz -lnghttp2

include $(THEOS_MAKE_PATH)/tweak.mk

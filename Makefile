TARGET := iphone:clang:latest:6.0
INSTALL_TARGET_PROCESSES = eBay
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EBayX

# api stuff
export APP_ID = $(shell echo $$APP_ID)
export CERT_ID = $(shell echo $$CERT_ID)

EBayX_FILES = Tweak.x \
    $(wildcard $(THEOS_PROJECT_DIR)/sbjson/*.m) \
    base64/Base64.m \
    NewOAuthManager.m
EBayX_CFLAGS = -fobjc-arc \
    -I$(THEOS_PROJECT_DIR)/libs/curl/headers \
    -I$(THEOS_PROJECT_DIR)/libs/openssl/headers \
    -DAPP_ID=@\"$(APP_ID)\" \
    -DCERT_ID=@\"$(CERT_ID)\"
EBayX_LDFLAGS = \
    -L$(THEOS_PROJECT_DIR)/libs/curl/libs \
    -L$(THEOS_PROJECT_DIR)/libs/openssl/libs \
    -lcurl -lssl -lcrypto -lz -lnghttp2 \
#     -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

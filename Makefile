TARGET := iphone:clang:8.0:3.0
INSTALL_TARGET_PROCESSES = eBay
BUNDLE_NAME = dev.preloading.ebayx2
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = eBayX2

# api stuff
export APP_ID = $(shell echo $$APP_ID)
export CERT_ID = $(shell echo $$CERT_ID)

eBayX2_FILES = Tweak.x \
    curl_requests.x \
    finding_api.x \
    utils.m \
    $(wildcard $(THEOS_PROJECT_DIR)/sbjson/*.m) \
    base64/Base64.m \
    NewOAuthManager.m \
    polyfill.x
eBayX2_CFLAGS = -fobjc-arc \
    -lSystem.B \
    -lobjc.A \
    -I$(THEOS_PROJECT_DIR)/libs/curl/headers \
    -I$(THEOS_PROJECT_DIR)/libs/openssl/headers \
    -DAPP_ID=@\"$(APP_ID)\" \
    -DCERT_ID=@\"$(CERT_ID)\" \
    -Wno-deprecated-declarations
eBayX2_LDFLAGS = \
    -L$(THEOS_PROJECT_DIR)/libs/curl/libs \
    -L$(THEOS_PROJECT_DIR)/libs/openssl/libs \
    -lcurl -lssl -lcrypto -lz -lnghttp2 
#     -undefined dynamic_lookup
eBayX2_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

XCODEPROJ_NAME = Orion

Orion_XCODEFLAGS = LD_DYLIB_INSTALL_NAME=/Library/Frameworks/Orion.framework/Orion
Orion_XCODEFLAGS += DWARF_DSYM_FOLDER_PATH=$(THEOS_OBJ_DIR)/dSYMs

include $(THEOS_MAKE_PATH)/xcodeproj.mk

SDK_DIR = $(THEOS_PACKAGE_DIR)/Orion.framework
DSYM_DIR = $(SDK_DIR).dSYM

SUBPKG_0_ID = 12
SUBPKG_0_NAME = iOS 12-13
SUBPKG_0_FW = firmware (>= 12.2), firmware (<< 14.0)

SUBPKG_1_ID = 14
SUBPKG_1_NAME = iOS 14
SUBPKG_1_FW = firmware (>= 14.0), firmware (<< 16.0)

ifeq ($(SWIFT_VERSION_COMPUTED),)
export SWIFT_VERSION_COMPUTED := 1
export IS_OSS_SWIFT := $(shell swiftc --version 2>/dev/null | grep -q swiftlang || echo 1)
ifeq ($(IS_OSS_SWIFT),)
export APPLE_SWIFT_VERSION := $(shell swiftc --version 2>/dev/null | cut -d' ' -f4)
endif
endif

ifeq ($(SUBPKG),)
ifneq ($(IS_OSS_SWIFT),)
SUBPKG := 0
else
ifeq ($(call __vercmp,$(APPLE_SWIFT_VERSION),ge,5.3),1)
SUBPKG := 1
else
SUBPKG := 0
endif
endif
endif

override THEOS_PACKAGE_NAME := dev.theos.orion$(SUBPKG_$(SUBPKG)_ID)

before-package::
	$(ECHO_NOTHING)sed -i '' \
		-e 's/\$${SUBPKG_ID}/$(SUBPKG_$(SUBPKG)_ID)/g' \
		-e 's/\$${SUBPKG_NAME}/$(SUBPKG_$(SUBPKG)_NAME)/g' \
		-e 's/\$${SUBPKG_FW}/$(SUBPKG_$(SUBPKG)_FW)/g' \
		-e 's/\$${PKG_VERSION}/$(_THEOS_INTERNAL_PACKAGE_VERSION)/g' \
		$(THEOS_STAGING_DIR)/DEBIAN/control$(ECHO_END)

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_PACKAGE_DIR)$(ECHO_END)
	$(ECHO_NOTHING)rm -rf $(SDK_DIR) $(DSYM_DIR) $(THEOS_STAGING_DIR)/Library/Frameworks/Orion.framework/PrivateHeaders$(ECHO_END)
	$(ECHO_NOTHING)cp -a $(THEOS_STAGING_DIR)/Library/Frameworks/Orion.framework $(SDK_DIR)$(ECHO_END)
ifeq ($(_THEOS_FINAL_PACKAGE),$(_THEOS_TRUE))
	$(ECHO_NOTHING)cp -a $(THEOS_OBJ_DIR)/dSYMs/Orion.framework.dSYM $(DSYM_DIR)$(ECHO_END)
endif
	$(ECHO_NOTHING)xcrun tapi stubify $(SDK_DIR)/Orion$(ECHO_END)
	$(ECHO_NOTHING)if [[ -L $(SDK_DIR)/Orion ]]; then \
		ln -s Versions/Current/Orion.tbd $(SDK_DIR)/Orion.tbd; \
		rm $(SDK_DIR)/Versions/Current/Orion; \
	fi$(ECHO_END)
	$(ECHO_NOTHING)sed -i '' -e '/ORION_PRIVATE_MODULE_BEGIN/,/ORION_PRIVATE_MODULE_END/d' $(SDK_DIR)/Modules/module.modulemap$(ECHO_END)
	$(ECHO_NOTHING)rm $(SDK_DIR)/Orion $(SDK_DIR)/Modules/Orion.swiftmodule/*.swiftmodule$(ECHO_END)
	$(ECHO_NOTHING)rm -rf $(THEOS_STAGING_DIR)/Library/Frameworks/Orion.doccarchive $(THEOS_STAGING_DIR)/Library/Frameworks/Orion.framework/{Headers,Modules}$(ECHO_END)

.PHONY: vendor

vendor:: package
ifneq ($(_THEOS_FINAL_PACKAGE),$(_THEOS_TRUE))
	$(ECHO_NOTHING)$(PRINT_FORMAT_WARNING) "Installing debug build of Orion.framework into vendor. Did you forget to set FINALPACKAGE=1?" >&2$(ECHO_END)
endif
	$(ECHO_BEGIN)$(PRINT_FORMAT_MAGENTA) "Installing Orion.framework to $(THEOS_VENDOR_LIBRARY_PATH)"$(ECHO_END); $(ECHO_PIPEFAIL) ( \
	rm -rf $(THEOS_VENDOR_LIBRARY_PATH)/Orion.framework; \
	cp -a $(SDK_DIR) $(THEOS_VENDOR_LIBRARY_PATH); \
	$(ECHO_END)

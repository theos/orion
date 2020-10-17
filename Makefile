include $(THEOS)/makefiles/common.mk

XCODEPROJ_NAME = Orion

Orion_XCODEFLAGS = LD_DYLIB_INSTALL_NAME=/Library/Frameworks/Orion.framework/Orion

include $(THEOS_MAKE_PATH)/xcodeproj.mk

SDK_DIR = $(THEOS_PACKAGE_DIR)/Orion.framework

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_PACKAGE_DIR)$(ECHO_END)
	$(ECHO_NOTHING)rm -rf $(SDK_DIR)$(ECHO_END)
	$(ECHO_NOTHING)cp -a $(THEOS_STAGING_DIR)/Library/Frameworks/Orion.framework $(SDK_DIR)$(ECHO_END)
	$(ECHO_NOTHING)xcrun tapi stubify $(SDK_DIR)/Orion$(ECHO_END)
	$(ECHO_NOTHING)rm $(SDK_DIR)/Orion $(SDK_DIR)/Modules/Orion.swiftmodule/*.swiftmodule$(ECHO_END)
	$(ECHO_NOTHING)rm -rf $(THEOS_STAGING_DIR)/Library/Frameworks/Orion.framework/{Headers,Modules}$(ECHO_END)

.PHONY: vendor

vendor:: package
ifneq ($(_THEOS_FINAL_PACKAGE),$(_THEOS_TRUE))
	$(ECHO_NOTHING)$(PRINT_FORMAT_WARNING) "Installing debug build of Orion.framework into vendor. Did you forget to set FINALPACKAGE=1?" >&2$(ECHO_END)
endif
	$(ECHO_BEGIN)$(PRINT_FORMAT_MAGENTA) "Installing Orion.framework to $(THEOS_VENDOR_LIBRARY_PATH)"$(ECHO_END); $(ECHO_PIPEFAIL) ( \
	rm -rf $(THEOS_VENDOR_LIBRARY_PATH)/Orion.framework; \
	cp -a $(SDK_DIR) $(THEOS_VENDOR_LIBRARY_PATH); \
	$(ECHO_END)

#import <TargetConditionals.h>

#if !(TARGET_OS_MAC && !TARGET_OS_IPHONE)
#error This copy of Orion has only been compiled for macOS. Please check that you are targeting the right platform.
#endif

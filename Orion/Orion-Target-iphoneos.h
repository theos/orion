#import <TargetConditionals.h>

#if !(TARGET_OS_IOS && !TARGET_OS_SIMULATOR)
#error This copy of Orion has only been compiled for iOS. Please check that you are targeting the right platform.
#endif

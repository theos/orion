#import <objc/message.h>
#import "super.h"

extern void objc_msgSendSuper2(void);

void _orion_with_objc_super(id receiver, Class cls, void(^block)(void *super_struct, void *send)) {
    struct objc_super sup = { receiver, cls };
    block(&sup, objc_msgSendSuper2);
}

#ifndef __arm64__
extern void objc_msgSendSuper2_stret(void);
void _orion_with_objc_super_stret(id receiver, Class cls, void(^block)(void *super_struct, void *send)) {
    struct objc_super sup = { receiver, cls };
    block(&sup, objc_msgSendSuper2_stret);
}
#endif

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "orion_objcrt.h"

extern void objc_msgSendSuper2(struct objc_super *super, SEL _cmd);

// MARK: - Super

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

// MARK: - Dealloc

void _orion_call_dealloc(_orion_DeallocMethod method, const CFTypeRef *self, SEL _cmd) {
    method((__bridge __unsafe_unretained id)(*self), _cmd);
}

void _orion_call_super_dealloc(Class cls, const CFTypeRef *self, SEL _cmd) {
    struct objc_super sup = { (__bridge __unsafe_unretained id)(*self), cls };
    objc_msgSendSuper2(&sup, _cmd);
}

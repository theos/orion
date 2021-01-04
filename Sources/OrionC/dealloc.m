#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "dealloc.h"

extern void objc_msgSendSuper2(struct objc_super *super, SEL _cmd);

void _orion_call_dealloc(_orion_DeallocMethod method, const CFTypeRef *self, SEL _cmd) {
    method((__bridge __unsafe_unretained id)(*self), _cmd);
}

void _orion_call_super_dealloc(Class cls, const CFTypeRef *self, SEL _cmd) {
    struct objc_super sup = { (__bridge __unsafe_unretained id)(*self), cls };
    objc_msgSendSuper2(&sup, _cmd);
}

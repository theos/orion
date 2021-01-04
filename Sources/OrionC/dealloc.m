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

//_orion_DeallocMethod _orion_createDeallocMethod(SEL deallocSel, _orion_DeallocPolicy(^block)(id)) {
//    // without __unsafe_unretained we would strongly retain self and break the
//    // dealloc method
//    return (_orion_DeallocMethod)imp_implementationWithBlock(^(id __unsafe_unretained self) {
//        _orion_DeallocPolicy policy = block(self);
//        switch (policy.kind) {
//            case _orion_DeallocPolicyKindCallOrig:
//                ((_orion_DeallocMethod)policy.param)(self, deallocSel);
//                break;
//            case _orion_DeallocPolicyKindCallSupr:
//                objc_msgSendSuper2(&(struct objc_super) { self, (__bridge Class)policy.param }, deallocSel);
//                break;
//        }
//    });
//}

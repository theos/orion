#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (*_orion_DeallocMethod)(__unsafe_unretained id, SEL);
// we take a pointer because that way the CFTypeRef is imported as Unmanaged.
// This is necessary since we want to call dealloc without retaining the
// object beforehand.
void _orion_call_dealloc(_orion_DeallocMethod method, const CFTypeRef _Nonnull * _Nonnull self, SEL _cmd);
void _orion_call_super_dealloc(Class cls, const CFTypeRef _Nonnull * _Nonnull self, SEL _cmd);

// These functions underpin Orion's `supr` proxy. Don't call them yourself.
void _orion_with_objc_super(id receiver, Class cls, void(NS_NOESCAPE ^block)(void *super_struct, void *send));
#ifndef __arm64__
void _orion_with_objc_super_stret(id receiver, Class cls, void(NS_NOESCAPE ^block)(void *super_struct, void *send));
#endif

NS_ASSUME_NONNULL_END

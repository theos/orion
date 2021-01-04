#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (*_orion_DeallocMethod)(__unsafe_unretained id, SEL);

// we take a pointer because that way the CFTypeRef is imported as Unmanaged.
// This is necessary since we want to call dealloc without retaining the
// object beforehand.
void _orion_call_dealloc(_orion_DeallocMethod method, const CFTypeRef _Nonnull * _Nonnull self, SEL _cmd);
void _orion_call_super_dealloc(Class cls, const CFTypeRef _Nonnull * _Nonnull self, SEL _cmd);

NS_ASSUME_NONNULL_END

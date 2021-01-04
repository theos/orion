#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (*_orion_DeallocMethod)(__unsafe_unretained id, SEL);

//typedef NS_ENUM(NSInteger, _orion_DeallocPolicyKind) {
//    _orion_DeallocPolicyKindCallOrig,
//    _orion_DeallocPolicyKindCallSupr
//};
//
//typedef struct _orion_DeallocPolicy {
//    _orion_DeallocPolicyKind kind;
//    const void *param;
//} _orion_DeallocPolicy;

// we take a pointer because that way the CFTypeRef is imported as Unmanaged.
// This is necessary since we want to call dealloc without retaining the
// object beforehand.
void _orion_call_dealloc(_orion_DeallocMethod method, const CFTypeRef _Nonnull * _Nonnull self, SEL _cmd);
void _orion_call_super_dealloc(Class cls, const CFTypeRef _Nonnull * _Nonnull self, SEL _cmd);

//// returns a function pointer to a new dealloc method which delegates to `block`.
//// `block` is a function that accepts the `target`. It should return an `_orion_DeallocPolicy`
//// which determines what the next action should be. When `policy.kind` is `callOrig`, `param`
//// should be the original method's function pointer. When it's `callSupr`, `param` should be
//// the target class (note: NOT the superclass).
////
//// This should be used instead of declaring the full dealloc method in Swift, since Swift
//// could end up retaining the target until after the dealloc call, interfering with its
//// lifetime.
//_orion_DeallocMethod _orion_createDeallocMethod(SEL deallocSel, _orion_DeallocPolicy(^block)(id));

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

void _logos_with_objc_super(id receiver, Class cls, void(NS_NOESCAPE ^block)(void *super_struct, void *send));

#ifndef __arm64__
void _logos_with_objc_super_stret(id receiver, Class cls, void(NS_NOESCAPE ^block)(void *super_struct, void *send));
#endif

NS_ASSUME_NONNULL_END

#import "MyCopyClass.h"

@implementation MyCopyClass

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _x = 5;

    return self;
}

- (id)copy {
    MyCopyClass *cp = [MyCopyClass new];
    cp->_x = 10;
    return cp;
}

- (id)mutableCopy {
    MyCopyClass *cp = [MyCopyClass new];
    cp->_x = 99;
    return cp;
}

@end

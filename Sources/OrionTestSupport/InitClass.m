#import "InitClass.h"

@implementation InitClass

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    _initType = InitClassInitRegular;

    return self;
}

- (instancetype)initWithX:(int)x {
    self = [super init];
    if (!self) return nil;

    _initType = InitClassInitWithX;
    _x = x;

    return self;
}

@end

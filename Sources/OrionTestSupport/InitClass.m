#import "InitClass.h"

@implementation InitClass

- (instancetype)initWithX:(int)x {
    self = [super init];
    if (!self) return nil;

    _origInitCalled = YES;
    _x = x;

    return self;
}

@end

#import "BasicClass.h"

@implementation BasicClass

- (NSString *)someTestMethod {
    return @"Original test method";
}

- (NSString *)someTestMethodWithArgument:(int)arg {
    return [NSString stringWithFormat:@"Original test method with arg %i", arg];
}

+ (NSString *)someTestMethod2WithArgument:(int)arg {
    return [NSString stringWithFormat:@"Original test class method with arg %i", arg];
}

+ (NSString *)someTestMethod3 {
    return @"Base test class method";
}

- (BOOL)methodForNamedTest { return NO; }

+ (NSArray *)classMethodForNamedTestWithArgument:(NSString *)arg {
    return @[@"hello", [arg stringByAppendingString:@"!"]];
}

@end

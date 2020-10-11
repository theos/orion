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

- (NSString *)someDidActivateMethod {
    return @"Original did activate method";
}

- (NSString *)someUnhookedMethod {
    return @"Original unhooked method";
}

+ (NSString *)someTestMethod3 {
    return @"Base test class method";
}

- (BOOL)methodForNamedTest { return NO; }

+ (NSArray *)classMethodForNamedTestWithArgument:(NSString *)arg {
    return @[@"hello", [arg stringByAppendingString:@"!"]];
}

- (NSString *)subclassableTestMethod {
    return @"Subclassable test method";
}

+ (NSString *)subclassableTestMethod1 {
    return @"Subclassable test class method";
}

- (NSString *)subclassableNamedTestMethod {
    return @"Subclassable named test method";
}

+ (NSString *)subclassableNamedTestMethod1 {
    return @"Subclassable named test class method";
}

@end

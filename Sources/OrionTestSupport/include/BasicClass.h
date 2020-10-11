#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BasicClass : NSObject

- (NSString *)someTestMethod;
- (NSString *)someTestMethodWithArgument:(int)arg;
+ (NSString *)someTestMethod2WithArgument:(int)arg;

- (NSString *)someDidActivateMethod;
- (NSString *)someUnhookedMethod;

+ (NSString *)someTestMethod3; // for supr class method test

- (BOOL)methodForNamedTest;
+ (NSArray *)classMethodForNamedTestWithArgument:(NSString *)arg;

- (NSString *)subclassableTestMethod;
+ (NSString *)subclassableTestMethod1;

- (NSString *)subclassableNamedTestMethod;
+ (NSString *)subclassableNamedTestMethod1;

@end

NS_ASSUME_NONNULL_END

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BasicClass : NSObject

- (NSString *)someTestMethod;
- (NSString *)someTestMethodWithArgument:(int)arg;
+ (NSString *)someTestMethod2WithArgument:(int)arg;

- (BOOL)methodForNamedTest;
+ (NSArray *)classMethodForNamedTestWithArgument:(NSString *)arg;

@end

NS_ASSUME_NONNULL_END

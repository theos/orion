#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface InitClass : NSObject

@property (nonatomic) BOOL origInitCalled;
@property (nonatomic) int x;

- (instancetype)initWithX:(int)x NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

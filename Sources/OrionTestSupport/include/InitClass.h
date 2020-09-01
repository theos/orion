#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_CLOSED_ENUM(NSUInteger, InitClassInit) {
    InitClassInitNone = 0,
    InitClassInitRegular,
    InitClassInitWithX
};

@interface InitClass : NSObject

@property (nonatomic) InitClassInit initType;
@property (nonatomic) int x;

- (instancetype)initWithX:(int)x;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

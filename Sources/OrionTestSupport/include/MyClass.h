#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MyClass : NSObject

@property (nonatomic) size_t foo;
@property (nonatomic) size_t bar;
@property (nonatomic, nullable) NSString *baz;
@property (nonatomic, nullable) NSString *woz;

@end

NS_ASSUME_NONNULL_END

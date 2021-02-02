#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MyClass : NSObject

@property (nonatomic) size_t foo;
@property (nonatomic) size_t bar;
@property (nonatomic, nullable) NSString *baz;
@property (nonatomic, nullable) NSString *woz;
@property (nonatomic, readonly) NSString *hooked;

@property (nonatomic, nullable) id strongRef;
@property (nonatomic, nullable, weak) id weakRef;

@end

NS_ASSUME_NONNULL_END

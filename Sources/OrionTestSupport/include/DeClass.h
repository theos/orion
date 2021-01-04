#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DeWatcher <NSObject>

- (void)classWillDeallocateWithIdentifier:(NSString *)identifier cls:(Class)cls;

@end

@interface DeClass : NSObject

@property (nonatomic, class, nullable) id<DeWatcher> watcher;

@property (nonatomic) NSString *identifier;
- (instancetype)initWithIdentifier:(NSString *)identifier;

@end

@interface DeSubclass1 : DeClass
@end

@interface DeSubclass2 : DeClass
@end

NS_ASSUME_NONNULL_END

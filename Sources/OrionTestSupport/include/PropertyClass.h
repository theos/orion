#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PropertyClass : NSObject

// the "Value" is to avoid somehow interfering with objc's properties
- (size_t)getXValue;
- (void)setXValue:(size_t)x;

- (size_t)getYValue;
- (void)setYValue:(size_t)y;

@end

NS_ASSUME_NONNULL_END

#import "DeClass.h"

static id<DeWatcher> _watcher = nil;

@implementation DeClass

+ (id<DeWatcher>)watcher {
    return _watcher;
}

+ (void)setWatcher:(id<DeWatcher>)watcher {
    _watcher = watcher;
}

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _identifier = identifier;
    }
    return self;
}

- (void)dealloc {
    [_watcher classWillDeallocateWithIdentifier:self.identifier cls:[DeClass class]];
}

@end

@implementation DeSubclass1

- (void)dealloc {
    [_watcher classWillDeallocateWithIdentifier:self.identifier cls:[DeSubclass1 class]];
}

@end

@implementation DeSubclass2

- (void)dealloc {
    [_watcher classWillDeallocateWithIdentifier:self.identifier cls:[DeSubclass2 class]];
}

@end

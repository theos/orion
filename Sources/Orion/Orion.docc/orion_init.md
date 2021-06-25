# ``Orion/orion_init()``

Initializes Orion.

## Overview

If you are integrating Orion into a non-SPM project, you must call this during startup, ideally inside an `__attribute__((constructor))` C function.

> Important: Do **not** call this function yourself if you are integrating Orion through Swift Package Manager.
>
> Furthermore, if you are using an Orion-based Theos template, it likely already has code that calls this function.

## Example

The `tweak_swift` template in Theos comes with code similar to the following:

```objc
#import <Orion/Orion.h>

__attribute__((constructor)) static void init() {
    orion_init();
}
```

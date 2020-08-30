#include <stdbool.h>

// since LogosSwift is linked statically, this symbol should be found while linking;
// it's declared in the Swift companion file as @_cdecl("__logos_swift_constructor")
extern void __logos_swift_constructor(void);

// in order to not optimize out the constructor, we call it again from within Tweak.swift.
// has_called determines whether we're on that second call, and if so, does nothing.
static bool has_called = false;

__attribute__((constructor)) void __logos_swift_constructor_real() {
    if (!has_called) {
        has_called = true;
        __logos_swift_constructor();
    }
}

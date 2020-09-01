#include <stdbool.h>

// since Orion is linked statically, this symbol should be found while linking;
// it's declared in the Swift glue file as @_cdecl("__orion_constructor")
extern void __orion_constructor(void);

// in order to not optimize out the constructor, we call it again from within Tweak.swift.
// has_called determines whether we're on that second call, and if so, does nothing.
static bool has_called = false;

__attribute__((constructor)) void __orion_constructor_c() {
    if (!has_called) {
        has_called = true;
        __orion_constructor();
    }
}

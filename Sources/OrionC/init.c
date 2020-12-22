#if SWIFT_PACKAGE

#include <init.h>
#include <stdbool.h>

// in order to not optimize out the constructor, we call it again from within Tweak.swift.
// has_called determines whether we're on that second call, and if so, does nothing.
static bool has_called = false;

__attribute__((constructor)) void _orion_init_c() {
    if (!has_called) {
        has_called = true;
        orion_init();
    }
}

#endif

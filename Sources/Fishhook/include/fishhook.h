// This file serves as a "trampoline" which renames the fishhook API
// functions by defining the original names as macros before including
// the actual header. This prevents duplicate symbols if a project links
// with another copy of fishhook as well.
#define rebind_symbols orion_rebind_symbols
#define rebind_symbols_image orion_rebind_symbols_image

#if SWIFT_PACKAGE
// We need the symbols to be visible from Orion, which is a separate
// module
#define FISHHOOK_EXPORT
#include "fishhook_internal.h"
#else
#include <fishhook_internal.h>
#endif

#ifndef ORION_LIFECYCLE_H_
#define ORION_LIFECYCLE_H_

#include <orion_public.h>

// this is only used in SPM mode but guarding it behind
// a conditional confuses the compiler. Don't call it yourself.
void _orion_init_c(void);

#endif

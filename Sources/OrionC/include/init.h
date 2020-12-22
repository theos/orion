#ifndef INIT_H_
#define INIT_H_

// this is only required in SPM mode but guarding it behind
// a conditional confuses the compiler
void _orion_init_c(void);

// this symbol should always be found while linking; it's
// declared in the Orion glue file as @_cdecl("orion_init")
void orion_init(void);

#endif

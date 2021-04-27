#ifndef INIT_H_
#define INIT_H_

#ifdef __cplusplus
extern "C" {
#endif

// this is only used in SPM mode but guarding it behind
// a conditional confuses the compiler. Don't call it yourself.
void _orion_init_c(void);

// this symbol should always be found while linking; it's
// declared in the Orion glue file as @_cdecl("orion_init")
void orion_init(void);

#ifdef __cplusplus
}
#endif

#endif

#ifndef ORION_PUBLIC_H
#define ORION_PUBLIC_H

#ifdef __cplusplus
extern "C" {
#endif

// this symbol should always be found while linking; it's
// declared in the Orion glue file as @_cdecl("orion_init")
void orion_init(void);

#ifdef __cplusplus
}
#endif

#endif

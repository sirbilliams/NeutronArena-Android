/* Minimal stand-in for <SDL.h>: the OMT subset used by the importer only needs these few names (no window, no GL). */
#pragma once
#include <stdint.h>
#include <stdlib.h>
typedef uint32_t Uint32;
typedef uint8_t Uint8;
typedef uint16_t Uint16;
typedef int32_t Sint32;
struct SDL_Window; struct SDL_Surface;
typedef int SDL_bool;
#define SDL_TRUE 1
#define SDL_FALSE 0
#ifdef __cplusplus
extern "C" {
#endif
void SDL_Log(const char *fmt, ...);
Uint32 SDL_GetTicks(void);
char *SDL_GetPrefPath(const char *org, const char *app);
void SDL_free(void *p);
int SDL_SetClipboardText(const char *t);
SDL_bool SDL_HasClipboardText(void);
#ifdef __cplusplus
}
#endif

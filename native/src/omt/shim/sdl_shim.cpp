#include "SDL.h"
#include <stdio.h>
#include <stdarg.h>
#include <time.h>
#include <string.h>
extern "C" {
void SDL_Log(const char *, ...) {}
Uint32 SDL_GetTicks(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return (Uint32)(t.tv_sec * 1000 + t.tv_nsec / 1000000); }
char *SDL_GetPrefPath(const char *, const char *) { return NULL; }
void SDL_free(void *p) { free(p); }
int SDL_SetClipboardText(const char *) { return 0; }
SDL_bool SDL_HasClipboardText(void) { return SDL_FALSE; }
}

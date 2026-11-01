/* port: configurable controller input, shared with native regressions. LGPL. */
#ifndef OMEDIA_CONTROL_SETTINGS_H
#define OMEDIA_CONTROL_SETTINGS_H
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
namespace omcontrols {
inline int bounded(const char *value, int fallback, int lo, int hi) {
    if (!value || !*value) return fallback;
    char *end = NULL; long n = strtol(value, &end, 10);
    return *end || n < lo || n > hi ? fallback : (int)n;
}
inline float deadzone(float value, int percent) {
    if (value > 1) value = 1;
    if (value < -1) value = -1;
    const float d = percent / 100.0f;
    return value > d ? (value-d)/(1-d) : value < -d ? (value+d)/(1-d) : 0;
}
struct Settings {
    int movement, camera, speed, invert, map[15];
    Settings() : movement(0), camera(20), speed(100), invert(0) {
        for (int i=0; i<15; ++i) map[i]=i;
    }
    bool mapping(const char *s) {
        const int keys[8]={0,1,2,3,9,10,7,8};
        int values[8], used=0; const char *p=s;
        for (int i=0; i<8; ++i) {
            if (!p || !*p) return false;
            char *end=NULL; long n=strtol(p,&end,10);
            if (end==p || n<0 || n>10 || (i<7 ? *end!=',' : *end!=0)) return false;
            int k=0; for (; k<8 && keys[k]!=n; ++k) {}
            if (k==8 || (used & (1<<k))) return false;
            used |= 1<<k; values[i]=(int)n; p=end+1;
        }
        for (int i=0; i<8; ++i) map[keys[i]]=values[i];
        return true;
    }
    void environment() {
        movement=bounded(getenv("NEG_MOVE_DEADZONE"),0,0,35);
        camera=bounded(getenv("NEG_CAMERA_DEADZONE"),20,0,35);
        speed=bounded(getenv("NEG_CAMERA_SPEED"),100,25,250);
        invert=bounded(getenv("NEG_CAMERA_INVERT_Y"),0,0,1);
        mapping(getenv("NEG_CONTROL_MAP"));
    }
};
}
#endif

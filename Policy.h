#ifndef DOCKSENSE_POLICY_H
#define DOCKSENSE_POLICY_H
#include <stdbool.h>

typedef struct { double x, y, width, height; } DSRect;

static inline bool DSCovers(DSRect window, DSRect area) {
    // macOS Fill leaves an 8-point inset when window tiling margins are enabled.
    const double tolerance = 8.0;
    if (area.width <= 16 || area.height <= 16 || window.width < 100 || window.height < 100)
        return false;
    return window.x <= area.x + tolerance && window.y <= area.y + tolerance &&
        window.x + window.width >= area.x + area.width - tolerance &&
        window.y + window.height >= area.y + area.height - tolerance;
}

// A watchdog is still needed: some applications omit Accessibility notifications.
static inline double DSInterval(bool observing, bool suspended) {
    return suspended ? 0.0 : (observing ? 15.0 : 3.0);
}
#endif

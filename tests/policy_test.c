#include <assert.h>
#include <stdio.h>
#include "../Policy.h"

int main(void) {
    DSRect area = {0, 25, 1440, 800};
    assert(DSCovers(area, area));
    assert(DSCovers((DSRect){-5, 20, 1450, 810}, area));
    assert(DSCovers((DSRect){4, 29, 1432, 792}, area));
    assert(!DSCovers((DSRect){5, 25, 1440, 800}, area));
    assert(!DSCovers((DSRect){0, 25, 720, 800}, area));
    assert(!DSCovers((DSRect){0, 25, 1440, 400}, area));
    assert(!DSCovers((DSRect){1440, 25, 1440, 800}, area));
    assert(!DSCovers((DSRect){-1440, 25, 1440, 800}, area));
    DSRect leftMonitor = {-1920, -200, 1920, 1080};
    assert(DSCovers(leftMonitor, leftMonitor));
    assert(!DSCovers(area, leftMonitor));
    assert(!DSCovers((DSRect){0, 0, 90, 90}, (DSRect){0, 0, 90, 90}));
    assert(!DSCovers(area, (DSRect){0, 0, 0, 0}));
    assert(DSInterval(true, false) == 15);
    assert(DSInterval(false, false) == 3);
    assert(DSInterval(true, true) == 0);
    assert(DSInterval(false, true) == 0);
    puts("16 policy assertions passed.");
    return 0;
}

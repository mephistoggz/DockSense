#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <string.h>
#include "Policy.h"

// Undocumented API, inherited from the original project. Fail safely if unavailable.
static void (*setAutoHide)(Boolean);
static Boolean (*getAutoHide)(void);
static BOOL loadDockAPI(void) {
    setAutoHide = (void (*)(Boolean))dlsym(RTLD_DEFAULT, "CoreDockSetAutoHideEnabled");
    getAutoHide = (Boolean (*)(void))dlsym(RTLD_DEFAULT, "CoreDockGetAutoHideEnabled");
    return setAutoHide && getAutoHide;
}

static NSArray *visibleWindows(void) {
    NSArray *all = CFBridgingRelease(CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
    if (!all) return nil; // Do not mistake an enumeration failure for an empty desktop.
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *window in all) {
        if ([window[(id)kCGWindowLayer] intValue] != 0 ||
            [window[(id)kCGWindowAlpha] doubleValue] <= 0) continue;
        CGRect bounds;
        NSDictionary *value = window[(id)kCGWindowBounds];
        if (!value || !CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)value, &bounds)) continue;
        if (bounds.size.width >= 100 && bounds.size.height >= 100) [result addObject:window];
    }
    return result;
}

@interface DockSense : NSObject <NSApplicationDelegate> {
    AXObserverRef _observer;
    AXUIElementRef _observedApplication;
}
@property (strong) NSStatusItem *item;
@property (strong) NSMenuItem *modeItem;
@property (strong) NSTimer *watchdog;
@property (strong) NSTimer *pending;
@property (strong) NSMutableDictionary<NSNumber *, NSValue *> *areas;
@property (copy) NSString *displaySignature;
@property BOOL original;
@property BOOL started;
@property BOOL sleeping;
@property BOOL screenSleeping;
@property BOOL sessionInactive;
@property BOOL observing;
@property BOOL calibrated;
@property NSUInteger scans;
- (void)windowChanged;
@end

static void windowNotification(AXObserverRef observer, AXUIElementRef element,
                               CFStringRef notification, void *context) {
    (void)observer; (void)element; (void)notification;
    [(__bridge DockSense *)context windowChanged];
}

@implementation DockSense
- (BOOL)suspended { return self.sleeping || self.screenSleeping || self.sessionInactive; }

- (void)stopObserving {
    if (_observer) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(_observer), kCFRunLoopCommonModes);
        CFRelease(_observer);
        _observer = NULL;
    }
    if (_observedApplication) { CFRelease(_observedApplication); _observedApplication = NULL; }
    self.observing = NO;
}

- (void)observeFrontmost {
    [self stopObserving];
    if ([self suspended] || !AXIsProcessTrusted()) return;
    NSRunningApplication *front = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (!front || front.processIdentifier == NSProcessInfo.processInfo.processIdentifier) return;
    if (AXObserverCreate(front.processIdentifier, windowNotification, &_observer) != kAXErrorSuccess) return;
    _observedApplication = AXUIElementCreateApplication(front.processIdentifier);
    AXUIElementSetMessagingTimeout(_observedApplication, 0.15);
    CFStringRef appEvents[] = {kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification,
                              kAXMainWindowChangedNotification};
    for (size_t i = 0; i < sizeof(appEvents) / sizeof(appEvents[0]); i++)
        AXObserverAddNotification(_observer, _observedApplication, appEvents[i], (__bridge void *)self);
    CFTypeRef value = NULL;
    BOOL allSupported = YES;
    NSUInteger count = 0;
    if (AXUIElementCopyAttributeValue(_observedApplication, kAXWindowsAttribute, &value) == kAXErrorSuccess &&
        value && CFGetTypeID(value) == CFArrayGetTypeID()) {
        CFArrayRef windows = (CFArrayRef)value;
        for (CFIndex i = 0; i < CFArrayGetCount(windows); i++) {
            AXUIElementRef window = (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
            AXError moved = AXObserverAddNotification(_observer, window, kAXMovedNotification, (__bridge void *)self);
            AXError resized = AXObserverAddNotification(_observer, window, kAXResizedNotification, (__bridge void *)self);
            AXObserverAddNotification(_observer, window, kAXUIElementDestroyedNotification, (__bridge void *)self);
            AXObserverAddNotification(_observer, window, kAXWindowMiniaturizedNotification, (__bridge void *)self);
            AXObserverAddNotification(_observer, window, kAXWindowDeminiaturizedNotification, (__bridge void *)self);
            allSupported = allSupported && moved == kAXErrorSuccess && resized == kAXErrorSuccess;
            count++;
        }
    }
    if (value) CFRelease(value);
    self.observing = count > 0 && allSupported;
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(_observer), kCFRunLoopCommonModes);
}

- (void)armWatchdog {
    [self.watchdog invalidate];
    self.watchdog = nil;
    double interval = DSInterval(self.observing, [self suspended]);
    if (interval > 0) {
        self.watchdog = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(watchdogFired:)
                                            userInfo:nil repeats:NO];
        self.watchdog.tolerance = interval * 0.2;
        [NSRunLoop.mainRunLoop addTimer:self.watchdog forMode:NSRunLoopCommonModes];
    }
    self.modeItem.title = [self suspended] ? @"Kontroller duraklatıldı" :
        (self.observing ? @"Pencere olayları izleniyor" : @"Seyrek kontrol modu (3 sn)");
}

- (void)scheduleCheck {
    if ([self suspended] || self.pending) return;
    // Coalesce bursts without postponing indefinitely during a long window drag.
    self.pending = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(pendingFired:)
                                        userInfo:nil repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:self.pending forMode:NSRunLoopCommonModes];
}

- (void)windowChanged { [self scheduleCheck]; }
- (void)pendingFired:(NSTimer *)timer {
    (void)timer;
    self.pending = nil;
    if ([self suspended]) return;
    [self observeFrontmost];
    [self checkWindows];
    [self armWatchdog];
}
- (void)watchdogFired:(NSTimer *)timer {
    (void)timer;
    self.watchdog = nil;
    if ([self suspended]) return;
    [self observeFrontmost]; // Also detects permission changes and newly created windows.
    [self checkWindows];
    [self armWatchdog];
}

- (void)checkWindows {
    if ([self suspended] || NSScreen.screens.count == 0) return;
    if (!self.calibrated) {
        // Capture the usable area with Dock visible, even when launched with autohide on.
        if (getAutoHide()) {
            setAutoHide(false);
            [self scheduleCheck];
            return;
        }
        [self.areas removeAllObjects];
        for (NSScreen *screen in NSScreen.screens)
            self.areas[screen.deviceDescription[@"NSScreenNumber"]] = [NSValue valueWithRect:screen.visibleFrame];
        self.calibrated = YES;
    }
    NSArray *windows = visibleWindows();
    if (!windows) return;
    self.scans++;
    CGFloat height = NSScreen.screens.firstObject.frame.size.height;
    BOOL covered = NO;
    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *key = screen.deviceDescription[@"NSScreenNumber"];
        if (!getAutoHide()) self.areas[key] = [NSValue valueWithRect:screen.visibleFrame];
        NSValue *cached = self.areas[key];
        if (!cached) { self.calibrated = NO; [self scheduleCheck]; return; }
        NSRect rect = cached.rectValue;
        DSRect area = {rect.origin.x, height - NSMaxY(rect), rect.size.width, rect.size.height};
        for (NSDictionary *window in windows) {
            CGRect bounds;
            if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)window[(id)kCGWindowBounds], &bounds)) continue;
            DSRect candidate = {bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height};
            if (DSCovers(candidate, area)) { covered = YES; break; }
        }
        if (covered) break;
    }
    if (getAutoHide() != covered) setAutoHide(covered);
}

- (void)workspaceChanged:(NSNotification *)notification {
    (void)notification;
    [self scheduleCheck];
}
- (void)screensChanged:(NSNotification *)notification {
    (void)notification;
    // Dock visibility can affect screen notifications. Only recalibrate for an
    // actual display layout change, otherwise we could cause a show/hide loop.
    NSMutableString *signature = [NSMutableString string];
    for (NSScreen *screen in NSScreen.screens)
        [signature appendFormat:@"%@:%@:%g;", screen.deviceDescription[@"NSScreenNumber"],
            NSStringFromRect(screen.frame), (double)screen.backingScaleFactor];
    if ([signature isEqualToString:self.displaySignature]) return;
    self.displaySignature = signature;
    self.calibrated = NO;
    [self scheduleCheck];
}
- (void)powerChanged:(NSNotification *)notification {
    NSString *name = notification.name;
    if ([name isEqualToString:NSWorkspaceWillSleepNotification]) self.sleeping = YES;
    if ([name isEqualToString:NSWorkspaceDidWakeNotification]) self.sleeping = NO;
    if ([name isEqualToString:NSWorkspaceScreensDidSleepNotification]) self.screenSleeping = YES;
    if ([name isEqualToString:NSWorkspaceScreensDidWakeNotification]) self.screenSleeping = NO;
    if ([name isEqualToString:NSWorkspaceSessionDidResignActiveNotification]) self.sessionInactive = YES;
    if ([name isEqualToString:NSWorkspaceSessionDidBecomeActiveNotification]) self.sessionInactive = NO;
    if ([self suspended]) {
        [self.pending invalidate]; self.pending = nil;
        [self stopObserving];
        [self armWatchdog];
    } else {
        self.calibrated = NO;
        [self scheduleCheck];
    }
}
- (void)enableEvents:(id)sender {
    (void)sender;
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES});
    [self scheduleCheck];
}
- (void)showDiagnostics:(id)sender {
    (void)sender;
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"DockSense";
    alert.informativeText = [NSString stringWithFormat:
        @"%@\nBu oturumdaki pencere taraması: %lu\nErişilebilirlik izni: %@\nYedek kontrol aralığı: %.0f sn",
        self.modeItem.title, (unsigned long)self.scans, AXIsProcessTrusted() ? @"Var" : @"Yok",
        DSInterval(self.observing, [self suspended])];
    [alert runModal];
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    if (!loadDockAPI()) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"DockSense bu macOS sürümünde Dock'u kontrol edemiyor.";
        alert.informativeText = @"Dock ayarınız değiştirilmedi.";
        [alert runModal]; [NSApp terminate:nil]; return;
    }
    // Avoid two copies fighting over a system-wide preference.
    if ([NSRunningApplication runningApplicationsWithBundleIdentifier:NSBundle.mainBundle.bundleIdentifier].count > 1) {
        [NSApp terminate:nil]; return;
    }
    self.original = getAutoHide();
    self.started = YES;
    self.areas = [NSMutableDictionary dictionary];
    self.item = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.item.button.title = @"DS";
    self.item.button.toolTip = @"DockSense";
    NSMenu *menu = [NSMenu new];
    self.modeItem = [menu addItemWithTitle:@"DockSense başlatılıyor" action:NULL keyEquivalent:@""];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *enable = [menu addItemWithTitle:@"Verimli mod için erişim izni ver…" action:@selector(enableEvents:) keyEquivalent:@""];
    enable.target = self;
    NSMenuItem *diagnostics = [menu addItemWithTitle:@"Durum ve kontrol sayısı…" action:@selector(showDiagnostics:) keyEquivalent:@""];
    diagnostics.target = self;
    [menu addItemWithTitle:@"DockSense'ten Çık" action:@selector(terminate:) keyEquivalent:@"q"];
    self.item.menu = menu;
    NSNotificationCenter *workspace = NSWorkspace.sharedWorkspace.notificationCenter;
    for (NSString *name in @[NSWorkspaceDidActivateApplicationNotification, NSWorkspaceDidLaunchApplicationNotification,
         NSWorkspaceDidTerminateApplicationNotification, NSWorkspaceDidHideApplicationNotification,
         NSWorkspaceDidUnhideApplicationNotification, NSWorkspaceActiveSpaceDidChangeNotification])
        [workspace addObserver:self selector:@selector(workspaceChanged:) name:name object:nil];
    for (NSString *name in @[NSWorkspaceWillSleepNotification, NSWorkspaceDidWakeNotification,
         NSWorkspaceScreensDidSleepNotification, NSWorkspaceScreensDidWakeNotification,
         NSWorkspaceSessionDidResignActiveNotification, NSWorkspaceSessionDidBecomeActiveNotification])
        [workspace addObserver:self selector:@selector(powerChanged:) name:name object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(screensChanged:)
        name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [self screensChanged:nil];
}
- (void)applicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.pending invalidate];
    [self.watchdog invalidate];
    [self stopObserving];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (self.started) setAutoHide(self.original);
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--diagnose") == 0) {
            BOOL available = loadDockAPI();
            NSArray *windows = visibleWindows();
            printf("DockSense\nDock API: %s\nAccessibility: %s\nWindow enumeration: %s\nVisible windows: %lu\n",
                available ? "available" : "unavailable", AXIsProcessTrusted() ? "granted" : "not granted",
                windows ? "ok" : "failed", (unsigned long)windows.count);
            return available && windows ? 0 : 1; // Read-only: never changes the Dock preference.
        }
        NSApplication *app = NSApplication.sharedApplication;
        DockSense *delegate = [DockSense new];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}

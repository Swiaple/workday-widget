#import <Cocoa/Cocoa.h>

FOUNDATION_EXPORT void WorkStyleWindowAsGlass(NSWindow *window);
FOUNDATION_EXPORT void WorkPositionWindowOnScreen(NSWindow *window, NSScreen *screen);
FOUNDATION_EXPORT void WorkPrepareModalWindowForSmoothPresentation(NSWindow *window, NSScreen *screen);
FOUNDATION_EXPORT NSModalResponse WorkRunGlassAlert(NSAlert *alert, NSScreen *screen);

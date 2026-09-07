#import "WindowStyling.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const GlassBackgroundIdentifier = @"workday.glass-background";

void WorkStyleWindowAsGlass(NSWindow *window) {
    if (!window) return;
    window.animationBehavior = NSWindowAnimationBehaviorNone;
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    window.opaque = NO;
    window.backgroundColor = [NSColor colorWithWhite:0.08 alpha:0.94];
    window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    NSView *content = window.contentView;
    if (!content) return;
    for (NSView *view in content.subviews) {
        if ([view.identifier isEqualToString:GlassBackgroundIdentifier]) return;
    }
    NSVisualEffectView *effect = [[NSVisualEffectView alloc] initWithFrame:content.bounds];
    effect.identifier = GlassBackgroundIdentifier;
    effect.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    effect.material = NSVisualEffectMaterialHUDWindow;
    effect.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effect.state = NSVisualEffectStateActive;
    effect.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    [content addSubview:effect positioned:NSWindowBelow relativeTo:nil];
}

static NSPoint WorkCenteredOrigin(NSWindow *window, NSScreen *screen) {
    NSRect visible = screen.visibleFrame;
    NSRect frame = window.frame;
    NSPoint origin = NSMakePoint(NSMidX(visible) - NSWidth(frame) / 2.0,
                                 NSMidY(visible) - NSHeight(frame) / 2.0);
    origin.x = MIN(NSMaxX(visible) - NSWidth(frame), MAX(NSMinX(visible), origin.x));
    origin.y = MIN(NSMaxY(visible) - NSHeight(frame), MAX(NSMinY(visible), origin.y));
    return origin;
}

void WorkPositionWindowOnScreen(NSWindow *window, NSScreen *screen) {
    if (!window || !screen) return;
    void (^positionNow)(void) = ^{
        [window setFrameOrigin:WorkCenteredOrigin(window, screen)];
    };
    positionNow();
    // NSAlert and NSOpenPanel may center themselves again when their modal loop
    // starts. Reapply the target screen on the next main-loop turn.
    dispatch_async(dispatch_get_main_queue(), positionNow);
}

void WorkPrepareModalWindowForSmoothPresentation(NSWindow *window, NSScreen *screen) {
    if (!window || !screen) return;
    WorkStyleWindowAsGlass(window);
    window.alphaValue = 0;
    [window setFrameOrigin:WorkCenteredOrigin(window, screen)];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSPoint destination = WorkCenteredOrigin(window, screen);
        BOOL reduceMotion = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
        NSPoint start = reduceMotion ? destination : NSMakePoint(destination.x, destination.y - 7);
        [window setFrameOrigin:start];
        [window displayIfNeeded];
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = reduceMotion ? 0.12 : 0.20;
            context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            window.animator.alphaValue = 1.0;
            if (!reduceMotion) [window.animator setFrameOrigin:destination];
        } completionHandler:nil];
    });
}

NSModalResponse WorkRunGlassAlert(NSAlert *alert, NSScreen *screen) {
    NSWindow *window = alert.window;
    window.level = NSModalPanelWindowLevel;
    WorkPrepareModalWindowForSmoothPresentation(window, screen);
    return [alert runModal];
}

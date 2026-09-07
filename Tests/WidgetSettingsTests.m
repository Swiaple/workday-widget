#import <Cocoa/Cocoa.h>
#import "WidgetSettings.h"

static void Assert(BOOL condition, NSString *message) {
    if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}

int main(void) {
    @autoreleasepool {
        WidgetSettings *settings = [[WidgetSettings alloc] init];
        settings.durationMinutes = 7 * 60 + 20;
        settings.backgroundMode = WidgetBackgroundModeBlurredImage;
        settings.cropZoom = 1.6;
        settings.cropOffsetX = 0.12;
        settings.cropOffsetY = -0.08;

        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:16 bitsPerSample:8
            samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace
            bytesPerRow:0 bitsPerPixel:0];
        NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(32, 16)];
        [image addRepresentation:rep];
        Assert([settings saveOriginalImage:image], @"original background is copied into app storage");
        Assert([settings saveCroppedImage:image], @"cropped background is saved atomically");
        [settings synchronize];

        WidgetSettings *reloaded = [[WidgetSettings alloc] init];
        Assert(reloaded.durationMinutes == 7 * 60 + 20, @"custom schedule survives reload");
        Assert(reloaded.backgroundMode == WidgetBackgroundModeBlurredImage, @"background mode survives reload");
        Assert(fabs(reloaded.cropZoom - 1.6) < 0.001, @"crop zoom survives reload");
        Assert(reloaded.hasCustomImage, @"saved custom background is available after reload");
        NSLog(@"PASS: WidgetSettingsTests");
    }
    return 0;
}

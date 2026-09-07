#import <Cocoa/Cocoa.h>
#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "WorkRecordStore.h"
#import "HistoryWindowController.h"
#import "WidgetSettings.h"
#import "WindowStyling.h"

@interface ClickableVisualEffectView : NSView
@property (nonatomic, copy) void (^onClick)(void);
@property (nonatomic, copy) void (^onMove)(void);
@property (nonatomic, copy) NSMenu *(^contextMenuProvider)(void);
@property (nonatomic) NSPoint mouseDownScreenPoint;
@property (nonatomic) NSPoint windowDownOrigin;
@property (nonatomic) BOOL didDrag;
@end

@interface BackgroundCropView : NSView
@property (nonatomic, strong) NSImage *image;
@property (nonatomic) CGFloat zoom;
@property (nonatomic) CGFloat offsetX;
@property (nonatomic) CGFloat offsetY;
@property (nonatomic) NSPoint lastDragPoint;
- (NSImage *)croppedImageWithPixelSize:(NSSize)size;
@end

@implementation BackgroundCropView
- (BOOL)isFlipped { return YES; }
- (void)setImage:(NSImage *)image { _image = image; [self setNeedsDisplay:YES]; }
- (void)setZoom:(CGFloat)zoom { _zoom = MIN(3.0, MAX(1.0, zoom)); [self clampOffsets]; [self setNeedsDisplay:YES]; }
- (NSRect)imageRectForBounds:(NSRect)bounds {
    if (!self.image || self.image.size.width <= 0 || self.image.size.height <= 0) return NSZeroRect;
    CGFloat scale = MAX(NSWidth(bounds) / self.image.size.width,
                        NSHeight(bounds) / self.image.size.height) * MAX(1.0, self.zoom);
    NSSize drawn = NSMakeSize(self.image.size.width * scale, self.image.size.height * scale);
    CGFloat x = NSMidX(bounds) - drawn.width / 2.0 + self.offsetX * NSWidth(bounds);
    CGFloat y = NSMidY(bounds) - drawn.height / 2.0 + self.offsetY * NSHeight(bounds);
    return NSMakeRect(x, y, drawn.width, drawn.height);
}
- (void)clampOffsets {
    if (!self.image || NSWidth(self.bounds) <= 0 || NSHeight(self.bounds) <= 0) return;
    NSRect imageRect = [self imageRectForBounds:self.bounds];
    CGFloat maxX = MAX(0, (NSWidth(imageRect) - NSWidth(self.bounds)) / 2.0) / NSWidth(self.bounds);
    CGFloat maxY = MAX(0, (NSHeight(imageRect) - NSHeight(self.bounds)) / 2.0) / NSHeight(self.bounds);
    self.offsetX = MIN(maxX, MAX(-maxX, self.offsetX));
    self.offsetY = MIN(maxY, MAX(-maxY, self.offsetY));
}
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithWhite:0.10 alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12] fill];
    if (!self.image) {
        NSDictionary *attributes = @{ NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightMedium],
                                      NSForegroundColorAttributeName: [NSColor.whiteColor colorWithAlphaComponent:0.55] };
        NSString *message = @"选择图片后，可在这里拖动取景";
        NSSize size = [message sizeWithAttributes:attributes];
        [message drawAtPoint:NSMakePoint((NSWidth(self.bounds) - size.width) / 2.0,
                                         (NSHeight(self.bounds) - size.height) / 2.0)
             withAttributes:attributes];
        return;
    }
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:12 yRadius:12] addClip];
    [self.image drawInRect:[self imageRectForBounds:self.bounds]
                  fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    [[NSColor.whiteColor colorWithAlphaComponent:0.35] setStroke];
    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5) xRadius:12 yRadius:12];
    border.lineWidth = 1;
    [border stroke];
}
- (void)mouseDown:(NSEvent *)event { self.lastDragPoint = [self convertPoint:event.locationInWindow fromView:nil]; }
- (void)mouseDragged:(NSEvent *)event {
    if (!self.image) return;
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    self.offsetX += (point.x - self.lastDragPoint.x) / NSWidth(self.bounds);
    self.offsetY += (point.y - self.lastDragPoint.y) / NSHeight(self.bounds);
    self.lastDragPoint = point;
    [self clampOffsets];
    [self setNeedsDisplay:YES];
}
- (NSImage *)croppedImageWithPixelSize:(NSSize)size {
    if (!self.image) return nil;
    NSInteger width = (NSInteger)size.width;
    NSInteger height = (NSInteger)size.height;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8
        samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace
        bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = context;
    NSRect target = NSMakeRect(0, 0, width, height);
    CGFloat scale = MAX(NSWidth(target) / self.image.size.width,
                        NSHeight(target) / self.image.size.height) * MAX(1.0, self.zoom);
    NSSize drawn = NSMakeSize(self.image.size.width * scale, self.image.size.height * scale);
    NSRect imageRect = NSMakeRect(NSMidX(target) - drawn.width / 2.0 + self.offsetX * NSWidth(target),
                                  NSMidY(target) - drawn.height / 2.0 - self.offsetY * NSHeight(target),
                                  drawn.width, drawn.height);
    [self.image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    NSImage *result = [[NSImage alloc] initWithSize:size];
    [result addRepresentation:rep];
    return result;
}
@end

@implementation ClickableVisualEffectView
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    return [hit isKindOfClass:NSButton.class] ? hit : self;
}
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (void)mouseDown:(NSEvent *)event {
    self.mouseDownScreenPoint = NSEvent.mouseLocation;
    self.windowDownOrigin = self.window.frame.origin;
    self.didDrag = NO;
}
- (void)mouseDragged:(NSEvent *)event {
    NSPoint current = NSEvent.mouseLocation;
    CGFloat dx = current.x - self.mouseDownScreenPoint.x;
    CGFloat dy = current.y - self.mouseDownScreenPoint.y;
    if (!self.didDrag && hypot(dx, dy) < 5.0) return;
    self.didDrag = YES;
    [self.window setFrameOrigin:NSMakePoint(self.windowDownOrigin.x + dx, self.windowDownOrigin.y + dy)];
}
- (void)mouseUp:(NSEvent *)event {
    NSPoint current = NSEvent.mouseLocation;
    CGFloat distance = hypot(current.x - self.mouseDownScreenPoint.x, current.y - self.mouseDownScreenPoint.y);
    if (self.didDrag) {
        [self.window saveFrameUsingName:@"WorkdayWidgetPosition"];
        if (self.onMove) self.onMove();
    }
    else if (distance < 5.0 && event.clickCount == 1 && self.onClick) self.onClick();
}
- (void)rightMouseDown:(NSEvent *)event {
    if (!self.contextMenuProvider) return;
    NSMenu *menu = self.contextMenuProvider();
    if (menu) [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}
@end

@interface WorkProgressView : NSView
@property (nonatomic) CGFloat regularProgress;
@property (nonatomic) CGFloat overtimeProgress;
@property (nonatomic) BOOL hasRecord;
@end

@implementation WorkProgressView
- (BOOL)isOpaque { return NO; }
- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect track = NSInsetRect(self.bounds, 0.5, 0.5);
    CGFloat radius = NSHeight(track) / 2.0;
    [[NSColor.whiteColor colorWithAlphaComponent:0.14] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:track xRadius:radius yRadius:radius] fill];
    if (!self.hasRecord) return;

    CGFloat regularEnd = NSWidth(track) * 0.82;
    CGFloat greenWidth = regularEnd * MIN(1.0, MAX(0.0, self.regularProgress));
    if (greenWidth > 0.5) {
        NSRect green = NSMakeRect(NSMinX(track), NSMinY(track), greenWidth, NSHeight(track));
        [NSColor.systemGreenColor setFill];
        [[NSBezierPath bezierPathWithRoundedRect:green xRadius:radius yRadius:radius] fill];
    }
    CGFloat redWidth = (NSWidth(track) - regularEnd) * MIN(1.0, MAX(0.0, self.overtimeProgress));
    if (redWidth > 0.5) {
        NSRect red = NSMakeRect(NSMinX(track) + regularEnd, NSMinY(track), redWidth, NSHeight(track));
        CGFloat redStrength = 0.34 + MIN(1.0, MAX(0.0, self.overtimeProgress)) * 0.66;
        [[NSColor.systemRedColor colorWithAlphaComponent:redStrength] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:red xRadius:radius yRadius:radius] fill];
    }
    [[NSColor.whiteColor colorWithAlphaComponent:0.38] setStroke];
    NSBezierPath *marker = [NSBezierPath bezierPath];
    marker.lineWidth = 0.7;
    [marker moveToPoint:NSMakePoint(NSMinX(track) + regularEnd, NSMinY(track) - 1)];
    [marker lineToPoint:NSMakePoint(NSMinX(track) + regularEnd, NSMaxY(track) + 1)];
    [marker stroke];
}
@end

@interface WidgetPanel : NSPanel @end
@implementation WidgetPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (nonatomic, strong) WorkRecordStore *store;
@property (nonatomic, strong) WidgetSettings *settings;
@property (nonatomic, strong) HistoryWindowController *historyController;
@property (nonatomic, strong) WidgetPanel *panel;
@property (nonatomic, strong) NSTextField *rangeLabel;
@property (nonatomic, strong) NSTextField *hintLabel;
@property (nonatomic, strong) NSView *statusDot;
@property (nonatomic, strong) WorkProgressView *progressView;
@property (nonatomic, strong) NSVisualEffectView *backgroundEffectView;
@property (nonatomic, strong) NSImageView *backgroundImageView;
@property (nonatomic, strong) NSView *backgroundTintView;
@property (nonatomic, strong) BackgroundCropView *settingsCropView;
@property (nonatomic, strong) NSSlider *settingsZoomSlider;
@property (nonatomic, strong) NSSegmentedControl *settingsModeControl;
@property (nonatomic, strong) NSTextField *settingsHoursField;
@property (nonatomic, strong) NSTextField *settingsMinutesField;
@property (nonatomic, strong) NSButton *settingsRemoveButton;
@property (nonatomic, strong) NSImage *pendingSettingsImage;
@property (nonatomic) BOOL pendingRemoveBackground;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation AppDelegate
- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _store = [[WorkRecordStore alloc] init];
    _settings = [[WidgetSettings alloc] init];
    _historyController = [[HistoryWindowController alloc] initWithStore:_store];
    __weak typeof(self) weakSelf = self;
    _historyController.onRecordsChanged = ^{ [weakSelf refreshDisplay]; };
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self buildWidget];
    [self refreshDisplay];
    __weak typeof(self) weakSelf = self;
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:30 repeats:YES block:^(NSTimer *timer) {
        [weakSelf refreshDisplay];
    }];
}

- (void)buildWidget {
    NSSize size = NSMakeSize(224, 88);
    self.panel = [[WidgetPanel alloc] initWithContentRect:NSMakeRect(0, 0, size.width, size.height)
                                                styleMask:NSWindowStyleMaskBorderless
                                                  backing:NSBackingStoreBuffered defer:NO];
    self.panel.opaque = NO;
    self.panel.backgroundColor = NSColor.clearColor;
    // The automatic window shadow follows the rectangular window frame and
    // leaves visible corner ghosts around a transparent rounded widget.
    self.panel.hasShadow = NO;
    self.panel.movableByWindowBackground = NO;
    self.panel.hidesOnDeactivate = NO;
    self.panel.level = (NSWindowLevel)(CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) + 1);
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                    NSWindowCollectionBehaviorStationary |
                                    NSWindowCollectionBehaviorIgnoresCycle;
    [self.panel setFrameAutosaveName:@"WorkdayWidgetPosition"];

    NSView *roundedContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
    roundedContainer.wantsLayer = YES;
    roundedContainer.layer.cornerRadius = 16;
    roundedContainer.layer.masksToBounds = YES;
    self.panel.contentView = roundedContainer;

    self.backgroundEffectView = [[NSVisualEffectView alloc] initWithFrame:roundedContainer.bounds];
    self.backgroundEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.backgroundEffectView.material = NSVisualEffectMaterialHUDWindow;
    self.backgroundEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    self.backgroundEffectView.state = NSVisualEffectStateActive;
    self.backgroundEffectView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    [roundedContainer addSubview:self.backgroundEffectView];

    self.backgroundImageView = [[NSImageView alloc] initWithFrame:roundedContainer.bounds];
    self.backgroundImageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.backgroundImageView.imageScaling = NSImageScaleAxesIndependently;
    self.backgroundImageView.wantsLayer = YES;
    [roundedContainer addSubview:self.backgroundImageView];

    self.backgroundTintView = [[NSView alloc] initWithFrame:roundedContainer.bounds];
    self.backgroundTintView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.backgroundTintView.wantsLayer = YES;
    [roundedContainer addSubview:self.backgroundTintView];

    ClickableVisualEffectView *root = [[ClickableVisualEffectView alloc] initWithFrame:roundedContainer.bounds];
    root.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    root.wantsLayer = YES;
    root.layer.cornerRadius = 16;
    root.layer.masksToBounds = YES;
    root.layer.borderWidth = 0.5;
    root.layer.borderColor = [NSColor.whiteColor colorWithAlphaComponent:0.16].CGColor;
    __weak typeof(self) weakSelf = self;
    root.onClick = ^{ [weakSelf showStartTimeEditor]; };
    root.onMove = ^{ [weakSelf saveWidgetPlacement]; };
    root.contextMenuProvider = ^NSMenu *{ return [weakSelf makeContextMenu]; };
    [roundedContainer addSubview:root];
    [self applyWidgetBackground];

    self.statusDot = [[NSView alloc] init];
    self.statusDot.wantsLayer = YES;
    self.statusDot.layer.cornerRadius = 5;
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;

    self.hintLabel = [NSTextField labelWithString:@"今日工时"];
    self.hintLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.hintLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.70];
    self.hintLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.rangeLabel = [NSTextField labelWithString:@"点击设置上班时间"];
    self.rangeLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.rangeLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.90];
    self.rangeLabel.maximumNumberOfLines = 1;
    self.rangeLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.rangeLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.progressView = [[WorkProgressView alloc] init];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *historyButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"calendar" accessibilityDescription:@"工作记录"]
                                                  target:self action:@selector(showHistory:)];
    historyButton.bordered = NO;
    historyButton.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.58];
    historyButton.toolTip = @"查看工作记录";
    historyButton.translatesAutoresizingMaskIntoConstraints = NO;

    [root addSubview:self.statusDot]; [root addSubview:self.hintLabel];
    [root addSubview:self.rangeLabel]; [root addSubview:historyButton]; [root addSubview:self.progressView];
    [NSLayoutConstraint activateConstraints:@[
        [self.statusDot.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:15],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.rangeLabel.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:10],
        [self.statusDot.heightAnchor constraintEqualToConstant:10],
        [self.hintLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:11],
        [self.hintLabel.topAnchor constraintEqualToAnchor:root.topAnchor constant:13],
        [self.rangeLabel.leadingAnchor constraintEqualToAnchor:self.hintLabel.leadingAnchor],
        [self.rangeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:historyButton.leadingAnchor constant:-8],
        [self.rangeLabel.topAnchor constraintEqualToAnchor:self.hintLabel.bottomAnchor constant:3],
        [historyButton.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-12],
        [historyButton.centerYAnchor constraintEqualToAnchor:self.rangeLabel.centerYAnchor],
        [historyButton.widthAnchor constraintEqualToConstant:24],
        [historyButton.heightAnchor constraintEqualToConstant:24],
        [self.progressView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:15],
        [self.progressView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-15],
        [self.progressView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12],
        [self.progressView.heightAnchor constraintEqualToConstant:7]
    ]];

    BOOL restored = [self restoreWidgetPlacementWithSize:size];
    if (!restored) {
        restored = [self.panel setFrameUsingName:@"WorkdayWidgetPosition"];
        if (restored) {
            NSRect restoredFrame = self.panel.frame;
            restoredFrame.size = size;
            [self.panel setFrame:restoredFrame display:NO];
            restored = [self screenContainingFrame:self.panel.frame] != nil;
            if (restored) [self saveWidgetPlacement];
        }
    }
    if (!restored) [self positionPanel:self.panel onScreen:NSScreen.mainScreen size:size];
    [self.panel orderFrontRegardless];
}

- (void)applyWidgetBackground {
    BOOL custom = self.settings.hasCustomImage && self.settings.backgroundMode != WidgetBackgroundModeSystemGlass;
    self.backgroundEffectView.hidden = custom;
    self.backgroundImageView.hidden = !custom;
    self.backgroundTintView.hidden = !custom;
    self.backgroundImageView.layer.filters = nil;
    self.backgroundImageView.frame = self.backgroundImageView.superview.bounds;
    if (!custom) return;

    self.backgroundImageView.image = self.settings.croppedImage;
    if (self.settings.backgroundMode == WidgetBackgroundModeBlurredImage) {
        CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
        [blur setDefaults];
        [blur setValue:@12.0 forKey:kCIInputRadiusKey];
        self.backgroundImageView.layer.filters = @[blur];
        self.backgroundImageView.frame = NSInsetRect(self.backgroundImageView.superview.bounds, -10, -10);
        self.backgroundTintView.layer.backgroundColor = [NSColor.blackColor colorWithAlphaComponent:0.28].CGColor;
    } else {
        self.backgroundTintView.layer.backgroundColor = NSColor.clearColor.CGColor;
    }
}

- (NSScreen *)screenContainingPoint:(NSPoint)point {
    for (NSScreen *screen in NSScreen.screens) if (NSPointInRect(point, screen.frame)) return screen;
    return nil;
}
- (NSScreen *)screenContainingFrame:(NSRect)frame {
    NSPoint center = NSMakePoint(NSMidX(frame), NSMidY(frame));
    for (NSScreen *screen in NSScreen.screens) if (NSPointInRect(center, screen.frame)) return screen;
    NSScreen *best = nil;
    CGFloat largestArea = 0;
    for (NSScreen *screen in NSScreen.screens) {
        NSRect intersection = NSIntersectionRect(frame, screen.frame);
        CGFloat area = NSWidth(intersection) * NSHeight(intersection);
        if (area > largestArea) { largestArea = area; best = screen; }
    }
    return best;
}
- (NSScreen *)widgetScreen {
    return self.panel.screen ?: [self screenContainingFrame:self.panel.frame] ?: NSScreen.mainScreen;
}
- (NSString *)identifierForScreen:(NSScreen *)screen {
    NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
    if (!number) return nil;
    CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID((CGDirectDisplayID)number.unsignedIntValue);
    if (!uuid) return number.stringValue;
    NSString *identifier = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));
    CFRelease(uuid);
    return identifier;
}
- (void)saveWidgetPlacement {
    NSScreen *screen = self.widgetScreen;
    if (!screen) return;
    NSRect visible = screen.visibleFrame;
    CGFloat availableWidth = MAX(1, NSWidth(visible) - NSWidth(self.panel.frame));
    CGFloat availableHeight = MAX(1, NSHeight(visible) - NSHeight(self.panel.frame));
    CGFloat x = (NSMinX(self.panel.frame) - NSMinX(visible)) / availableWidth;
    CGFloat y = (NSMinY(self.panel.frame) - NSMinY(visible)) / availableHeight;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:[self identifierForScreen:screen] forKey:@"widget.displayIdentifier"];
    [defaults setDouble:MIN(1, MAX(0, x)) forKey:@"widget.positionX"];
    [defaults setDouble:MIN(1, MAX(0, y)) forKey:@"widget.positionY"];
}
- (BOOL)restoreWidgetPlacementWithSize:(NSSize)size {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *identifier = [defaults stringForKey:@"widget.displayIdentifier"];
    if (!identifier) return NO;
    NSScreen *target = nil;
    for (NSScreen *screen in NSScreen.screens) {
        if ([[self identifierForScreen:screen] isEqualToString:identifier]) { target = screen; break; }
    }
    if (!target) return NO;
    NSRect visible = target.visibleFrame;
    CGFloat x = [defaults doubleForKey:@"widget.positionX"];
    CGFloat y = [defaults doubleForKey:@"widget.positionY"];
    NSPoint origin = NSMakePoint(NSMinX(visible) + MIN(1, MAX(0, x)) * MAX(0, NSWidth(visible) - size.width),
                                 NSMinY(visible) + MIN(1, MAX(0, y)) * MAX(0, NSHeight(visible) - size.height));
    [self.panel setFrame:NSMakeRect(origin.x, origin.y, size.width, size.height) display:NO];
    return YES;
}
- (void)positionPanel:(NSPanel *)panel onScreen:(NSScreen *)screen size:(NSSize)size {
    if (!screen) return;
    NSRect visible = screen.visibleFrame;
    [panel setFrameOrigin:NSMakePoint(NSMaxX(visible) - size.width - 24,
                                      NSMaxY(visible) - size.height - 24)];
}

- (void)refreshDisplay {
    NSString *dateKey = self.store.relevantDateKey;
    NSDictionary *record = [self.store recordForDateKey:dateKey];
    if (!record) {
        self.hintLabel.stringValue = @"今日工时";
        self.rangeLabel.stringValue = @"点击设置上班时间";
        self.rangeLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
        self.rangeLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.68];
        self.statusDot.layer.backgroundColor = NSColor.systemGreenColor.CGColor;
        self.progressView.hasRecord = NO;
        self.progressView.toolTip = @"设置上班时间后显示今日工时进度";
    } else {
        NSInteger start = [record[@"start"] integerValue];
        BOOL completed = [record[@"completed"] boolValue];
        NSInteger standardDuration = record[@"plannedDuration"]
            ? [record[@"plannedDuration"] integerValue] : WorkDurationMinutes;
        NSInteger plannedEnd = [record[@"plannedEnd"] integerValue];
        NSInteger elapsed = completed ? [record[@"actualEnd"] integerValue] - start
                                      : [self liveElapsedMinutesForDateKey:dateKey startMinutes:start];
        elapsed = MAX(0, elapsed);
        NSInteger overtime = MAX(0, elapsed - standardDuration);
        NSInteger shownEnd = completed ? [record[@"actualEnd"] integerValue] : plannedEnd;
        if (completed) {
            self.hintLabel.stringValue = [NSString stringWithFormat:@"今日工时 · %@", WorkFormatDuration(elapsed)];
            self.rangeLabel.stringValue = [NSString stringWithFormat:@"%@–%@", WorkFormatClock(start), WorkFormatClock(shownEnd)];
        } else if (overtime > 0) {
            self.hintLabel.stringValue = [NSString stringWithFormat:@"加班中 · +%@", WorkFormatDuration(overtime)];
            self.rangeLabel.stringValue = [NSString stringWithFormat:@"%@–", WorkFormatClock(plannedEnd)];
        } else {
            self.hintLabel.stringValue = [NSString stringWithFormat:@"今日工时 · 已进行 %@", WorkFormatDuration(elapsed)];
            self.rangeLabel.stringValue = [NSString stringWithFormat:@"%@–%@", WorkFormatClock(start), WorkFormatClock(plannedEnd)];
        }
        self.rangeLabel.font = [NSFont monospacedDigitSystemFontOfSize:17 weight:NSFontWeightSemibold];
        self.rangeLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.92];
        if (overtime > 0) {
            CGFloat redStrength = 0.34 + MIN(1.0, overtime / 180.0) * 0.66;
            self.statusDot.layer.backgroundColor = [NSColor.systemRedColor colorWithAlphaComponent:redStrength].CGColor;
        } else {
            self.statusDot.layer.backgroundColor = NSColor.systemGreenColor.CGColor;
        }
        self.progressView.hasRecord = YES;
        self.progressView.regularProgress = MIN(1.0, elapsed / (CGFloat)standardDuration);
        self.progressView.overtimeProgress = MIN(1.0, overtime / 180.0);
        self.progressView.toolTip = overtime > 0
            ? [NSString stringWithFormat:@"标准工时 %@ · 加班 %@", WorkFormatDuration(MIN(elapsed, standardDuration)), WorkFormatDuration(overtime)]
            : [NSString stringWithFormat:@"已工作 %@ / %@", WorkFormatDuration(elapsed), WorkFormatDuration(standardDuration)];
    }
    [self.progressView setNeedsDisplay:YES];
}

- (NSInteger)liveElapsedMinutesForDateKey:(NSString *)dateKey startMinutes:(NSInteger)start {
    NSDate *base = WorkDateFromKey(dateKey);
    NSDate *startedAt = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitMinute value:start
                                                              toDate:base options:0];
    return (NSInteger)floor([[NSDate date] timeIntervalSinceDate:startedAt] / 60.0);
}

- (NSDatePicker *)timePickerWithDate:(NSDate *)date {
    NSDatePicker *picker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(0, 0, 220, 28)];
    picker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    picker.datePickerElements = NSDatePickerElementFlagHourMinute;
    picker.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    picker.font = [NSFont monospacedDigitSystemFontOfSize:16 weight:NSFontWeightMedium];
    picker.dateValue = date;
    return picker;
}

- (void)showWidgetSettings {
    [NSApp activateIgnoringOtherApps:YES];
    self.pendingSettingsImage = self.settings.originalImage;
    self.pendingRemoveBackground = NO;

    NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 460, 300)];
    NSTextField *previewLabel = [NSTextField labelWithString:@"背景预览（拖动图片调整取景）"];
    previewLabel.frame = NSMakeRect(20, 278, 300, 20);
    previewLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [accessory addSubview:previewLabel];

    self.settingsCropView = [[BackgroundCropView alloc] initWithFrame:NSMakeRect(20, 108, 420, 165)];
    self.settingsCropView.image = self.pendingSettingsImage;
    self.settingsCropView.offsetX = self.settings.cropOffsetX;
    self.settingsCropView.offsetY = self.settings.cropOffsetY;
    self.settingsCropView.zoom = self.settings.cropZoom;
    [accessory addSubview:self.settingsCropView];

    NSButton *choose = [NSButton buttonWithTitle:@"选择图片…" target:self action:@selector(chooseSettingsBackground:)];
    choose.frame = NSMakeRect(20, 74, 96, 26);
    choose.bezelStyle = NSBezelStyleRounded;
    [accessory addSubview:choose];

    self.settingsRemoveButton = [NSButton buttonWithTitle:@"移除图片" target:self action:@selector(removeSettingsBackground:)];
    self.settingsRemoveButton.frame = NSMakeRect(120, 74, 86, 26);
    self.settingsRemoveButton.bezelStyle = NSBezelStyleRounded;
    self.settingsRemoveButton.enabled = self.pendingSettingsImage != nil;
    [accessory addSubview:self.settingsRemoveButton];

    self.settingsModeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"使用原图", @"模糊毛玻璃"]
                                                                 trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                        target:nil action:nil];
    self.settingsModeControl.frame = NSMakeRect(230, 74, 210, 26);
    self.settingsModeControl.selectedSegment = self.settings.backgroundMode == WidgetBackgroundModeBlurredImage ? 1 : 0;
    self.settingsModeControl.enabled = self.pendingSettingsImage != nil;
    [accessory addSubview:self.settingsModeControl];

    NSTextField *zoomLabel = [NSTextField labelWithString:@"缩放"];
    zoomLabel.frame = NSMakeRect(20, 41, 42, 20);
    self.settingsZoomSlider = [NSSlider sliderWithValue:self.settings.cropZoom minValue:1.0 maxValue:3.0
                                                 target:self action:@selector(settingsZoomChanged:)];
    self.settingsZoomSlider.frame = NSMakeRect(66, 38, 374, 24);
    self.settingsZoomSlider.enabled = self.pendingSettingsImage != nil;
    [accessory addSubview:zoomLabel]; [accessory addSubview:self.settingsZoomSlider];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"更多小组件设置";
    alert.informativeText = @"上传图片并调整小组件背景。";
    alert.accessoryView = accessory;
    [alert addButtonWithTitle:@"保存设置"];
    [alert addButtonWithTitle:@"取消"];
    if (WorkRunGlassAlert(alert, self.widgetScreen) != NSAlertFirstButtonReturn) return;

    if (self.pendingSettingsImage) {
        NSImage *cropped = [self.settingsCropView croppedImageWithPixelSize:NSMakeSize(448, 176)];
        if (![self.settings saveOriginalImage:self.pendingSettingsImage] || ![self.settings saveCroppedImage:cropped]) {
            NSAlert *failure = [[NSAlert alloc] init];
            failure.messageText = @"背景图片保存失败";
            failure.informativeText = @"请检查磁盘空间后重试。";
            WorkRunGlassAlert(failure, self.widgetScreen);
            return;
        }
        self.settings.backgroundMode = self.settingsModeControl.selectedSegment == 1
            ? WidgetBackgroundModeBlurredImage : WidgetBackgroundModeImage;
        self.settings.cropZoom = self.settingsCropView.zoom;
        self.settings.cropOffsetX = self.settingsCropView.offsetX;
        self.settings.cropOffsetY = self.settingsCropView.offsetY;
    } else if (self.pendingRemoveBackground) {
        [self.settings removeCustomImage];
    }
    [self.settings synchronize];
    [self applyWidgetBackground];
    [self refreshDisplay];
    [self.historyController refresh];
    [self.panel orderFrontRegardless];
}

- (void)chooseSettingsBackground:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"选择小组件背景图片";
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedContentTypes = @[UTTypePNG, UTTypeJPEG, UTTypeHEIC, UTTypeTIFF];
    WorkPrepareModalWindowForSmoothPresentation(panel, self.widgetScreen);
    if ([panel runModal] != NSModalResponseOK) return;
    NSImage *image = [[NSImage alloc] initWithContentsOfURL:panel.URL];
    if (!image) { NSBeep(); return; }
    self.pendingSettingsImage = image;
    self.pendingRemoveBackground = NO;
    self.settingsCropView.offsetX = 0;
    self.settingsCropView.offsetY = 0;
    self.settingsCropView.zoom = 1.0;
    self.settingsCropView.image = image;
    self.settingsZoomSlider.doubleValue = 1.0;
    self.settingsZoomSlider.enabled = YES;
    self.settingsModeControl.enabled = YES;
    self.settingsRemoveButton.enabled = YES;
}

- (void)settingsZoomChanged:(NSSlider *)sender { self.settingsCropView.zoom = sender.doubleValue; }

- (void)removeSettingsBackground:(id)sender {
    self.pendingSettingsImage = nil;
    self.pendingRemoveBackground = YES;
    self.settingsCropView.image = nil;
    self.settingsZoomSlider.enabled = NO;
    self.settingsModeControl.enabled = NO;
    self.settingsRemoveButton.enabled = NO;
}

- (void)showWorkScheduleSettings {
    [NSApp activateIgnoringOtherApps:YES];
    NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 72)];
    NSTextField *prefix = [NSTextField labelWithString:@"预计下班时间为上班后"];
    prefix.frame = NSMakeRect(0, 43, 135, 20);
    NSInteger duration = self.settings.durationMinutes;
    self.settingsHoursField = [[NSTextField alloc] initWithFrame:NSMakeRect(136, 38, 42, 26)];
    self.settingsHoursField.integerValue = duration / 60;
    self.settingsHoursField.alignment = NSTextAlignmentCenter;
    NSTextField *hoursLabel = [NSTextField labelWithString:@"小时"];
    hoursLabel.frame = NSMakeRect(182, 43, 32, 20);
    self.settingsMinutesField = [[NSTextField alloc] initWithFrame:NSMakeRect(216, 38, 42, 26)];
    self.settingsMinutesField.integerValue = duration % 60;
    self.settingsMinutesField.alignment = NSTextAlignmentCenter;
    NSTextField *minutesLabel = [NSTextField labelWithString:@"分钟"];
    minutesLabel.frame = NSMakeRect(262, 43, 38, 20);
    NSTextField *hint = [NSTextField labelWithString:@"保存一次后永久执行，直到再次修改。"];
    hint.frame = NSMakeRect(0, 6, 300, 20);
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = NSColor.secondaryLabelColor;
    [accessory addSubview:prefix]; [accessory addSubview:self.settingsHoursField];
    [accessory addSubview:hoursLabel]; [accessory addSubview:self.settingsMinutesField];
    [accessory addSubview:minutesLabel]; [accessory addSubview:hint];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"工作时间计划";
    alert.informativeText = [NSString stringWithFormat:@"当前标准工时：%@", WorkFormatDuration(duration)];
    alert.accessoryView = accessory;
    [alert addButtonWithTitle:@"保存计划"];
    [alert addButtonWithTitle:@"取消"];
    if (WorkRunGlassAlert(alert, self.widgetScreen) != NSAlertFirstButtonReturn) return;

    NSInteger hours = self.settingsHoursField.integerValue;
    NSInteger minutes = self.settingsMinutesField.integerValue;
    NSInteger total = hours * 60 + minutes;
    if (hours < 0 || hours > 24 || minutes < 0 || minutes > 59 || total < 1 || total > 24 * 60) {
        NSAlert *invalid = [[NSAlert alloc] init];
        invalid.messageText = @"工作时长不正确";
        invalid.informativeText = @"请输入 1 分钟到 24 小时之间的时长，分钟需要在 0–59 之间。";
        WorkRunGlassAlert(invalid, self.widgetScreen);
        return;
    }
    self.settings.durationMinutes = total;
    [self.settings synchronize];
    NSString *activeKey = self.store.relevantDateKey;
    NSDictionary *activeRecord = [self.store recordForDateKey:activeKey];
    if (activeRecord && ![activeRecord[@"completed"] boolValue])
        [self.store updatePlannedDurationMinutes:total forUncompletedDateKey:activeKey];
    [self refreshDisplay];
    [self.historyController refresh];
    [self.panel orderFrontRegardless];
}

- (void)showStartTimeEditor {
    [NSApp activateIgnoringOtherApps:YES];
    NSString *dateKey = self.store.relevantDateKey;
    NSDictionary *record = [self.store recordForDateKey:dateKey];
    BOOL isToday = [dateKey isEqualToString:self.store.todayKey];
    if (record && !isToday && ![record[@"completed"] boolValue]) {
        NSAlert *overnight = [[NSAlert alloc] init];
        overnight.messageText = @"上一班次还未结束";
        overnight.informativeText = [NSString stringWithFormat:@"%@ 的班次跨到了今天，请先记录实际下班时间。", dateKey];
        [overnight addButtonWithTitle:@"记录下班"];
        [overnight addButtonWithTitle:@"取消"];
        if (WorkRunGlassAlert(overnight, self.widgetScreen) == NSAlertFirstButtonReturn)
            [self showClockOutEditorForDateKey:dateKey record:record];
        return;
    }
    if (record && isToday && [record[@"completed"] boolValue]) {
        [self.historyController showOnScreen:self.widgetScreen];
        return;
    }
    NSInteger start = record ? [record[@"start"] integerValue] : -1;
    NSDate *baseDate = WorkDateFromKey(self.store.todayKey);
    NSDate *initialDate = (start >= 0 && isToday) ? [baseDate dateByAddingTimeInterval:start * 60] : [NSDate date];
    NSDatePicker *picker = [self timePickerWithDate:initialDate];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"设置今天的上班时间";
    alert.informativeText = [NSString stringWithFormat:@"预计下班时间按 %@ 后计算；点击下班后才会归档。",
                             WorkFormatDuration(self.settings.durationMinutes)];
    alert.accessoryView = picker;
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"取消"];
    if (record) [alert addButtonWithTitle:[record[@"completed"] boolValue] ? @"查看记录" : @"记录下班"];

    NSModalResponse response = WorkRunGlassAlert(alert, self.widgetScreen);
    if (response == NSAlertFirstButtonReturn) {
        NSDateComponents *selected = [NSCalendar.currentCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                                                    fromDate:picker.dateValue];
        [self.store saveStartMinutes:selected.hour * 60 + selected.minute
              plannedDurationMinutes:self.settings.durationMinutes
                          forDateKey:self.store.todayKey];
        [self refreshDisplay]; [self.historyController refresh];
    } else if (response == NSAlertThirdButtonReturn) {
        if ([record[@"completed"] boolValue]) [self.historyController showOnScreen:self.widgetScreen];
        else [self showClockOutEditorForDateKey:dateKey record:record];
    }
    [self.panel orderFrontRegardless];
}

- (void)showClockOutEditorForDateKey:(NSString *)dateKey record:(NSDictionary *)record {
    NSInteger start = [record[@"start"] integerValue];
    NSDate *baseDate = WorkDateFromKey(dateKey);
    NSDate *clockOutMoment = [NSDate date];
    NSDate *todayStart = [NSCalendar.currentCalendar startOfDayForDate:clockOutMoment];
    NSInteger dayOffset = [NSCalendar.currentCalendar components:NSCalendarUnitDay
                                                        fromDate:baseDate toDate:todayStart options:0].day;
    NSDateComponents *clock = [NSCalendar.currentCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                                              fromDate:clockOutMoment];
    NSInteger end = dayOffset * 24 * 60 + clock.hour * 60 + clock.minute;
    NSInteger duration = end - start;
    if (duration <= 0) {
        NSAlert *invalid = [[NSAlert alloc] init];
        invalid.messageText = @"现在还早于上班时间";
        invalid.informativeText = @"请先检查今天设置的上班时间。";
        WorkRunGlassAlert(invalid, self.widgetScreen);
        return;
    }
    if (duration > 24 * 60) {
        NSAlert *stale = [[NSAlert alloc] init];
        stale.messageText = @"这条班次已超过 24 小时";
        stale.informativeText = @"为避免误记多天工时，请到月度记录中点击这一天并修改正确的下班时间。";
        [stale addButtonWithTitle:@"打开记录"];
        [stale addButtonWithTitle:@"取消"];
        if (WorkRunGlassAlert(stale, self.widgetScreen) == NSAlertFirstButtonReturn)
            [self.historyController showOnScreen:self.widgetScreen];
        return;
    }

    NSInteger standardDuration = record[@"plannedDuration"]
        ? [record[@"plannedDuration"] integerValue] : WorkDurationMinutes;
    NSInteger overtime = MAX(0, duration - standardDuration);
    NSAlert *confirm = [[NSAlert alloc] init];
    confirm.messageText = [NSString stringWithFormat:@"确认在 %@ 下班？", WorkFormatClock(end)];
    confirm.informativeText = overtime > 0
        ? [NSString stringWithFormat:@"总工时 %@，其中加班 %@。", WorkFormatDuration(duration), WorkFormatDuration(overtime)]
        : [NSString stringWithFormat:@"本次总工时 %@。", WorkFormatDuration(duration)];
    [confirm addButtonWithTitle:@"确认下班"];
    [confirm addButtonWithTitle:@"取消"];
    if (WorkRunGlassAlert(confirm, self.widgetScreen) != NSAlertFirstButtonReturn) return;
    [self.store completeRecordForDateKey:dateKey endMinutes:end];
    [self refreshDisplay]; [self.historyController refresh];
}

- (NSMenu *)makeContextMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *setItem = [[NSMenuItem alloc] initWithTitle:@"设置上班时间…" action:@selector(openEditor:) keyEquivalent:@""];
    setItem.target = self; [menu addItem:setItem];
    NSString *dateKey = self.store.relevantDateKey;
    NSDictionary *record = [self.store recordForDateKey:dateKey];
    if (record && ![record[@"completed"] boolValue]) {
        NSMenuItem *finish = [[NSMenuItem alloc] initWithTitle:@"记录实际下班时间…" action:@selector(recordClockOut:) keyEquivalent:@""];
        finish.target = self; [menu addItem:finish];
    }
    NSMenuItem *history = [[NSMenuItem alloc] initWithTitle:@"查看工作记录…" action:@selector(showHistory:) keyEquivalent:@""];
    history.target = self; [menu addItem:history];
    NSString *scheduleTitle = [NSString stringWithFormat:@"工作时间计划（%@）…",
                               WorkFormatDuration(self.settings.durationMinutes)];
    NSMenuItem *schedule = [[NSMenuItem alloc] initWithTitle:scheduleTitle action:@selector(openSchedule:) keyEquivalent:@""];
    schedule.target = self; [menu addItem:schedule];
    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"更多小组件设置…" action:@selector(openSettings:) keyEquivalent:@""];
    settings.target = self; [menu addItem:settings];
    if ([self.store recordForDateKey:self.store.todayKey]) {
        [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *clear = [[NSMenuItem alloc] initWithTitle:@"删除今日记录…" action:@selector(deleteToday:) keyEquivalent:@""];
        clear.target = self; [menu addItem:clear];
    }
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"退出桌面小组件" action:@selector(quitApp:) keyEquivalent:@""];
    quit.target = self; [menu addItem:quit];
    return menu;
}

- (void)openEditor:(id)sender { [self showStartTimeEditor]; }
- (void)openSettings:(id)sender { [self showWidgetSettings]; }
- (void)openSchedule:(id)sender { [self showWorkScheduleSettings]; }
- (void)showHistory:(id)sender { [self.historyController showOnScreen:self.widgetScreen]; }
- (void)recordClockOut:(id)sender {
    NSString *key = self.store.relevantDateKey;
    NSDictionary *record = [self.store recordForDateKey:key];
    if (record) [self showClockOutEditorForDateKey:key record:record];
}
- (void)deleteToday:(id)sender {
    NSAlert *confirm = [[NSAlert alloc] init];
    confirm.messageText = @"删除今天的工作记录？";
    confirm.informativeText = @"删除后无法从月度记录中恢复。";
    [confirm addButtonWithTitle:@"删除"];
    [confirm addButtonWithTitle:@"取消"];
    if (WorkRunGlassAlert(confirm, self.widgetScreen) != NSAlertFirstButtonReturn) return;
    [self.store deleteRecordForDateKey:self.store.todayKey];
    [self refreshDisplay]; [self.historyController refresh];
}
- (void)quitApp:(id)sender { [NSApp terminate:nil]; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}

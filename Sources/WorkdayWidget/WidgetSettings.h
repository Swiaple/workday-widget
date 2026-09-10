#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, WidgetBackgroundMode) {
    WidgetBackgroundModeImage = 0,
    WidgetBackgroundModeBlurredImage = 1,
    WidgetBackgroundModeSystemGlass = 2
};

typedef NS_ENUM(NSInteger, WidgetProgressIconMode) {
    WidgetProgressIconModeOff = 0,
    WidgetProgressIconModeBuiltIn = 1,
    WidgetProgressIconModeCustom = 2
};

@interface WidgetSettings : NSObject
@property (nonatomic) NSInteger durationMinutes;
@property (nonatomic) WidgetBackgroundMode backgroundMode;
@property (nonatomic) CGFloat cropZoom;
@property (nonatomic) CGFloat cropOffsetX;
@property (nonatomic) CGFloat cropOffsetY;
@property (nonatomic) WidgetProgressIconMode progressIconMode;
@property (nonatomic, readonly) BOOL hasCustomImage;
@property (nonatomic, readonly) BOOL hasCustomProgressIcon;
- (NSImage *)originalImage;
- (NSImage *)croppedImage;
- (NSData *)customProgressIconData;
- (NSImage *)customProgressIconImage;
- (BOOL)saveOriginalImage:(NSImage *)image;
- (BOOL)saveCroppedImage:(NSImage *)image;
- (BOOL)saveCustomProgressIconData:(NSData *)data;
- (void)removeCustomImage;
- (void)removeCustomProgressIcon;
- (void)synchronize;
@end

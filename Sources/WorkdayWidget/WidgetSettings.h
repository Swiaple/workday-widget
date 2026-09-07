#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, WidgetBackgroundMode) {
    WidgetBackgroundModeImage = 0,
    WidgetBackgroundModeBlurredImage = 1,
    WidgetBackgroundModeSystemGlass = 2
};

@interface WidgetSettings : NSObject
@property (nonatomic) NSInteger durationMinutes;
@property (nonatomic) WidgetBackgroundMode backgroundMode;
@property (nonatomic) CGFloat cropZoom;
@property (nonatomic) CGFloat cropOffsetX;
@property (nonatomic) CGFloat cropOffsetY;
@property (nonatomic, readonly) BOOL hasCustomImage;
- (NSImage *)originalImage;
- (NSImage *)croppedImage;
- (BOOL)saveOriginalImage:(NSImage *)image;
- (BOOL)saveCroppedImage:(NSImage *)image;
- (void)removeCustomImage;
- (void)synchronize;
@end

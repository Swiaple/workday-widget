#import "WidgetSettings.h"

static NSString *const DurationKey = @"settings.durationMinutes";
static NSString *const BackgroundModeKey = @"settings.backgroundMode";
static NSString *const CropZoomKey = @"settings.cropZoom";
static NSString *const CropOffsetXKey = @"settings.cropOffsetX";
static NSString *const CropOffsetYKey = @"settings.cropOffsetY";
static NSString *const ProgressIconModeKey = @"settings.progressIconMode";

@interface WidgetSettings ()
@property (nonatomic, strong) NSURL *directoryURL;
@property (nonatomic, strong) NSURL *originalURL;
@property (nonatomic, strong) NSURL *croppedURL;
@property (nonatomic, strong) NSURL *progressIconURL;
@end

@implementation WidgetSettings
- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
    _directoryURL = [support URLByAppendingPathComponent:@"打卡时间" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:_directoryURL
                           withIntermediateDirectories:YES attributes:nil error:nil];
    _originalURL = [_directoryURL URLByAppendingPathComponent:@"background-original.png"];
    _croppedURL = [_directoryURL URLByAppendingPathComponent:@"background-cropped.png"];
    // Keep the original bytes so GIF/APNG/WebP animation frames are not lost.
    _progressIconURL = [_directoryURL URLByAppendingPathComponent:@"progress-icon-original"];

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    _durationMinutes = [defaults objectForKey:DurationKey] ? [defaults integerForKey:DurationKey] : 8 * 60 + 30;
    _backgroundMode = [defaults objectForKey:BackgroundModeKey]
        ? [defaults integerForKey:BackgroundModeKey] : WidgetBackgroundModeSystemGlass;
    _cropZoom = [defaults objectForKey:CropZoomKey] ? [defaults doubleForKey:CropZoomKey] : 1.0;
    _cropOffsetX = [defaults doubleForKey:CropOffsetXKey];
    _cropOffsetY = [defaults doubleForKey:CropOffsetYKey];
    _progressIconMode = [defaults objectForKey:ProgressIconModeKey]
        ? [defaults integerForKey:ProgressIconModeKey] : WidgetProgressIconModeOff;
    if (!self.hasCustomImage) _backgroundMode = WidgetBackgroundModeSystemGlass;
    if (_progressIconMode == WidgetProgressIconModeCustom && !self.hasCustomProgressIcon)
        _progressIconMode = WidgetProgressIconModeOff;
    return self;
}

- (BOOL)hasCustomImage {
    return [NSFileManager.defaultManager fileExistsAtPath:self.originalURL.path] &&
           [NSFileManager.defaultManager fileExistsAtPath:self.croppedURL.path];
}

- (BOOL)hasCustomProgressIcon {
    return [NSFileManager.defaultManager fileExistsAtPath:self.progressIconURL.path];
}

- (NSImage *)originalImage { return [[NSImage alloc] initWithContentsOfURL:self.originalURL]; }
- (NSImage *)croppedImage { return [[NSImage alloc] initWithContentsOfURL:self.croppedURL]; }
- (NSData *)customProgressIconData { return [NSData dataWithContentsOfURL:self.progressIconURL]; }
- (NSImage *)customProgressIconImage {
    NSData *data = self.customProgressIconData;
    return data ? [[NSImage alloc] initWithData:data] : nil;
}

- (BOOL)writePNGImage:(NSImage *)image toURL:(NSURL *)url {
    NSData *tiff = image.TIFFRepresentation;
    if (!tiff) return NO;
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return png && [png writeToURL:url options:NSDataWritingAtomic error:nil];
}

- (BOOL)saveOriginalImage:(NSImage *)image { return [self writePNGImage:image toURL:self.originalURL]; }
- (BOOL)saveCroppedImage:(NSImage *)image { return [self writePNGImage:image toURL:self.croppedURL]; }
- (BOOL)saveCustomProgressIconData:(NSData *)data {
    if (data.length == 0 || ![[NSImage alloc] initWithData:data]) return NO;
    return [data writeToURL:self.progressIconURL options:NSDataWritingAtomic error:nil];
}

- (void)removeCustomImage {
    [NSFileManager.defaultManager removeItemAtURL:self.originalURL error:nil];
    [NSFileManager.defaultManager removeItemAtURL:self.croppedURL error:nil];
    self.backgroundMode = WidgetBackgroundModeSystemGlass;
    self.cropZoom = 1.0;
    self.cropOffsetX = 0;
    self.cropOffsetY = 0;
    [self synchronize];
}

- (void)removeCustomProgressIcon {
    [NSFileManager.defaultManager removeItemAtURL:self.progressIconURL error:nil];
    if (self.progressIconMode == WidgetProgressIconModeCustom)
        self.progressIconMode = WidgetProgressIconModeOff;
    [self synchronize];
}

- (void)synchronize {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setInteger:MAX(1, self.durationMinutes) forKey:DurationKey];
    [defaults setInteger:self.backgroundMode forKey:BackgroundModeKey];
    [defaults setDouble:self.cropZoom forKey:CropZoomKey];
    [defaults setDouble:self.cropOffsetX forKey:CropOffsetXKey];
    [defaults setDouble:self.cropOffsetY forKey:CropOffsetYKey];
    [defaults setInteger:self.progressIconMode forKey:ProgressIconModeKey];
}
@end

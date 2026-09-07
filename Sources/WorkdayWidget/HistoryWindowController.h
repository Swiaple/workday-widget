#import <Cocoa/Cocoa.h>
#import "WorkRecordStore.h"

@interface HistoryWindowController : NSObject
@property (nonatomic, copy) void (^onRecordsChanged)(void);
- (instancetype)initWithStore:(WorkRecordStore *)store;
- (void)show;
- (void)showOnScreen:(NSScreen *)screen;
- (void)refresh;
@end

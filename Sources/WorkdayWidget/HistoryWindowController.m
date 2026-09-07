#import "HistoryWindowController.h"
#import "WindowStyling.h"

@interface HistoryWindowController () <NSWindowDelegate>
@property (nonatomic, strong) WorkRecordStore *store;
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSVisualEffectView *rootView;
@property (nonatomic, strong) NSButton *previousButton;
@property (nonatomic, strong) NSTextField *monthLabel;
@property (nonatomic, strong) NSTextField *summaryLabel;
@property (nonatomic, strong) NSView *gridContainer;
@property (nonatomic, strong) NSButton *nextButton;
@property (nonatomic, strong) NSArray<NSTextField *> *weekdayLabels;
@property (nonatomic, strong) NSTextField *legendLabel;
@property (nonatomic, strong) NSButton *todayButton;
@property (nonatomic, strong) NSDate *displayedMonth;
@property (nonatomic, weak) NSScreen *preferredScreen;
@end

@implementation HistoryWindowController
- (instancetype)initWithStore:(WorkRecordStore *)store {
    self = [super init];
    if (!self) return nil;
    _store = store;
    _displayedMonth = [self firstDayOfMonth:[NSDate date]];
    [self buildWindow];
    return self;
}

- (NSDate *)firstDayOfMonth:(NSDate *)date {
    NSDateComponents *components = [NSCalendar.currentCalendar components:(NSCalendarUnitYear | NSCalendarUnitMonth)
                                                                  fromDate:date];
    components.day = 1;
    return [NSCalendar.currentCalendar dateFromComponents:components];
}

- (void)buildWindow {
    NSRect frame = NSMakeRect(0, 0, 380, 420);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"工作记录";
    self.window.releasedWhenClosed = NO;
    self.window.level = NSNormalWindowLevel;
    self.window.minSize = NSMakeSize(340, 390);
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    self.window.backgroundColor = [NSColor colorWithWhite:0.08 alpha:1.0];
    self.window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    if (![self.window setFrameUsingName:@"WorkHistoryWindowPositionV2"]) [self.window center];
    [self.window setFrameAutosaveName:@"WorkHistoryWindowPositionV2"];

    NSVisualEffectView *root = [[NSVisualEffectView alloc] initWithFrame:frame];
    root.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    root.material = NSVisualEffectMaterialHUDWindow;
    root.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    root.state = NSVisualEffectStateActive;
    root.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    self.window.contentView = root;
    self.rootView = root;

    self.previousButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"chevron.left" accessibilityDescription:@"上个月"]
                                             target:self action:@selector(previousMonth:)];
    self.previousButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.previousButton.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.72];
    [root addSubview:self.previousButton];

    self.monthLabel = [NSTextField labelWithString:@""];
    self.monthLabel.frame = NSMakeRect(105, 472, 246, 24);
    self.monthLabel.alignment = NSTextAlignmentCenter;
    self.monthLabel.font = [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
    self.monthLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.94];
    [root addSubview:self.monthLabel];

    self.nextButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"chevron.right" accessibilityDescription:@"下个月"]
                                         target:self action:@selector(nextMonth:)];
    self.nextButton.frame = NSMakeRect(406, 469, 32, 28);
    self.nextButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.nextButton.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.72];
    [root addSubview:self.nextButton];

    self.summaryLabel = [NSTextField labelWithString:@""];
    self.summaryLabel.frame = NSMakeRect(18, 438, 420, 22);
    self.summaryLabel.alignment = NSTextAlignmentCenter;
    self.summaryLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.summaryLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.64];
    [root addSubview:self.summaryLabel];

    NSArray *weekdays = @[@"一", @"二", @"三", @"四", @"五", @"六", @"日"];
    NSMutableArray *weekdayLabels = [[NSMutableArray alloc] init];
    for (NSInteger column = 0; column < 7; column++) {
        NSTextField *label = [NSTextField labelWithString:weekdays[column]];
        label.alignment = NSTextAlignmentCenter;
        label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        label.textColor = [NSColor.whiteColor colorWithAlphaComponent:(column >= 5 ? 0.38 : 0.60)];
        [root addSubview:label];
        [weekdayLabels addObject:label];
    }
    self.weekdayLabels = weekdayLabels;

    self.gridContainer = [[NSView alloc] init];
    [root addSubview:self.gridContainer];

    self.legendLabel = [NSTextField labelWithString:@"绿色深浅＝总工时  ·  红色深浅＝加班  ·  橙色＝进行中"];
    self.legendLabel.alignment = NSTextAlignmentCenter;
    self.legendLabel.font = [NSFont systemFontOfSize:10];
    self.legendLabel.textColor = [NSColor.whiteColor colorWithAlphaComponent:0.46];
    [root addSubview:self.legendLabel];

    self.todayButton = [NSButton buttonWithTitle:@"回到本月" target:self action:@selector(showCurrentMonth:)];
    self.todayButton.bezelStyle = NSBezelStyleRounded;
    [root addSubview:self.todayButton];

    [self layoutWindowContents];
    self.window.delegate = self;
}

- (void)layoutWindowContents {
    CGFloat width = NSWidth(self.rootView.bounds);
    CGFloat height = NSHeight(self.rootView.bounds);
    self.previousButton.frame = NSMakeRect(14, height - 48, 32, 28);
    self.monthLabel.frame = NSMakeRect(58, height - 46, width - 116, 24);
    self.nextButton.frame = NSMakeRect(width - 46, height - 48, 32, 28);
    self.summaryLabel.frame = NSMakeRect(14, height - 77, width - 28, 22);
    self.gridContainer.frame = NSMakeRect(14, 64, width - 28, height - 174);
    self.legendLabel.frame = NSMakeRect(14, 36, width - 28, 18);
    self.todayButton.frame = NSMakeRect((width - 100) / 2.0, 7, 100, 26);

    CGFloat gap = 4;
    CGFloat cellWidth = (NSWidth(self.gridContainer.frame) - gap * 6) / 7.0;
    for (NSInteger column = 0; column < 7; column++) {
        self.weekdayLabels[column].frame = NSMakeRect(14 + column * (cellWidth + gap),
                                                      height - 106, cellWidth, 20);
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    [self layoutWindowContents];
    [self refresh];
}

- (void)show {
    [self showOnScreen:NSScreen.mainScreen];
}

- (void)showOnScreen:(NSScreen *)screen {
    [self.store finalizeDueRecords];
    [self refresh];
    self.preferredScreen = screen ?: NSScreen.mainScreen;
    WorkPositionWindowOnScreen(self.window, self.preferredScreen);
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)refresh {
    [self.store finalizeDueRecords];
    for (NSView *view in self.gridContainer.subviews.copy) [view removeFromSuperview];

    NSDateComponents *monthComponents = [NSCalendar.currentCalendar components:(NSCalendarUnitYear | NSCalendarUnitMonth)
                                                                        fromDate:self.displayedMonth];
    self.monthLabel.stringValue = [NSString stringWithFormat:@"%ld年 %ld月", (long)monthComponents.year, (long)monthComponents.month];

    NSDate *currentMonth = [self firstDayOfMonth:[NSDate date]];
    self.nextButton.enabled = [self.displayedMonth compare:currentMonth] == NSOrderedAscending;

    NSRange dayRange = [NSCalendar.currentCalendar rangeOfUnit:NSCalendarUnitDay
                                                       inUnit:NSCalendarUnitMonth
                                                      forDate:self.displayedMonth];
    NSInteger weekday = [NSCalendar.currentCalendar component:NSCalendarUnitWeekday fromDate:self.displayedMonth];
    NSInteger mondayOffset = (weekday + 5) % 7;
    NSDictionary *records = self.store.allRecords;
    NSInteger completedDays = 0;
    NSInteger totalMinutes = 0;
    NSInteger totalOvertime = 0;
    CGFloat horizontalGap = 4;
    CGFloat verticalGap = 4;
    CGFloat gridWidth = NSWidth(self.gridContainer.bounds);
    CGFloat gridHeight = NSHeight(self.gridContainer.bounds);
    CGFloat cellWidth = (gridWidth - horizontalGap * 6) / 7.0;
    CGFloat cellHeight = (gridHeight - verticalGap * 5) / 6.0;

    for (NSInteger day = 1; day <= (NSInteger)dayRange.length; day++) {
        NSInteger slot = mondayOffset + day - 1;
        NSInteger row = slot / 7;
        NSInteger column = slot % 7;
        NSDateComponents *components = [monthComponents copy];
        components.day = day;
        NSDate *date = [NSCalendar.currentCalendar dateFromComponents:components];
        NSString *dateKey = WorkDateKey(date);
        NSDictionary *record = records[dateKey];
        BOOL completed = [record[@"completed"] boolValue];
        NSInteger plannedDuration = record[@"plannedDuration"]
            ? [record[@"plannedDuration"] integerValue] : WorkDurationMinutes;
        NSInteger duration = completed ? [record[@"actualEnd"] integerValue] - [record[@"start"] integerValue] : 0;
        NSInteger overtime = completed ? MAX(0, duration - plannedDuration) : 0;
        if (completed) {
            completedDays++;
            totalMinutes += MAX(0, duration);
            totalOvertime += overtime;
        }

        NSString *subtitle = @"";
        if (completed) subtitle = [NSString stringWithFormat:@"%ldh%02ld", (long)(duration / 60), (long)(duration % 60)];
        else if (record) subtitle = @"预计";
        NSString *title = subtitle.length ? [NSString stringWithFormat:@"%ld\n%@", (long)day, subtitle] : [NSString stringWithFormat:@"%ld", (long)day];

        NSButton *button = [NSButton buttonWithTitle:title target:self action:@selector(dayClicked:)];
        button.identifier = dateKey;
        button.frame = NSMakeRect(column * (cellWidth + horizontalGap),
                                  gridHeight - (row + 1) * cellHeight - row * verticalGap,
                                  cellWidth, cellHeight);
        button.bordered = NO;
        button.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:completed ? NSFontWeightSemibold : NSFontWeightRegular];
        button.alignment = NSTextAlignmentCenter;
        button.wantsLayer = YES;
        button.layer.cornerRadius = 9;

        if (completed) {
            CGFloat strength = MIN(1.0, MAX(0.0, (duration - 300.0) / 360.0));
            button.layer.backgroundColor = [NSColor.systemGreenColor colorWithAlphaComponent:(0.18 + strength * 0.58)].CGColor;
            button.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:(strength > 0.62 ? 1.0 : 0.88)];
            if (overtime > 0) {
                CGFloat overtimeStrength = MIN(1.0, overtime / 180.0);
                CALayer *redBand = [CALayer layer];
                redBand.frame = NSMakeRect(4, 3, cellWidth - 8, 5);
                redBand.cornerRadius = 2.5;
                redBand.backgroundColor = [NSColor.systemRedColor colorWithAlphaComponent:(0.28 + overtimeStrength * 0.70)].CGColor;
                [button.layer addSublayer:redBand];
            }
            button.toolTip = [NSString stringWithFormat:@"%@  %@–%@  %@%@", dateKey,
                              WorkFormatClock([record[@"start"] integerValue]),
                              WorkFormatClock([record[@"actualEnd"] integerValue]),
                              WorkFormatDuration(duration),
                              overtime > 0 ? [NSString stringWithFormat:@"（加班 %@）", WorkFormatDuration(overtime)] : @""];
        } else if (record) {
            button.layer.backgroundColor = [NSColor.systemOrangeColor colorWithAlphaComponent:0.20].CGColor;
            button.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.88];
            NSInteger start = [record[@"start"] integerValue];
            NSDate *startedAt = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitMinute value:start
                                                                       toDate:date options:0];
            NSInteger liveDuration = MAX(0, (NSInteger)floor([[NSDate date] timeIntervalSinceDate:startedAt] / 60.0));
            NSInteger liveOvertime = MAX(0, liveDuration - plannedDuration);
            button.toolTip = liveOvertime > 0
                ? [NSString stringWithFormat:@"加班中：已加班 %@", WorkFormatDuration(liveOvertime)]
                : [NSString stringWithFormat:@"进行中：已工作 %@", WorkFormatDuration(liveDuration)];
        } else if (column >= 5) {
            button.layer.backgroundColor = [NSColor.whiteColor colorWithAlphaComponent:0.035].CGColor;
            button.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.38];
        } else {
            button.contentTintColor = [NSColor.whiteColor colorWithAlphaComponent:0.66];
        }

        if ([dateKey isEqualToString:self.store.todayKey]) {
            button.layer.borderWidth = 1.3;
            button.layer.borderColor = NSColor.systemOrangeColor.CGColor;
        }
        [self.gridContainer addSubview:button];
    }

    if (completedDays == 0) {
        self.summaryLabel.stringValue = @"本月还没有已完成的工作记录";
    } else {
        self.summaryLabel.stringValue = [NSString stringWithFormat:@"%ld 天  ·  共 %@  ·  加班 %@  ·  平均 %@",
                                         (long)completedDays, WorkFormatDuration(totalMinutes),
                                         WorkFormatDuration(totalOvertime),
                                         WorkFormatDuration(totalMinutes / completedDays)];
    }
}

- (void)previousMonth:(id)sender {
    self.displayedMonth = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitMonth value:-1
                                                                toDate:self.displayedMonth options:0];
    [self refresh];
}

- (void)nextMonth:(id)sender {
    NSDate *candidate = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitMonth value:1
                                                              toDate:self.displayedMonth options:0];
    if ([candidate compare:[self firstDayOfMonth:[NSDate date]]] != NSOrderedDescending) self.displayedMonth = candidate;
    [self refresh];
}

- (void)showCurrentMonth:(id)sender {
    self.displayedMonth = [self firstDayOfMonth:[NSDate date]];
    [self refresh];
}

- (void)dayClicked:(NSButton *)sender {
    NSString *dateKey = sender.identifier;
    NSDictionary *record = [self.store recordForDateKey:dateKey];
    if (!record) return;
    BOOL completed = [record[@"completed"] boolValue];
    NSInteger start = [record[@"start"] integerValue];
    NSInteger end = completed ? [record[@"actualEnd"] integerValue] : [record[@"plannedEnd"] integerValue];
    NSInteger duration = end - start;
    NSInteger plannedDuration = record[@"plannedDuration"]
        ? [record[@"plannedDuration"] integerValue] : WorkDurationMinutes;
    NSInteger overtime = completed ? MAX(0, duration - plannedDuration) : 0;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = dateKey;
    alert.informativeText = [NSString stringWithFormat:@"上班 %@\n%@ %@\n总工时 %@%@",
                             WorkFormatClock(start), completed ? @"下班" : @"预计下班",
                             WorkFormatClock(end), WorkFormatDuration(duration),
                             overtime > 0 ? [NSString stringWithFormat:@"\n加班 %@", WorkFormatDuration(overtime)] : @""];
    [alert addButtonWithTitle:@"修改记录"];
    [alert addButtonWithTitle:@"关闭"];
    [alert addButtonWithTitle:@"删除"];
    NSModalResponse response = WorkRunGlassAlert(alert, self.preferredScreen ?: NSScreen.mainScreen);
    if (response == NSAlertFirstButtonReturn) [self editRecordForDateKey:dateKey record:record];
    else if (response == NSAlertThirdButtonReturn) [self confirmDeleteDateKey:dateKey];
}

- (void)editRecordForDateKey:(NSString *)dateKey record:(NSDictionary *)record {
    NSInteger start = [record[@"start"] integerValue];
    NSInteger end = [record[@"completed"] boolValue] ? [record[@"actualEnd"] integerValue] : [record[@"plannedEnd"] integerValue];
    NSDate *baseDate = WorkDateFromKey(dateKey);

    NSView *accessory = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 280, 92)];
    NSTextField *startLabel = [NSTextField labelWithString:@"上班"];
    startLabel.frame = NSMakeRect(0, 62, 46, 22);
    NSDatePicker *startPicker = [self timePickerWithFrame:NSMakeRect(52, 58, 112, 28)
                                                    date:[baseDate dateByAddingTimeInterval:start * 60]];
    NSTextField *endLabel = [NSTextField labelWithString:@"下班"];
    endLabel.frame = NSMakeRect(0, 27, 46, 22);
    NSDatePicker *endPicker = [self timePickerWithFrame:NSMakeRect(52, 23, 112, 28)
                                                  date:[baseDate dateByAddingTimeInterval:(end % (24 * 60)) * 60]];
    NSButton *nextDay = [NSButton checkboxWithTitle:@"次日" target:nil action:nil];
    nextDay.frame = NSMakeRect(178, 26, 82, 22);
    nextDay.state = end >= 24 * 60 ? NSControlStateValueOn : NSControlStateValueOff;
    [accessory addSubview:startLabel]; [accessory addSubview:startPicker];
    [accessory addSubview:endLabel]; [accessory addSubview:endPicker]; [accessory addSubview:nextDay];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"修改 %@ 的记录", dateKey];
    alert.informativeText = @"可修正早退、加班或跨午夜的情况。";
    alert.accessoryView = accessory;
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"取消"];
    if (WorkRunGlassAlert(alert, self.preferredScreen ?: NSScreen.mainScreen) != NSAlertFirstButtonReturn) return;

    NSDateComponents *startParts = [NSCalendar.currentCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                                                  fromDate:startPicker.dateValue];
    NSDateComponents *endParts = [NSCalendar.currentCalendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                                                fromDate:endPicker.dateValue];
    NSInteger newStart = startParts.hour * 60 + startParts.minute;
    NSInteger newEnd = endParts.hour * 60 + endParts.minute + (nextDay.state == NSControlStateValueOn ? 24 * 60 : 0);
    if (newEnd <= newStart) newEnd += 24 * 60;
    NSInteger duration = newEnd - newStart;
    if (duration <= 0 || duration > 24 * 60) {
        NSAlert *invalid = [[NSAlert alloc] init];
        invalid.messageText = @"时间范围不正确";
        invalid.informativeText = @"一条工作记录的时长需要在 1 分钟到 24 小时之间。";
        WorkRunGlassAlert(invalid, self.preferredScreen ?: NSScreen.mainScreen);
        return;
    }
    NSInteger plannedDuration = record[@"plannedDuration"]
        ? [record[@"plannedDuration"] integerValue] : WorkDurationMinutes;
    [self.store saveCompletedRecordForDateKey:dateKey startMinutes:newStart endMinutes:newEnd
                       plannedDurationMinutes:plannedDuration];
    [self refresh];
    if (self.onRecordsChanged) self.onRecordsChanged();
}

- (NSDatePicker *)timePickerWithFrame:(NSRect)frame date:(NSDate *)date {
    NSDatePicker *picker = [[NSDatePicker alloc] initWithFrame:frame];
    picker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
    picker.datePickerElements = NSDatePickerElementFlagHourMinute;
    picker.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    picker.font = [NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightMedium];
    picker.dateValue = date;
    return picker;
}

- (void)confirmDeleteDateKey:(NSString *)dateKey {
    NSAlert *confirm = [[NSAlert alloc] init];
    confirm.messageText = [NSString stringWithFormat:@"删除 %@ 的记录？", dateKey];
    confirm.informativeText = @"删除后无法从日历中恢复。";
    [confirm addButtonWithTitle:@"删除"];
    [confirm addButtonWithTitle:@"取消"];
    if (WorkRunGlassAlert(confirm, self.preferredScreen ?: NSScreen.mainScreen) != NSAlertFirstButtonReturn) return;
    [self.store deleteRecordForDateKey:dateKey];
    [self refresh];
    if (self.onRecordsChanged) self.onRecordsChanged();
}
@end

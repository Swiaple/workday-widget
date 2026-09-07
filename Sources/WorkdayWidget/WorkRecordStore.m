#import "WorkRecordStore.h"

NSInteger const WorkDurationMinutes = 8 * 60 + 30;

static NSDateFormatter *DateKeyFormatter(void) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd";
    });
    return formatter;
}

NSString *WorkDateKey(NSDate *date) {
    return [DateKeyFormatter() stringFromDate:date];
}

NSDate *WorkDateFromKey(NSString *key) {
    return [DateKeyFormatter() dateFromString:key];
}

NSString *WorkFormatClock(NSInteger minutes) {
    NSInteger normalized = ((minutes % (24 * 60)) + (24 * 60)) % (24 * 60);
    NSString *prefix = minutes >= 24 * 60 ? @"次日 " : @"";
    return [NSString stringWithFormat:@"%@%02ld:%02ld", prefix,
            (long)(normalized / 60), (long)(normalized % 60)];
}

NSString *WorkFormatDuration(NSInteger minutes) {
    NSInteger safe = MAX(0, minutes);
    if (safe % 60 == 0) return [NSString stringWithFormat:@"%ld小时", (long)(safe / 60)];
    return [NSString stringWithFormat:@"%ld小时%ld分", (long)(safe / 60), (long)(safe % 60)];
}

@interface WorkRecordStore ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *records;
@property (nonatomic, readwrite) NSURL *dataURL;
@property (nonatomic, strong) NSURL *backupURL;
- (void)reopenTodayAutomaticallyCompletedRecordIfNeeded;
@end

@implementation WorkRecordStore
- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                          inDomains:NSUserDomainMask].firstObject;
    NSURL *directory = [support URLByAppendingPathComponent:@"打卡时间" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:directory
                           withIntermediateDirectories:YES
                                            attributes:nil
                                                 error:nil];
    _dataURL = [directory URLByAppendingPathComponent:@"work-records.json"];
    _backupURL = [directory URLByAppendingPathComponent:@"work-records.backup.json"];
    _records = [[NSMutableDictionary alloc] init];
    [self load];
    [self migrateLegacyRecordIfNeeded];
    [self reopenTodayAutomaticallyCompletedRecordIfNeeded];
    return self;
}

- (NSString *)todayKey { return WorkDateKey([NSDate date]); }

- (NSString *)relevantDateKey {
    __block NSString *candidate = nil;
    [self.records enumerateKeysAndObjectsUsingBlock:^(NSString *dateKey, NSDictionary *record, BOOL *stop) {
        if ([record[@"completed"] boolValue]) return;
        if ([dateKey compare:self.todayKey] != NSOrderedDescending &&
            (!candidate || [dateKey compare:candidate] == NSOrderedDescending)) candidate = dateKey;
    }];
    return candidate ?: self.todayKey;
}

- (void)load {
    NSData *data = [NSData dataWithContentsOfURL:self.dataURL];
    if (!data) data = [NSData dataWithContentsOfURL:self.backupURL];
    if (!data) return;
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSDictionary *stored = [root isKindOfClass:NSDictionary.class] ? root[@"records"] : nil;
    if (![stored isKindOfClass:NSDictionary.class]) return;
    [stored enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *record, BOOL *stop) {
        if ([key isKindOfClass:NSString.class] && [record isKindOfClass:NSDictionary.class]) {
            self.records[key] = [record mutableCopy];
        }
    }];
}

- (void)persist {
    NSData *previous = [NSData dataWithContentsOfURL:self.dataURL];
    if (previous) [previous writeToURL:self.backupURL options:NSDataWritingAtomic error:nil];
    NSDictionary *root = @{ @"version": @2, @"records": self.records };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToURL:self.dataURL options:NSDataWritingAtomic error:nil];
}

- (void)migrateLegacyRecordIfNeeded {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *dateKey = [defaults stringForKey:@"workday.date"];
    NSNumber *start = [defaults objectForKey:@"workday.startMinutes"];
    if (!dateKey || !start || self.records[dateKey]) return;
    [self saveStartMinutes:start.integerValue forDateKey:dateKey];
    [defaults removeObjectForKey:@"workday.date"];
    [defaults removeObjectForKey:@"workday.startMinutes"];
}

- (void)reopenTodayAutomaticallyCompletedRecordIfNeeded {
    NSMutableDictionary *record = self.records[self.todayKey];
    if (!record || ![record[@"completed"] boolValue] || record[@"completionSource"]) return;
    if ([record[@"actualEnd"] integerValue] != [record[@"plannedEnd"] integerValue]) return;
    [record removeObjectForKey:@"actualEnd"];
    record[@"completed"] = @NO;
    record[@"updatedAt"] = @([NSDate date].timeIntervalSince1970);
    [self persist];
}

- (NSDictionary *)recordForDateKey:(NSString *)dateKey {
    return [self.records[dateKey] copy];
}

- (NSDictionary<NSString *,NSDictionary *> *)allRecords {
    NSMutableDictionary *copy = [[NSMutableDictionary alloc] init];
    [self.records enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *record, BOOL *stop) {
        copy[key] = [record copy];
    }];
    return copy;
}

- (void)saveStartMinutes:(NSInteger)minutes forDateKey:(NSString *)dateKey {
    [self saveStartMinutes:minutes plannedDurationMinutes:WorkDurationMinutes forDateKey:dateKey];
}

- (void)saveStartMinutes:(NSInteger)minutes
  plannedDurationMinutes:(NSInteger)plannedDurationMinutes
              forDateKey:(NSString *)dateKey {
    NSInteger safeStart = MIN(MAX(minutes, 0), 24 * 60 - 1);
    NSInteger safeDuration = MIN(MAX(plannedDurationMinutes, 1), 24 * 60);
    self.records[dateKey] = [@{
        @"start": @(safeStart),
        @"plannedDuration": @(safeDuration),
        @"plannedEnd": @(safeStart + safeDuration),
        @"completed": @NO,
        @"updatedAt": @([NSDate date].timeIntervalSince1970)
    } mutableCopy];
    [self persist];
}

- (void)saveCompletedRecordForDateKey:(NSString *)dateKey
                         startMinutes:(NSInteger)startMinutes
                           endMinutes:(NSInteger)endMinutes {
    [self saveCompletedRecordForDateKey:dateKey startMinutes:startMinutes endMinutes:endMinutes
                 plannedDurationMinutes:WorkDurationMinutes];
}

- (void)saveCompletedRecordForDateKey:(NSString *)dateKey
                         startMinutes:(NSInteger)startMinutes
                           endMinutes:(NSInteger)endMinutes
               plannedDurationMinutes:(NSInteger)plannedDurationMinutes {
    NSInteger safeDuration = MIN(MAX(plannedDurationMinutes, 1), 24 * 60);
    self.records[dateKey] = [@{
        @"start": @(startMinutes),
        @"plannedDuration": @(safeDuration),
        @"plannedEnd": @(startMinutes + safeDuration),
        @"actualEnd": @(endMinutes),
        @"completed": @YES,
        @"completionSource": @"edited",
        @"updatedAt": @([NSDate date].timeIntervalSince1970)
    } mutableCopy];
    [self persist];
}

- (void)updatePlannedDurationMinutes:(NSInteger)minutes forUncompletedDateKey:(NSString *)dateKey {
    NSMutableDictionary *record = self.records[dateKey];
    if (!record || [record[@"completed"] boolValue]) return;
    NSInteger safeDuration = MIN(MAX(minutes, 1), 24 * 60);
    record[@"plannedDuration"] = @(safeDuration);
    record[@"plannedEnd"] = @([record[@"start"] integerValue] + safeDuration);
    record[@"updatedAt"] = @([NSDate date].timeIntervalSince1970);
    [self persist];
}

- (void)completeRecordForDateKey:(NSString *)dateKey endMinutes:(NSInteger)endMinutes {
    NSMutableDictionary *record = self.records[dateKey];
    if (!record) return;
    record[@"actualEnd"] = @(endMinutes);
    record[@"completed"] = @YES;
    record[@"completionSource"] = @"manual";
    record[@"updatedAt"] = @([NSDate date].timeIntervalSince1970);
    [self persist];
}

- (void)deleteRecordForDateKey:(NSString *)dateKey {
    if (!self.records[dateKey]) return;
    [self.records removeObjectForKey:dateKey];
    [self persist];
}

- (BOOL)finalizeDueRecords {
    // Never infer a clock-out time. An unfinished shift remains live, including
    // overtime, until the user explicitly clocks out or edits the record.
    return NO;
}
@end

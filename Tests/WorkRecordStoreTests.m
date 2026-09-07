#import <Foundation/Foundation.h>
#import "WorkRecordStore.h"

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        Assert([WorkFormatClock(9 * 60) isEqualToString:@"09:00"], @"same-day clock formatting");
        Assert([WorkFormatClock(25 * 60 + 5) isEqualToString:@"次日 01:05"], @"overnight clock formatting");
        Assert([WorkFormatDuration(510) isEqualToString:@"8小时30分"], @"duration formatting");

        WorkRecordStore *store = [[WorkRecordStore alloc] init];
        NSString *today = store.todayKey;
        [store saveStartMinutes:9 * 60 + 10 forDateKey:today];
        NSDictionary *planned = [store recordForDateKey:today];
        Assert([planned[@"plannedEnd"] integerValue] == 17 * 60 + 40, @"8.5 hour expected end");
        Assert(![planned[@"completed"] boolValue], @"new shift remains active");

        [store saveStartMinutes:8 * 60 plannedDurationMinutes:7 * 60 + 45 forDateKey:today];
        NSDictionary *customPlan = [store recordForDateKey:today];
        Assert([customPlan[@"plannedDuration"] integerValue] == 7 * 60 + 45,
               @"custom standard duration is stored with the shift");
        Assert([customPlan[@"plannedEnd"] integerValue] == 15 * 60 + 45,
               @"custom expected end is calculated correctly");
        [store updatePlannedDurationMinutes:8 * 60 forUncompletedDateKey:today];
        customPlan = [store recordForDateKey:today];
        Assert([customPlan[@"plannedEnd"] integerValue] == 16 * 60,
               @"active shift follows a changed schedule");

        [store completeRecordForDateKey:today endMinutes:18 * 60 + 5];
        NSDictionary *completed = [store recordForDateKey:today];
        Assert([completed[@"completed"] boolValue], @"manual clock-out completes shift");
        Assert([completed[@"actualEnd"] integerValue] - [completed[@"start"] integerValue] == 605,
               @"actual duration is retained");

        NSString *past = @"2020-01-02";
        [store saveStartMinutes:23 * 60 forDateKey:past];
        Assert(![store finalizeDueRecords], @"unfinished shifts are never silently auto-finalized");
        NSDictionary *archived = [store recordForDateKey:past];
        Assert(![archived[@"completed"] boolValue], @"forgotten clock-out remains pending for correction");
        Assert([store.relevantDateKey isEqualToString:past], @"latest unfinished shift stays active");

        WorkRecordStore *reloaded = [[WorkRecordStore alloc] init];
        Assert([[reloaded recordForDateKey:today][@"actualEnd"] integerValue] == 18 * 60 + 5,
               @"records survive reload");
        Assert([NSFileManager.defaultManager fileExistsAtPath:reloaded.dataURL.path], @"JSON data file exists");
        NSLog(@"PASS: WorkRecordStoreTests");
    }
    return 0;
}

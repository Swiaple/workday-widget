#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSInteger const WorkDurationMinutes;
FOUNDATION_EXPORT NSString *WorkDateKey(NSDate *date);
FOUNDATION_EXPORT NSDate *WorkDateFromKey(NSString *key);
FOUNDATION_EXPORT NSString *WorkFormatClock(NSInteger minutes);
FOUNDATION_EXPORT NSString *WorkFormatDuration(NSInteger minutes);

@interface WorkRecordStore : NSObject
@property (nonatomic, readonly) NSString *todayKey;
@property (nonatomic, readonly) NSURL *dataURL;
- (NSString *)relevantDateKey;
- (NSDictionary *)recordForDateKey:(NSString *)dateKey;
- (NSDictionary<NSString *, NSDictionary *> *)allRecords;
- (void)saveStartMinutes:(NSInteger)minutes forDateKey:(NSString *)dateKey;
- (void)saveStartMinutes:(NSInteger)minutes
  plannedDurationMinutes:(NSInteger)plannedDurationMinutes
              forDateKey:(NSString *)dateKey;
- (void)saveCompletedRecordForDateKey:(NSString *)dateKey
                         startMinutes:(NSInteger)startMinutes
                           endMinutes:(NSInteger)endMinutes;
- (void)saveCompletedRecordForDateKey:(NSString *)dateKey
                         startMinutes:(NSInteger)startMinutes
                           endMinutes:(NSInteger)endMinutes
               plannedDurationMinutes:(NSInteger)plannedDurationMinutes;
- (void)updatePlannedDurationMinutes:(NSInteger)minutes forUncompletedDateKey:(NSString *)dateKey;
- (void)completeRecordForDateKey:(NSString *)dateKey endMinutes:(NSInteger)endMinutes;
- (void)deleteRecordForDateKey:(NSString *)dateKey;
- (BOOL)finalizeDueRecords;
@end

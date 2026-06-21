#import "TelemetryManager.h"
#import "SupabaseClient.h"
#import <UIKit/UIKit.h>

@interface TelemetryManager () {
    dispatch_queue_t _queue;
    NSMutableDictionary *_buffers; // feature -> NSMutableArray of event dicts
    NSInteger _totalBufferedCount;
}
@end

@implementation TelemetryManager

+ (instancetype)sharedManager {
    static TelemetryManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 创建一个专用的串行队列，保证所有状态修改和磁盘落盘是线程安全的
        _queue = dispatch_queue_create("com.kidschinese.telemetry", DISPATCH_QUEUE_SERIAL);
        _buffers = [NSMutableDictionary dictionary];
        _totalBufferedCount = 0;
        
        // 监听应用退到后台的通知，在退到后台前强制落盘与同步
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAppBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public API

- (void)recordEventWithFeature:(NSString *)feature
                    targetWord:(NSString *)word
                    wrongInput:(NSString *)input
                     errorType:(NSString *)errorType
                          book:(NSInteger)book
                        lesson:(NSInteger)lesson {
    if (!feature || feature.length == 0) return;
    
    // 异步分发至串行队列，避免任何卡顿和主线程竞争
    dispatch_async(_queue, ^{
        NSString *userId = [[SupabaseClient sharedClient] currentUserIdFromToken];
        if (!userId || userId.length == 0) {
            return; // 未登录时不记录，保持旁路静默
        }
        
        NSMutableArray *featureBuffer = self->_buffers[feature];
        if (!featureBuffer) {
            featureBuffer = [NSMutableArray array];
            self->_buffers[feature] = featureBuffer;
        }
        
        // 构建平面的轻量级事件数据
        NSDictionary *event = @{
            @"target_word": word ?: @"",
            @"wrong_input": input ?: @"",
            @"error_type": errorType ?: @"",
            @"timestamp": @((long)[[NSDate date] timeIntervalSince1970])
        };
        
        [featureBuffer addObject:event];
        self->_totalBufferedCount++;
        
        // 存储该 Feature 最新的 Book/Lesson 进度，用于同步时对齐 user_progress
        [self storeLastPositionForFeature:feature book:book lesson:lesson userId:userId];
        
        // 达到 20 条阈值，落盘至 NSUserDefaults 并清空内存
        if (self->_totalBufferedCount >= 20) {
            [self localFlushWithUserId:userId];
        }
    });
}

- (void)flushAndSync {
    dispatch_async(_queue, ^{
        NSString *userId = [[SupabaseClient sharedClient] currentUserIdFromToken];
        if (!userId || userId.length == 0) return;
        
        // 1. 将当前内存中缓存的所有事件强制刷入 UserDefaults
        if (self->_totalBufferedCount > 0) {
            [self localFlushWithUserId:userId];
        }
        
        // 2. 静默在后台上传所有待同步的数据
        [self syncPendingEventsWithUserId:userId];
    });
}

#pragma mark - Private Methods

- (void)handleAppBackground {
    [self flushAndSync];
}

- (void)storeLastPositionForFeature:(NSString *)feature book:(NSInteger)book lesson:(NSInteger)lesson userId:(NSString *)userId {
    NSString *posKey = [NSString stringWithFormat:@"telemetry_last_pos_%@_%@", userId, feature];
    NSDictionary *pos = @{
        @"book": @(book),
        @"lesson": @(lesson)
    };
    [[NSUserDefaults standardUserDefaults] setObject:pos forKey:posKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 必须在 _queue 串行队列中执行
- (void)localFlushWithUserId:(NSString *)userId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 读取目前未同步的 Feature 列表
    NSString *unsyncedKey = [NSString stringWithFormat:@"telemetry_unsynced_features_%@", userId];
    NSArray *unsyncedArray = [defaults arrayForKey:unsyncedKey] ?: @[];
    NSMutableSet *unsyncedSet = [NSMutableSet setWithArray:unsyncedArray];
    
    [self->_buffers enumerateKeysAndObjectsUsingBlock:^(NSString *feature, NSMutableArray *events, BOOL *stop) {
        if (events.count == 0) return;
        
        NSString *historyKey = [NSString stringWithFormat:@"telemetry_history_%@_%@", userId, feature];
        NSArray *existingEvents = [defaults arrayForKey:historyKey] ?: @[];
        NSMutableArray *newHistory = [NSMutableArray arrayWithArray:existingEvents];
        [newHistory addObjectsFromArray:events];
        
        // 核心内存优化：单 Feature 错题及埋点数上限设为 100 条，超出部分丢弃，防止爆内存/请求体超限
        if (newHistory.count > 100) {
            [newHistory removeObjectsInRange:NSMakeRange(0, newHistory.count - 100)];
        }
        
        [defaults setObject:newHistory forKey:historyKey];
        [unsyncedSet addObject:feature];
    }];
    
    [defaults setObject:[unsyncedSet allObjects] forKey:unsyncedKey];
    [defaults synchronize];
    
    [self->_buffers removeAllObjects];
    self->_totalBufferedCount = 0;
}

// 必须在 _queue 串行队列中执行
- (void)syncPendingEventsWithUserId:(NSString *)userId {
    if (![[SupabaseClient sharedClient] isAvailable]) return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *unsyncedKey = [NSString stringWithFormat:@"telemetry_unsynced_features_%@", userId];
    NSArray *unsyncedFeatures = [defaults arrayForKey:unsyncedKey];
    if (unsyncedFeatures.count == 0) return;
    
    for (NSString *feature in unsyncedFeatures) {
        NSString *historyKey = [NSString stringWithFormat:@"telemetry_history_%@_%@", userId, feature];
        NSArray *events = [defaults arrayForKey:historyKey];
        if (events.count == 0) {
            [self markFeatureSynced:feature userId:userId];
            continue;
        }
        
        // 读取存储的课程定位，防止覆盖进度
        NSString *posKey = [NSString stringWithFormat:@"telemetry_last_pos_%@_%@", userId, feature];
        NSDictionary *pos = [defaults dictionaryForKey:posKey];
        NSInteger book = [pos[@"book"] integerValue] ?: 1;
        NSInteger lesson = [pos[@"lesson"] integerValue] ?: 1;
        
        // 异步静默调用 Supabase 进行 upsert，把整个本地最新缓存覆盖到 telemetry_data 列上
        [[SupabaseClient sharedClient] saveProgressWithFeature:feature
                                                   bookNumber:book
                                                 lessonNumber:lesson
                                                    wordIndex:-1
                                                telemetryData:events
                                                   completion:^(NSError *error) {
            if (!error) {
                // 成功后在串行队列中安全修改未同步状态
                dispatch_async(self->_queue, ^{
                    [self markFeatureSynced:feature userId:userId];
                });
            } else {
                NSLog(@"[Telemetry] Sync failed for %@: %@", feature, error.localizedDescription);
            }
        }];
    }
}

// 必须在 _queue 串行队列中执行
- (void)markFeatureSynced:(NSString *)feature userId:(NSString *)userId {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *unsyncedKey = [NSString stringWithFormat:@"telemetry_unsynced_features_%@", userId];
    NSArray *unsyncedArray = [defaults arrayForKey:unsyncedKey] ?: @[];
    NSMutableArray *newUnsynced = [NSMutableArray arrayWithArray:unsyncedArray];
    [newUnsynced removeObject:feature];
    
    [defaults setObject:newUnsynced forKey:unsyncedKey];
    [defaults synchronize];
    NSLog(@"[Telemetry] Successfully synced telemetry for feature: %@", feature);
}

@end

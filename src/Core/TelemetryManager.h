#import <Foundation/Foundation.h>

@interface TelemetryManager : NSObject

+ (instancetype)sharedManager;

/**
 * 记录一条无感旁路学习事件
 *
 * @param feature 游戏/模块标识 (e.g. @"game1", @"pinyin", @"fullspell")
 * @param word 目标汉字
 * @param input 用户的错误输入/选择
 * @param errorType 错误类型 (e.g. @"char_mixup", @"pinyin_typo", @"order_wrong")
 * @param book 册数
 * @param lesson 课数
 */
- (void)recordEventWithFeature:(NSString *)feature
                    targetWord:(NSString *)word
                    wrongInput:(NSString *)input
                     errorType:(NSString *)errorType
                          book:(NSInteger)book
                        lesson:(NSInteger)lesson;

/**
 * 将内存缓冲区中的数据立即刷入 NSUserDefaults，并在后台尝试同步到 Supabase
 * 通常在用户退出游戏或 App 退到后台时调用
 */
- (void)flushAndSync;

@end

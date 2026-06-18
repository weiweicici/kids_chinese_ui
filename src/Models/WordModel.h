#import <Foundation/Foundation.h>

@interface WordModel : NSObject

@property (assign, nonatomic) NSInteger bookNumber;
@property (assign, nonatomic) NSInteger lessonNumber;
@property (assign, nonatomic) NSInteger wordIndex; // 1-indexed (1-16)
@property (strong, nonatomic) NSString *character;
@property (strong, nonatomic) NSString *pinyinWithTone;
@property (strong, nonatomic) NSString *pinyinWithoutTone;

// Optional override: if set, strokeGifName returns this directly
@property (strong, nonatomic) NSString *strokeGifNameOverride;

// Computed helpers for asset paths
- (NSString *)audioFileName;        // e.g. "1-1-1.mp3"
- (NSString *)strokeGifName;        // e.g. "1_ch1.gif" (1-160 for lessons 1-10)
- (BOOL)hasStrokeGif;

@end

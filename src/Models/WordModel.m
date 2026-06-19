#import "WordModel.h"

static NSDictionary *_strokeMapCache = nil;
static NSDictionary *_gifToCharCache = nil; // gifIndex (NSNumber) -> character (NSString)

@implementation WordModel

- (NSString *)audioFileName {
    return [NSString stringWithFormat:@"%ld-%ld-%ld.mp3", 
            (long)self.bookNumber, 
            (long)self.lessonNumber, 
            (long)self.wordIndex];
}

- (NSDictionary *)strokeMapForBook:(NSInteger)bookNumber {
    NSString *cacheKey = [NSString stringWithFormat:@"stroke_map_%ld", (long)bookNumber];
    NSDictionary *map = [_strokeMapCache objectForKey:cacheKey];
    if (!map) {
        NSString *mapName = [NSString stringWithFormat:@"stroke_map_%ld", (long)bookNumber];
        NSString *path = [[NSBundle mainBundle] pathForResource:mapName ofType:@"json" inDirectory:@"ChineseWordmp3"];
        if (path) {
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (data) {
                map = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (map) {
                    if (!_strokeMapCache) {
                        _strokeMapCache = [[NSMutableDictionary alloc] init];
                    }
                    [(NSMutableDictionary *)_strokeMapCache setObject:map forKey:cacheKey];
                }
            }
        }
    }
    return map;
}

- (NSDictionary *)gifToCharMap {
    if (_gifToCharCache) return _gifToCharCache;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"stroke_map_detail" ofType:@"json" inDirectory:@"ChineseWordmp3"];
    if (!path) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    NSArray *entries = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![entries isKindOfClass:[NSArray class]]) return nil;
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    for (NSDictionary *entry in entries) {
        NSNumber *gif = entry[@"gif"];
        NSString *ch = entry[@"char"];
        if (gif && ch) {
            map[gif] = ch;
        }
    }
    _gifToCharCache = map;
    return map;
}

- (NSString *)strokeGifName {
    if (self.strokeGifNameOverride) {
        return self.strokeGifNameOverride;
    }
    if (![self hasStrokeGif]) {
        return nil;
    }
    NSInteger gifIndex = (self.lessonNumber - 1) * 16 + self.wordIndex;
    return [NSString stringWithFormat:@"%ld_ch%ld.gif", (long)self.bookNumber, (long)gifIndex];
}

- (BOOL)hasStrokeGif {
    if (self.strokeGifNameOverride) return YES;
    if (self.bookNumber >= 2 && self.lessonNumber <= 10) return YES;
    if (self.bookNumber == 1 && self.lessonNumber <= 10) {
        NSInteger gifIndex = (self.lessonNumber - 1) * 16 + self.wordIndex;
        NSDictionary *g2c = [self gifToCharMap];
        if (g2c) {
            NSString *expectedChar = g2c[@(gifIndex)];
            if ([expectedChar isEqualToString:self.character]) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Book %ld Lesson %ld Word %ld: %@ (%@)", 
            (long)self.bookNumber, (long)self.lessonNumber, (long)self.wordIndex, 
            self.character, self.pinyinWithTone];
}

@end

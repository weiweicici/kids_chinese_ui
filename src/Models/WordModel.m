#import "WordModel.h"

static NSDictionary *_strokeMapCache = nil;

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

- (NSString *)strokeGifName {
    if (![self hasStrokeGif]) {
        return nil;
    }
    // If plist provides a direct GIF name override, use it
    if (self.strokeGifNameOverride) {
        return self.strokeGifNameOverride;
    }
    NSInteger gifIndex = (self.lessonNumber - 1) * 16 + self.wordIndex;
    NSDictionary *map = [self strokeMapForBook:self.bookNumber];
    if (map) {
        NSString *key = [NSString stringWithFormat:@"%ld", (long)gifIndex];
        NSNumber *corrected = [map objectForKey:key];
        if (corrected) {
            gifIndex = [corrected integerValue];
        }
    }
    return [NSString stringWithFormat:@"%ld_ch%ld.gif", (long)self.bookNumber, (long)gifIndex];
}

- (BOOL)hasStrokeGif {
    // GIFs are only provided for the first 10 lessons of each book (up to index 160)
    return self.lessonNumber <= 10;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Book %ld Lesson %ld Word %ld: %@ (%@)", 
            (long)self.bookNumber, (long)self.lessonNumber, (long)self.wordIndex, 
            self.character, self.pinyinWithTone];
}

@end

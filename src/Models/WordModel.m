#import "WordModel.h"

@implementation WordModel

- (NSString *)audioFileName {
    return [NSString stringWithFormat:@"%ld-%ld-%ld.mp3", 
            (long)self.bookNumber, 
            (long)self.lessonNumber, 
            (long)self.wordIndex];
}

- (NSString *)strokeGifName {
    if (![self hasStrokeGif]) {
        return nil;
    }
    NSInteger gifIndex = (self.lessonNumber - 1) * 16 + self.wordIndex;
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

#import "LessonModel.h"

@implementation LessonModel

- (NSString *)readAloudAudioFileName {
    return [NSString stringWithFormat:@"%ld-%ld.mp3", (long)self.bookNumber, (long)self.lessonNumber];
}

- (NSString *)readAlongAudioFileName {
    return [NSString stringWithFormat:@"%ld-%lda.mp3", (long)self.bookNumber, (long)self.lessonNumber];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Book %ld Lesson %ld: %lu words", 
            (long)self.bookNumber, (long)self.lessonNumber, (unsigned long)self.words.count];
}

@end

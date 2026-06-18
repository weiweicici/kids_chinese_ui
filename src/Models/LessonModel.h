#import <Foundation/Foundation.h>
#import "WordModel.h"

@interface LessonModel : NSObject

@property (assign, nonatomic) NSInteger bookNumber;
@property (assign, nonatomic) NSInteger lessonNumber;
@property (strong, nonatomic) NSArray<WordModel *> *words;

// Full-lesson audio filenames
- (NSString *)readAloudAudioFileName;   // e.g. "1-1.mp3"
- (NSString *)readAlongAudioFileName;   // e.g. "1-1a.mp3"

@end

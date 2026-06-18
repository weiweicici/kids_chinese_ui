#import <Foundation/Foundation.h>
#import "LessonModel.h"
#import "WordModel.h"

@interface TextbookManager : NSObject

+ (instancetype)sharedManager;

// Load data files (automatic on first access)
- (void)loadAllTextbooks;

// Data Access
- (NSArray<LessonModel *> *)lessonsForBook:(NSInteger)bookNumber;
- (LessonModel *)lessonForBook:(NSInteger)bookNumber lesson:(NSInteger)lessonNumber;
- (WordModel *)wordForBook:(NSInteger)bookNumber lesson:(NSInteger)lessonNumber wordIndex:(NSInteger)wordIndex;

@end

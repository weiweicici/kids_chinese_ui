#import "BaseViewController.h"
#import "LessonModel.h"

@interface MainScreenViewController : BaseViewController

@property (assign, nonatomic) NSInteger currentBook;
@property (assign, nonatomic) NSInteger currentLesson;

// Reloads UI with the current book and lesson models
- (void)reloadLessonData;

@end

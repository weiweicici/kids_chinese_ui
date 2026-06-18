#import "BaseViewController.h"

@interface FlashcardViewController : BaseViewController

@property (assign, nonatomic) NSInteger currentBook;
@property (assign, nonatomic) NSInteger currentLesson;
@property (assign, nonatomic) NSInteger selectedWordIndex; // 1-indexed (1-16)

@end

#import "BaseViewController.h"

@interface Game1ViewController : BaseViewController

@property (assign, nonatomic) NSInteger currentBook;
@property (assign, nonatomic) NSInteger currentLesson;
@property (assign, nonatomic) BOOL isShuffled; // NO = easy (sequential), YES = hard (shuffled)

@end

#import "BaseViewController.h"

@interface FlashcardViewController : BaseViewController

@property (assign, nonatomic) NSInteger currentBook;
@property (assign, nonatomic) NSInteger currentLesson;
@property (assign, nonatomic) NSInteger selectedWordIndex; // 1-indexed (1-16)

// Game mode (认读游戏)
@property (assign, nonatomic) BOOL isGameMode;
@property (assign, nonatomic) BOOL isShuffled; // NO = easy (sequential), YES = hard (shuffled)

@end

#import "PinyinMainViewController.h"
#import "TextbookManager.h"
#import "AudioManager.h"
#import "SquishyButton.h"
#import <QuartzCore/QuartzCore.h>

@interface PinyinMainViewController ()

@property (strong, nonatomic) NSMutableArray<WordModel *> *words;
@property (strong, nonatomic) NSMutableArray<UIView *> *gridCells;
@property (strong, nonatomic) NSMutableArray<UILabel *> *charLabels;
@property (strong, nonatomic) NSMutableArray<UILabel *> *pinyinLabels;
@property (strong, nonatomic) NSMutableArray<UIView *> *underlineViews;

@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UIButton *pinyinBtn;
@property (assign, nonatomic) BOOL showingPinyin;

@property (strong, nonatomic) UIView *pickerOverlay;
@property (assign, nonatomic) NSInteger selectedBookForPicker;

// Footer
@property (strong, nonatomic) UILabel *footerModeLabel;
@property (strong, nonatomic) SquishyButton *footerStartBtn;
@property (strong, nonatomic) SquishyButton *footerReturnBtn;
@property (strong, nonatomic) SquishyButton *footerReplayBtn;
@property (strong, nonatomic) UILabel *footerProgressLabel;
@property (strong, nonatomic) UIView *footerView;
@property (strong, nonatomic) NSMutableArray *footerGameBtns;

// Game state
@property (assign, nonatomic) BOOL gameActive;
@property (assign, nonatomic) BOOL gameModeEasy;
@property (assign, nonatomic) BOOL fullSpell; // YES = 全文拼写 mode
@property (strong, nonatomic) NSMutableArray *remainingIndices;
@property (strong, nonatomic) NSMutableArray *currentOrder;
@property (strong, nonatomic) NSMutableArray *gridOrder; // word index per grid position (shuffled for 难 mode)
@property (assign, nonatomic) NSInteger currentTargetIdx;
@property (assign, nonatomic) NSInteger gameStep;
@property (strong, nonatomic) NSMutableDictionary *charResults;
@property (strong, nonatomic) NSMutableDictionary *userInputs; // wordIndex → user typed pinyin
@property (assign, nonatomic) NSInteger correctCount;
@property (assign, nonatomic) NSInteger totalAttempts;
@property (strong, nonatomic) NSString *savedKey;
@property (strong, nonatomic) UIView *gameDimView;
@property (strong, nonatomic) UIView *topNavBar;
@property (strong, nonatomic) SquishyButton *fullSpellCheckBtn;
@property (strong, nonatomic) SquishyButton *fullSpellRestartBtn;
@property (strong, nonatomic) UIView *popupCard;

// Spelling game
@property (assign, nonatomic) BOOL spellingActive;
@property (assign, nonatomic) BOOL spellingStarted;
@property (assign, nonatomic) NSInteger spellingIndex;
@property (strong, nonatomic) UIView *spellingCard;
@property (strong, nonatomic) UIView *spellingTopBar;
@property (strong, nonatomic) UITextField *spellingInput;
@property (strong, nonatomic) UILabel *spellingCharLabel;
@property (strong, nonatomic) UIView *spellingUnderline;
@property (strong, nonatomic) UIView *spellingResultBar;
@property (strong, nonatomic) SquishyButton *spellingStartBtn;

@property (strong, nonatomic) UILabel *popupCharLabel;
@property (strong, nonatomic) UIView *popupLine;
@property (strong, nonatomic) UITextField *popupInput;
@property (strong, nonatomic) UIView *popupResultBar;
@property (assign, nonatomic) NSInteger popupCharIndex;

- (void)updateSavedKey;

@end

@implementation PinyinMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.currentBook = 1;
    self.currentLesson = 1;
    self.selectedBookForPicker = 1;
    self.words = [NSMutableArray array];
    self.gridCells = [NSMutableArray array];
    self.charLabels = [NSMutableArray array];
    self.pinyinLabels = [NSMutableArray array];
    self.underlineViews = [NSMutableArray array];
    self.showingPinyin = NO;

    self.gameActive = NO;
    self.gameModeEasy = YES;
    self.fullSpell = NO;
    self.remainingIndices = [NSMutableArray array];
    self.currentOrder = [NSMutableArray array];
    self.charResults = [NSMutableDictionary dictionary];
    self.userInputs = [NSMutableDictionary dictionary];
    self.popupCharIndex = -1;

    [self setupUI];
    [self reloadLessonData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[AudioManager sharedManager] stopCurrentSound];
}

#pragma mark - UI Setup

- (void)setupUI {
    // TopBar
    UIView *topNavBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 80.0f)];
    self.topNavBar = topNavBar;
    topNavBar.backgroundColor = [[self backgroundColor] colorWithAlphaComponent:0.95f];
    UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 79.5f, 768.0f, 0.5f)];
    topSeparator.backgroundColor = [self surfaceContainerColor];
    [topNavBar addSubview:topSeparator];

    // Back button
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(4, 20, 40, 40);
    [backBtn setTitle:@"◀" forState:UIControlStateNormal];
    [backBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont systemFontOfSize:22];
    [backBtn addTarget:self action:@selector(backBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:backBtn];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(56, 16, 200, 48)];
    self.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:20];
    self.titleLabel.textColor = [self onSurfaceColor];
    [topNavBar addSubview:self.titleLabel];

    SquishyButton *recordBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(252, 16, 80, 48)
                                                     backgroundColor:[self surfaceContainerColor]
                                                         shadowColor:[self onSurfaceVariantColor]
                                                        cornerRadius:16];
    [recordBtn setTitle:@"📝记录" forState:UIControlStateNormal];
    [recordBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    recordBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [recordBtn addTarget:self action:@selector(comingSoonAlert) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:recordBtn];

    self.pinyinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pinyinBtn.frame = CGRectMake(352, 16, 64, 48);
    self.pinyinBtn.backgroundColor = [self primaryContainerColor];
    self.pinyinBtn.layer.cornerRadius = 16;
    [self.pinyinBtn setTitle:@"拼音" forState:UIControlStateNormal];
    [self.pinyinBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    self.pinyinBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.pinyinBtn addTarget:self action:@selector(pinyinToggled) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:self.pinyinBtn];

    SquishyButton *chapterBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(436, 16, 64, 48)
                                                     backgroundColor:[self surfaceContainerColor]
                                                         shadowColor:[self onSurfaceVariantColor]
                                                        cornerRadius:16];
    [chapterBtn setTitle:@"📚目录" forState:UIControlStateNormal];
    [chapterBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    chapterBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [chapterBtn addTarget:self action:@selector(chapterBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:chapterBtn];

    UIButton *awardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    awardBtn.frame = CGRectMake(714, 16, 44, 48);
    awardBtn.backgroundColor = [self secondaryContainerColor];
    awardBtn.layer.cornerRadius = 22;
    awardBtn.titleLabel.font = [UIFont systemFontOfSize:24];
    [awardBtn setTitle:@"🏆" forState:UIControlStateNormal];
    [awardBtn addTarget:self action:@selector(awardBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:awardBtn];

    [self.canvasView addSubview:topNavBar];

    // Footer — 5 game entry buttons (normal) + game footer items (hidden during normal)
    self.footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 904.0f, 768.0f, 120.0f)];
    self.footerView.backgroundColor = [self backgroundColor];
    UIView *botSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 0.5f)];
    botSeparator.backgroundColor = [self surfaceContainerColor];
    [self.footerView addSubview:botSeparator];

    // 5 game entry buttons (normal mode)
    self.footerGameBtns = [NSMutableArray array];
    NSArray *gameTitles = @[@"拼音游戏(易)", @"拼音游戏(难)", @"拼写游戏", @"全文拼写(易)", @"全文拼写(难)"];
    SEL gameActions[] = {@selector(startGameWithSender:), @selector(startGameWithSender:), @selector(startSpellingGame), @selector(startGameWithSender:), @selector(startGameWithSender:)};
    CGFloat btnW = 120;
    CGFloat btnH = 64;
    CGFloat spacing = (768.0f - 40 * 2 - btnW * 5) / 4;
    if (spacing < 6) spacing = 6;
    CGFloat startX = 40;

    for (NSInteger i = 0; i < 5; i++) {
        SquishyButton *btn = [[SquishyButton alloc] initWithFrame:CGRectMake(startX + i * (btnW + spacing), 28, btnW, btnH)
                                                   backgroundColor:[self surfaceContainerColor]
                                                       shadowColor:[self onSurfaceVariantColor]
                                                      cornerRadius:12];
        [btn setTitle:gameTitles[i] forState:UIControlStateNormal];
        [btn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:13];
        btn.titleLabel.numberOfLines = 2;
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        btn.tag = i;
        [btn addTarget:self action:gameActions[i] forControlEvents:UIControlEventTouchUpInside];
        [self.footerView addSubview:btn];
        [self.footerGameBtns addObject:btn];
    }

    // Game mode footer items (hidden in normal mode)
    self.footerModeLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 32, 160, 48)];
    self.footerModeLabel.text = @"拼音游戏(易)";
    self.footerModeLabel.font = [UIFont boldSystemFontOfSize:18];
    self.footerModeLabel.textColor = [self onSurfaceVariantColor];
    self.footerModeLabel.adjustsFontSizeToFitWidth = YES;
    self.footerModeLabel.minimumScaleFactor = 0.6;
    self.footerModeLabel.hidden = YES;
    [self.footerView addSubview:self.footerModeLabel];

    self.footerProgressLabel = [[UILabel alloc] initWithFrame:CGRectMake(324, 28, 120, 56)];
    self.footerProgressLabel.textAlignment = NSTextAlignmentCenter;
    self.footerProgressLabel.font = [UIFont boldSystemFontOfSize:24];
    self.footerProgressLabel.textColor = [self primaryColor];
    self.footerProgressLabel.hidden = YES;
    [self.footerView addSubview:self.footerProgressLabel];

    self.footerReturnBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(604, 28, 120, 56)
                                               backgroundColor:[self surfaceContainerColor]
                                                   shadowColor:[self onSurfaceVariantColor]
                                                  cornerRadius:16];
    [self.footerReturnBtn setTitle:@"返回" forState:UIControlStateNormal];
    [self.footerReturnBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    self.footerReturnBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.footerReturnBtn.hidden = YES;
    [self.footerReturnBtn addTarget:self action:@selector(returnBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:self.footerReturnBtn];

    self.footerReplayBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(200, 28, 110, 56)
                                                 backgroundColor:[self primaryContainerColor]
                                                     shadowColor:[self primaryColor]
                                                    cornerRadius:16];
    [self.footerReplayBtn setTitle:@"🔊 重播" forState:UIControlStateNormal];
    [self.footerReplayBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    self.footerReplayBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.footerReplayBtn.hidden = YES;
    [self.footerReplayBtn addTarget:self action:@selector(replayTargetSound) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:self.footerReplayBtn];

    [self.canvasView addSubview:self.footerView];

    // 4x4 grid area
    CGFloat gridW = 768.0f;
    CGFloat cellW = gridW / 4;
    CGFloat gridTop = 110.0f;
    CGFloat cellH = 198.0f;

    for (NSInteger i = 0; i < 16; i++) {
        NSInteger col = i % 4;
        NSInteger row = i / 4;
        CGFloat x = col * cellW;
        CGFloat y = row * cellH;

        UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(x, y + gridTop, cellW, cellH)];
        cell.backgroundColor = [UIColor clearColor];
        cell.tag = i;

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cellTapped:)];
        [cell addGestureRecognizer:tap];

        UILabel *charLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, cellW, cellH)];
        charLabel.textAlignment = NSTextAlignmentCenter;
        charLabel.font = [UIFont boldSystemFontOfSize:120];
        charLabel.textColor = [UIColor darkTextColor];
        charLabel.adjustsFontSizeToFitWidth = YES;
        charLabel.minimumScaleFactor = 0.5;
        [cell addSubview:charLabel];
        [self.charLabels addObject:charLabel];

        UILabel *pyLabel = [[UILabel alloc] initWithFrame:CGRectMake(4, 1, cellW - 8, 30)];
        pyLabel.textAlignment = NSTextAlignmentCenter;
        pyLabel.font = [UIFont boldSystemFontOfSize:28];
        pyLabel.textColor = [UIColor blackColor];
        pyLabel.adjustsFontSizeToFitWidth = YES;
        pyLabel.minimumScaleFactor = 0.5;
        pyLabel.hidden = YES;
        [cell addSubview:pyLabel];
        [self.pinyinLabels addObject:pyLabel];

        UIView *uline = [[UIView alloc] initWithFrame:CGRectMake(cellW * 0.3, 33, cellW * 0.4, 1.5)];
        uline.backgroundColor = [UIColor lightGrayColor];
        uline.hidden = YES;
        [cell addSubview:uline];
        [self.underlineViews addObject:uline];

        [self.canvasView addSubview:cell];
        [self.gridCells addObject:cell];
    }
}

#pragma mark - Data

- (void)updateSavedKey {
    NSString *prefix = self.fullSpell ? @"fullspell" : @"pinyin";
    self.savedKey = [NSString stringWithFormat:@"%@_progress_b%ld_l%ld_%@",
                     prefix,
                     (long)self.currentBook,
                     (long)self.currentLesson,
                     self.gameModeEasy ? @"easy" : @"hard"];
}

- (void)reloadLessonData {
    // Clear game state when switching lessons
    self.gameActive = NO;
    self.fullSpell = NO;
    self.correctCount = 0;
    self.totalAttempts = 0;
    self.gameStep = 0;
    [self.remainingIndices removeAllObjects];
    [self.currentOrder removeAllObjects];
    [self.charResults removeAllObjects];
    [self.userInputs removeAllObjects];
    [self resetGameState];
    self.showingPinyin = NO;
    self.pinyinBtn.alpha = 1.0f;
    if (self.gameDimView) {
        [self.gameDimView removeFromSuperview];
        self.gameDimView = nil;
    }
    if (self.popupCard) {
        [self.popupCard removeFromSuperview];
        self.popupCard = nil;
    }

    // Clean grid UI
    for (NSInteger i = 0; i < 16; i++) {
        UIView *cell = self.gridCells[i];
        cell.backgroundColor = [UIColor clearColor];
        [self removeResultLabelFromCell:cell];
        self.underlineViews[i].hidden = !self.showingPinyin;
        self.pinyinLabels[i].hidden = !self.showingPinyin;
        self.pinyinLabels[i].backgroundColor = [UIColor clearColor];
        self.pinyinLabels[i].text = @"";
    }

    // Reset footer to normal
    for (SquishyButton *btn in self.footerGameBtns) {
        btn.hidden = NO;
    }
    self.footerModeLabel.hidden = YES;
    self.footerProgressLabel.hidden = YES;
    self.footerReplayBtn.hidden = YES;
    self.footerReturnBtn.hidden = YES;
    self.footerReturnBtn.enabled = YES;
    if (self.fullSpellCheckBtn) {
        [self.fullSpellCheckBtn removeFromSuperview];
        self.fullSpellCheckBtn = nil;
    }

    LessonModel *lesson = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    if (!lesson) {
        NSLog(@"Error: Lesson data not found for book %ld lesson %ld", (long)self.currentBook, (long)self.currentLesson);
        return;
    }

    self.words = (lesson.words) ? [lesson.words mutableCopy] : [NSMutableArray array];
    self.titleLabel.text = [NSString stringWithFormat:@"第%@册 第%ld课",
                            [self chineseNumberForBook:self.currentBook], (long)self.currentLesson];

    NSArray<WordModel *> *words = lesson.words;
    for (NSInteger i = 0; i < 16 && i < words.count; i++) {
        WordModel *word = words[i];
        UILabel *charLbl = self.charLabels[i];
        UILabel *pyLbl = self.pinyinLabels[i];
        charLbl.text = word.character;
        pyLbl.text = word.pinyinWithTone;
    }

    [self updateSavedKey];
    [self loadSavedProgress];
}

- (NSString *)chineseNumberForBook:(NSInteger)book {
    if (book == 1) return @"一";
    if (book == 2) return @"二";
    if (book == 3) return @"三";
    return [NSString stringWithFormat:@"%ld", (long)book];
}

#pragma mark - Actions

- (void)backBtnClicked {
    if (self.spellingActive) {
        [self exitSpellingGame];
        return;
    }
    if (self.gameActive) {
        [self exitGame];
        return;
    }
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Spelling Game

- (void)startSpellingGame {
    if (self.gameActive || self.spellingActive) return;
    self.spellingActive = YES;
    self.spellingStarted = NO;
    self.spellingIndex = 0;

    // Hide normal UI elements — blank background with only spelling top bar
    self.topNavBar.hidden = YES;
    self.footerView.hidden = YES;
    for (UIView *cell in self.gridCells) {
        cell.hidden = YES;
    }

    // Spelling mode top bar
    self.spellingTopBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 64.0f)];
    self.spellingTopBar.backgroundColor = [self surfaceContainerColor];

    CGFloat barW = 768.0f;
    CGFloat leftX = 20.0f;

    UILabel *modeLabel = [[UILabel alloc] initWithFrame:CGRectMake(leftX, 0, 120, 64)];
    modeLabel.text = @"📖 拼写游戏";
    modeLabel.font = [UIFont systemFontOfSize:16];
    modeLabel.textColor = [self onSurfaceColor];
    [self.spellingTopBar addSubview:modeLabel];

    SquishyButton *chapterBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(140, 12, 80, 40)
                                                     backgroundColor:[self surfaceContainerColor]
                                                         shadowColor:[self onSurfaceVariantColor]
                                                        cornerRadius:10];
    [chapterBtn setTitle:@"📚 目录" forState:UIControlStateNormal];
    [chapterBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    chapterBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [chapterBtn addTarget:self action:@selector(spellingChapterTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.spellingTopBar addSubview:chapterBtn];

    SquishyButton *resetBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(480, 12, 80, 40)
                                                    backgroundColor:[self surfaceContainerColor]
                                                        shadowColor:[self onSurfaceVariantColor]
                                                       cornerRadius:10];
    [resetBtn setTitle:@"🔄 重置" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [resetBtn addTarget:self action:@selector(spellingReset) forControlEvents:UIControlEventTouchUpInside];
    [self.spellingTopBar addSubview:resetBtn];

    self.spellingStartBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(580, 12, 80, 40)
                                                 backgroundColor:[self primaryContainerColor]
                                                     shadowColor:[self primaryColor]
                                                    cornerRadius:10];
    [self.spellingStartBtn setTitle:@"▶️ 开始" forState:UIControlStateNormal];
    [self.spellingStartBtn setTitleColor:[self primaryColor] forState:UIControlStateNormal];
    self.spellingStartBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.spellingStartBtn addTarget:self action:@selector(spellingStartTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.spellingTopBar addSubview:self.spellingStartBtn];

    SquishyButton *returnBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(barW - 100, 12, 80, 40)
                                                     backgroundColor:[self surfaceContainerColor]
                                                         shadowColor:[self onSurfaceVariantColor]
                                                        cornerRadius:10];
    [returnBtn setTitle:@"◀️ 返回" forState:UIControlStateNormal];
    [returnBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    returnBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [returnBtn addTarget:self action:@selector(exitSpellingGame) forControlEvents:UIControlEventTouchUpInside];
    [self.spellingTopBar addSubview:returnBtn];

    [self.canvasView addSubview:self.spellingTopBar];

    // Create spelling card — larger size
    CGFloat cardW = 700;
    CGFloat cardH = 540;
    CGFloat cardX = (768 - cardW) / 2;
    CGFloat cardY = 100;

    self.spellingCard = [[UIView alloc] initWithFrame:CGRectMake(cardX, cardY, cardW, cardH)];
    self.spellingCard.backgroundColor = [UIColor whiteColor];
    self.spellingCard.layer.cornerRadius = 24;
    self.spellingCard.clipsToBounds = YES;
    self.spellingCard.alpha = 0.0f;

    // Input field
    self.spellingInput = [[UITextField alloc] initWithFrame:CGRectMake(150, 60, 400, 56)];
    self.spellingInput.font = [UIFont systemFontOfSize:42];
    self.spellingInput.textAlignment = NSTextAlignmentCenter;
    self.spellingInput.placeholder = @"输入拼音...";
    self.spellingInput.keyboardType = UIKeyboardTypeASCIICapable;
    self.spellingInput.autocorrectionType = UITextAutocorrectionTypeNo;
    self.spellingInput.spellCheckingType = UITextSpellCheckingTypeNo;
    self.spellingInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.spellingInput.returnKeyType = UIReturnKeyDone;
    self.spellingInput.delegate = (id<UITextFieldDelegate>)self;
    [self.spellingCard addSubview:self.spellingInput];

    // Underline below input
    UIView *inputLine = [[UIView alloc] initWithFrame:CGRectMake(150, 124, 400, 2)];
    inputLine.backgroundColor = [UIColor lightGrayColor];
    inputLine.tag = 101;
    [self.spellingCard addSubview:inputLine];

    // Character label — bigger
    self.spellingCharLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 180, cardW, 240)];
    self.spellingCharLabel.font = [UIFont boldSystemFontOfSize:200];
    self.spellingCharLabel.textAlignment = NSTextAlignmentCenter;
    self.spellingCharLabel.textColor = [UIColor blackColor];
    [self.spellingCard addSubview:self.spellingCharLabel];

    // Underline below character
    self.spellingUnderline = [[UIView alloc] initWithFrame:CGRectMake((cardW - 100) / 2, 440, 100, 3)];
    self.spellingUnderline.backgroundColor = [UIColor blackColor];
    self.spellingUnderline.tag = 102;
    [self.spellingCard addSubview:self.spellingUnderline];

    [self.canvasView addSubview:self.spellingCard];

    [UIView animateWithDuration:0.3f animations:^{
        self.spellingCard.alpha = 1.0f;
    }];
}

- (void)exitSpellingGame {
    if (!self.spellingActive) return;
    self.spellingActive = NO;
    self.spellingStarted = NO;
    self.spellingIndex = 0;

    [self.spellingInput resignFirstResponder];

    if (self.spellingCard) {
        [self.spellingCard removeFromSuperview];
        self.spellingCard = nil;
    }
    if (self.spellingTopBar) {
        [self.spellingTopBar removeFromSuperview];
        self.spellingTopBar = nil;
    }
    if (self.spellingResultBar) {
        [self.spellingResultBar removeFromSuperview];
        self.spellingResultBar = nil;
    }
    self.spellingInput = nil;
    self.spellingCharLabel = nil;
    self.spellingUnderline = nil;
    self.spellingStartBtn = nil;

    // Restore normal UI
    self.topNavBar.hidden = NO;
    self.footerView.hidden = NO;
    for (UIView *cell in self.gridCells) {
        cell.hidden = NO;
    }
}

- (void)spellingStartTapped {
    if (self.words.count == 0) return;
    self.spellingStarted = YES;
    self.spellingIndex = 0;
    [self.spellingStartBtn setTitle:@"⏩ 继续" forState:UIControlStateNormal];

    [self showSpellingCardAtIndex:self.spellingIndex];
    [self.spellingInput becomeFirstResponder];
}

- (void)showSpellingCardAtIndex:(NSInteger)idx {
    if (idx < 0 || idx >= self.words.count) {
        idx = 0;
    }
    WordModel *word = self.words[idx];
    self.spellingCharLabel.text = word.character;
    self.spellingInput.text = @"";
    self.spellingInput.placeholder = @"输入拼音...";

    // Remove result bar if visible
    if (self.spellingResultBar) {
        [self.spellingResultBar removeFromSuperview];
        self.spellingResultBar = nil;
    }
    // Ensure input and underline visible
    UIView *inpLine = [self.spellingCard viewWithTag:101];
    inpLine.hidden = NO;
    self.spellingUnderline.hidden = NO;

    self.spellingInput.userInteractionEnabled = YES;
    [self.spellingInput becomeFirstResponder];
}

- (void)spellingSubmit {
    if (!self.spellingStarted || self.words.count == 0) return;
    NSString *input = [self.spellingInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (input.length == 0) return;

    WordModel *word = self.words[self.spellingIndex];
    NSString *expected = [word.pinyinWithoutTone lowercaseString];
    expected = [expected stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *userInput = [input lowercaseString];
    userInput = [userInput stringByReplacingOccurrencesOfString:@" " withString:@""];

    // Remove numbers from expected for comparison (so "han4" matches "han")
    NSString *expectedClean = expected;
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    expectedClean = [[expectedClean componentsSeparatedByCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] componentsJoinedByString:@""];

    CGFloat cardW = self.spellingCard.frame.size.width;
    CGFloat barY = 30;
    CGFloat barH = 440;
    self.spellingInput.userInteractionEnabled = NO;
    [self.spellingInput resignFirstResponder];

    if ([userInput isEqualToString:expectedClean]) {
        // Correct
        if (!self.spellingResultBar) {
            self.spellingResultBar = [[UIView alloc] initWithFrame:CGRectMake(0, barY, cardW, barH)];
            self.spellingResultBar.backgroundColor = [UIColor colorWithRed:0.1f green:0.8f blue:0.1f alpha:0.2f];
            [self.spellingCard addSubview:self.spellingResultBar];
        }
        UILabel *correctLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, barH - 60, cardW - 80, 40)];
        correctLabel.text = @"✅ 正确！";
        correctLabel.font = [UIFont boldSystemFontOfSize:28];
        correctLabel.textAlignment = NSTextAlignmentCenter;
        correctLabel.textColor = [UIColor colorWithRed:0.0f green:0.6f blue:0.0f alpha:1.0f];
        correctLabel.tag = 201;
        [self.spellingResultBar addSubview:correctLabel];

        [[AudioManager sharedManager] playSoundNamed:@"nizhenbang.caf"];

        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf spellingNextCard];
        });
    } else {
        // Wrong
        if (!self.spellingResultBar) {
            self.spellingResultBar = [[UIView alloc] initWithFrame:CGRectMake(0, barY, cardW, barH)];
            self.spellingResultBar.backgroundColor = [UIColor colorWithRed:0.8f green:0.1f blue:0.1f alpha:0.2f];
            [self.spellingCard addSubview:self.spellingResultBar];
        }
        UILabel *wrongLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, barH - 60, cardW - 80, 40)];
        wrongLabel.text = @"❌ 再试一次";
        wrongLabel.font = [UIFont boldSystemFontOfSize:28];
        wrongLabel.textAlignment = NSTextAlignmentCenter;
        wrongLabel.textColor = [UIColor colorWithRed:0.6f green:0.0f blue:0.0f alpha:1.0f];
        wrongLabel.tag = 201;
        [self.spellingResultBar addSubview:wrongLabel];

        [[AudioManager sharedManager] playSoundNamed:@"jixujiayou.caf"];

        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Re-enable input for retry
            weakSelf.spellingInput.userInteractionEnabled = YES;
            [weakSelf.spellingInput becomeFirstResponder];
            if (weakSelf.spellingResultBar) {
                [weakSelf.spellingResultBar removeFromSuperview];
                weakSelf.spellingResultBar = nil;
            }
            UIView *inpLine = [weakSelf.spellingCard viewWithTag:101];
            inpLine.hidden = NO;
            weakSelf.spellingUnderline.hidden = NO;
        });
    }
}
- (void)spellingNextCard {
    if (!self.spellingActive) return;
    self.spellingIndex++;
    if (self.spellingIndex >= self.words.count) {
        self.spellingIndex = 0;
    }

    // Slide animation: current card slides out bottom, new card slides in from top
    CGFloat cardW = 700;
    CGFloat cardH = 540;
    CGFloat cardX = (768 - cardW) / 2;
    CGFloat cardY = 100;

    // Create new card with next content
    UIView *newCard = [[UIView alloc] initWithFrame:CGRectMake(cardX, -cardH, cardW, cardH)];
    newCard.backgroundColor = [UIColor whiteColor];
    newCard.layer.cornerRadius = 24;
    newCard.clipsToBounds = YES;

    // Character label
    UILabel *newCharLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 180, cardW, 240)];
    newCharLabel.font = [UIFont boldSystemFontOfSize:200];
    newCharLabel.textAlignment = NSTextAlignmentCenter;
    newCharLabel.textColor = [UIColor blackColor];
    WordModel *word = self.words[self.spellingIndex];
    newCharLabel.text = word.character;
    [newCard addSubview:newCharLabel];

    // Underline
    UIView *newUnderline = [[UIView alloc] initWithFrame:CGRectMake((cardW - 100) / 2, 440, 100, 3)];
    newUnderline.backgroundColor = [UIColor blackColor];
    [newCard addSubview:newUnderline];

    // Input field
    UITextField *newInput = [[UITextField alloc] initWithFrame:CGRectMake(150, 60, 400, 56)];
    newInput.font = [UIFont systemFontOfSize:42];
    newInput.textAlignment = NSTextAlignmentCenter;
    newInput.placeholder = @"输入拼音...";
    newInput.keyboardType = UIKeyboardTypeASCIICapable;
    newInput.autocorrectionType = UITextAutocorrectionTypeNo;
    newInput.spellCheckingType = UITextSpellCheckingTypeNo;
    newInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    newInput.returnKeyType = UIReturnKeyDone;
    newInput.delegate = (id<UITextFieldDelegate>)self;
    [newCard addSubview:newInput];

    UIView *newInputLine = [[UIView alloc] initWithFrame:CGRectMake(150, 124, 400, 2)];
    newInputLine.backgroundColor = [UIColor lightGrayColor];
    [newCard addSubview:newInputLine];

    [self.canvasView addSubview:newCard];

    CGFloat bottomY = self.canvasView.frame.size.height;
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.35f delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        // Current card slides out bottom
        weakSelf.spellingCard.frame = CGRectMake(cardX, bottomY + 60, cardW, cardH);
        weakSelf.spellingCard.alpha = 0.5f;
        // New card slides in from top to position
        newCard.frame = CGRectMake(cardX, cardY, cardW, cardH);
    } completion:^(BOOL finished) {
        [weakSelf.spellingCard removeFromSuperview];
        weakSelf.spellingCard = newCard;
        weakSelf.spellingCharLabel = newCharLabel;
        weakSelf.spellingUnderline = newUnderline;
        weakSelf.spellingInput = newInput;
        weakSelf.spellingInput.userInteractionEnabled = YES;
        [weakSelf.spellingInput becomeFirstResponder];
        weakSelf.spellingResultBar = nil;
    }];
}

- (void)spellingReset {
    self.spellingIndex = 0;
    if (self.spellingStarted) {
        [self showSpellingCardAtIndex:0];
        [self.spellingInput becomeFirstResponder];
    }
}

- (void)spellingChapterTapped {
    [self showLessonPicker];
}

- (void)pickerLessonSelected:(UIButton *)sender {
    self.currentBook = self.selectedBookForPicker;
    self.currentLesson = sender.tag;
    [self reloadLessonData];
    [self dismissLessonPicker];

    // Reset spelling game state
    if (self.spellingActive) {
        // reloadLessonData resets visibility, restore spelling UI
        self.topNavBar.hidden = YES;
        self.footerView.hidden = YES;
        for (UIView *cell in self.gridCells) {
            cell.hidden = YES;
        }

        self.spellingIndex = 0;
        self.spellingStarted = NO;
        [self.spellingStartBtn setTitle:@"▶️ 开始" forState:UIControlStateNormal];
        if (self.spellingResultBar) {
            [self.spellingResultBar removeFromSuperview];
            self.spellingResultBar = nil;
        }
        if (self.words.count > 0) {
            [self showSpellingCardAtIndex:0];
        }
    }
}

- (void)comingSoonAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"敬请期待"
                                                                   message:@"该功能还在开发中"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)awardBtnClicked {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"我的荣誉"
                                                                   message:@"完成关卡游戏即可赢取奖杯奖励！"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"加油" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pinyinToggled {
    if (self.gameActive) return;
    self.showingPinyin = !self.showingPinyin;
    for (NSInteger i = 0; i < 16; i++) {
        self.pinyinLabels[i].hidden = !self.showingPinyin;
        self.underlineViews[i].hidden = !self.showingPinyin;
        UILabel *cl = self.charLabels[i];
        if (self.showingPinyin) {
            cl.frame = CGRectMake(0, 16, 192, 182);
        } else {
            cl.frame = CGRectMake(0, 0, 192, 198);
        }
    }
    self.pinyinBtn.alpha = self.showingPinyin ? 0.7f : 1.0f;
}

- (void)returnBtnClicked {
    if (self.spellingActive) {
        [self exitSpellingGame];
    } else if (self.gameActive) {
        [self exitGame];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)cellTapped:(UITapGestureRecognizer *)sender {
    UIView *cell = sender.view;
    NSInteger idx = cell.tag;
    if (idx < 0 || idx >= self.words.count) return;

    if (self.gameActive) {
        [self gameCellTapped:idx cell:cell];
    } else {
        WordModel *word = self.words[idx];
        [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];
        [UIView animateWithDuration:0.1f animations:^{
            cell.transform = CGAffineTransformMakeScale(0.92, 0.92);
            cell.backgroundColor = [UIColor colorWithRed:165.0f/255.0f green:214.0f/255.0f blue:167.0f/255.0f alpha:0.3f];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.15f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                cell.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                cell.backgroundColor = [UIColor clearColor];
            }];
        }];
    }
}

#pragma mark - Game

- (void)startGameWithSender:(UIButton *)sender {
    if (sender.tag == 0) {
        self.gameModeEasy = YES;
        self.fullSpell = NO;
    } else if (sender.tag == 1) {
        self.gameModeEasy = NO;
        self.fullSpell = NO;
    } else if (sender.tag == 3) {
        self.gameModeEasy = YES;
        self.fullSpell = YES;
        [self.charResults removeAllObjects];
        [self.userInputs removeAllObjects];
    } else if (sender.tag == 4) {
        self.gameModeEasy = NO;
        self.fullSpell = YES;
        [self.charResults removeAllObjects];
        [self.userInputs removeAllObjects];
    } else {
        return;
    }
    [self updateSavedKey];
    [self loadSavedProgress];
    [self beginGame];
}

- (void)beginGame {
    if (self.remainingIndices.count == 0) {
        [self resetGameState];
    }

    self.gameActive = YES;
    
    if (!self.fullSpell) {
        // Pinyin game mode
        self.correctCount = 16 - self.remainingIndices.count;
        if (self.remainingIndices.count == 16) {
            self.totalAttempts = 0;
            [self.charResults removeAllObjects];
        }
        self.gameStep = 0;
        [self setupGameOrder];
    } else {
        // Full spell mode
        self.correctCount = 0;
        [self.userInputs removeAllObjects];
        // Restore userInputs from charResults (saved as @"input")
        for (NSString *key in self.charResults) {
            NSDictionary *result = self.charResults[key];
            if (result[@"input"]) {
                self.userInputs[key] = result[@"input"];
            }
        }
    }

    // Build grid order based on mode
    NSMutableArray *gridOrder = [NSMutableArray arrayWithCapacity:16];
    for (NSInteger i = 0; i < 16; i++) {
        [gridOrder addObject:@(i)];
    }
    if (!self.gameModeEasy) {
        for (NSInteger i = 15; i > 0; i--) {
            [gridOrder exchangeObjectAtIndex:i withObjectAtIndex:arc4random_uniform((u_int32_t)(i + 1))];
        }
    }
    self.gridOrder = gridOrder;

    // Clean/setup grid
    for (NSInteger i = 0; i < 16; i++) {
        self.charLabels[i].backgroundColor = [UIColor clearColor];
        [self removeResultLabelFromCell:self.gridCells[i]];
        self.underlineViews[i].hidden = !self.fullSpell;
        self.underlineViews[i].backgroundColor = [UIColor lightGrayColor];
        self.pinyinLabels[i].backgroundColor = [UIColor clearColor];
        self.pinyinLabels[i].font = [UIFont boldSystemFontOfSize:30];
        self.pinyinLabels[i].hidden = !self.fullSpell;

        NSInteger wordIdx = [self.gridOrder[i] integerValue];
        if (wordIdx < (NSInteger)self.words.count) {
            // Use remainingIndices to determine if word is already solved (not remaining = hidden)
            BOOL isSolved = ![self.remainingIndices containsObject:@(wordIdx)];
            
            if (isSolved && self.fullSpell) {
                self.charLabels[i].text = @"";
                self.pinyinLabels[i].text = @"";
                self.underlineViews[i].hidden = YES;
            } else {
                self.charLabels[i].text = self.words[wordIdx].character;
                // Show user input for fullSpell, empty for pinyin game
                if (self.fullSpell) {
                    NSString *savedInput = self.userInputs[[@(wordIdx) stringValue]];
                    self.pinyinLabels[i].text = savedInput ?: @"";
                    if (savedInput) {
                        self.pinyinLabels[i].font = [UIFont boldSystemFontOfSize:24];
                    }
                } else {
                    self.pinyinLabels[i].text = @"";
                }
                
                if (!self.fullSpell) {
                    // Restore visual feedback for pinyin game mode
                    id result = self.charResults[@(wordIdx)] ?: self.charResults[[NSString stringWithFormat:@"%ld", (long)wordIdx]];
                    if (result) {
                        NSString *input = result[@"input"];
                        NSString *status = result[@"result"];
                        if ([status isEqualToString:@"correct"]) {
                            self.pinyinLabels[i].backgroundColor = [UIColor colorWithRed:0.2f green:0.8f blue:0.3f alpha:0.3f];
                        } else {
                            self.pinyinLabels[i].backgroundColor = [UIColor colorWithRed:1.0f green:0.2f blue:0.2f alpha:0.3f];
                        }
                        self.pinyinLabels[i].text = input;
                        self.pinyinLabels[i].font = [UIFont boldSystemFontOfSize:24];
                    }
                }
            }
        } else {
            self.charLabels[i].text = @"";
        }
    }

    // Show game footer, hide game entry buttons
    for (SquishyButton *btn in self.footerGameBtns) {
        btn.hidden = YES;
    }
    self.footerModeLabel.hidden = NO;
    self.footerModeLabel.text = [self modeNameString];
    self.footerProgressLabel.hidden = NO;
    [self updateFooterProgress];
    self.footerReturnBtn.hidden = NO;
    self.footerReturnBtn.enabled = YES;

    if (self.fullSpell) {
        self.footerReplayBtn.hidden = YES;
        // Create check button
        if (!self.fullSpellCheckBtn) {
            self.fullSpellCheckBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(190, 28, 110, 56)
                                                          backgroundColor:[self primaryContainerColor]
                                                              shadowColor:[self primaryColor]
                                                             cornerRadius:16];
            [self.fullSpellCheckBtn setTitle:@"✅ 检查" forState:UIControlStateNormal];
            [self.fullSpellCheckBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
            self.fullSpellCheckBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
            [self.fullSpellCheckBtn addTarget:self action:@selector(fullSpellCheckTapped) forControlEvents:UIControlEventTouchUpInside];
            [self.footerView addSubview:self.fullSpellCheckBtn];
        }
        self.fullSpellCheckBtn.hidden = NO;
        // Create restart button
        if (!self.fullSpellRestartBtn) {
            self.fullSpellRestartBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(450, 28, 100, 56)
                                                             backgroundColor:[self surfaceContainerColor]
                                                                 shadowColor:[self onSurfaceVariantColor]
                                                                cornerRadius:16];
            [self.fullSpellRestartBtn setTitle:@"🔄 重来" forState:UIControlStateNormal];
            [self.fullSpellRestartBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
            self.fullSpellRestartBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            [self.fullSpellRestartBtn addTarget:self action:@selector(fullSpellRestartTapped) forControlEvents:UIControlEventTouchUpInside];
            [self.footerView addSubview:self.fullSpellRestartBtn];
        }
        self.fullSpellRestartBtn.hidden = NO;
    } else {
        self.footerReplayBtn.hidden = NO;
        // Remove check button if exists
    if (self.fullSpellCheckBtn) {
        [self.fullSpellCheckBtn removeFromSuperview];
        self.fullSpellCheckBtn = nil;
    }
    if (self.fullSpellRestartBtn) {
        [self.fullSpellRestartBtn removeFromSuperview];
        self.fullSpellRestartBtn = nil;
    }
    }

    // Dim overlay — remove old first to prevent accumulation
    if (self.gameDimView) {
        [self.gameDimView removeFromSuperview];
        self.gameDimView = nil;
    }
    self.gameDimView = [[UIView alloc] initWithFrame:self.canvasView.bounds];
    self.gameDimView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3f];
    self.gameDimView.userInteractionEnabled = NO;
    [self.canvasView addSubview:self.gameDimView];

    if (!self.fullSpell) {
        [self playCurrentTargetAudio];
    }
}

- (NSString *)modeNameString {
    if (self.fullSpell) {
        return self.gameModeEasy ? @"全文拼写(易)" : @"全文拼写(难)";
    }
    return self.gameModeEasy ? @"拼音游戏(易)" : @"拼音游戏(难)";
}

- (void)resetGameState {
    [self.remainingIndices removeAllObjects];
    for (NSInteger i = 0; i < 16; i++) {
        [self.remainingIndices addObject:@(i)];
    }
}

- (void)setupGameOrder {
    [self.currentOrder removeAllObjects];
    if (self.remainingIndices.count == 0) {
        [self resetGameState];
    } else {
        [self.currentOrder addObjectsFromArray:self.remainingIndices];
    }

    // Shuffle so audio plays in random order
    for (NSInteger i = self.currentOrder.count - 1; i > 0; i--) {
        [self.currentOrder exchangeObjectAtIndex:i withObjectAtIndex:arc4random_uniform((u_int32_t)(i + 1))];
    }
}

- (void)playCurrentTargetAudio {
    // Skip already answered words in the current playlist
    while (self.gameStep < self.currentOrder.count) {
        NSInteger idx = [self.currentOrder[self.gameStep] integerValue];
        if ([self.remainingIndices containsObject:@(idx)]) {
            break;
        }
        self.gameStep++;
    }

    if (self.gameStep >= self.currentOrder.count) {
        self.gameStep = 0;
        [self setupGameOrder];
    }

    // Double check after potentially rebuilding order
    if (self.remainingIndices.count == 0) {
        [self finishGame];
        return;
    }
    
    if (self.currentOrder.count == 0) {
        [self finishGame];
        return;
    }

    NSInteger idx = [self.currentOrder[self.gameStep] integerValue];
    self.currentTargetIdx = idx;
    WordModel *word = self.words[idx];
    [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];
}

- (void)replayTargetSound {
    if (self.gameActive && self.currentTargetIdx >= 0 && self.currentTargetIdx < (NSInteger)self.words.count) {
        WordModel *word = self.words[self.currentTargetIdx];
        [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];
    }
}

- (void)gameCellTapped:(NSInteger)idx cell:(UIView *)cell {
    if (self.popupCard) return;

    NSInteger wordIdx = [self.gridOrder[idx] integerValue];
    
    if (self.fullSpell) {
        // In full spell mode: any remaining word can be tapped
        if ([self.remainingIndices containsObject:@(wordIdx)]) {
            [self showPopupForCharIndex:wordIdx];
        }
        return;
    }
    
    // Pinyin game mode
    // Check if they tapped a previously correct/wrong cell
    id result = self.charResults[@(wordIdx)] ?: self.charResults[[NSString stringWithFormat:@"%ld", (long)wordIdx]];
    BOOL isPreviouslyWrong = result && [result[@"result"] isEqualToString:@"wrong"];
    BOOL isPreviouslyCorrect = result && [result[@"result"] isEqualToString:@"correct"];

    if (wordIdx == self.currentTargetIdx || isPreviouslyWrong) {
        // Allow typing if it is the current target OR a previously wrong word
        [self showPopupForCharIndex:wordIdx];
    } else if (isPreviouslyCorrect) {
        // Just play the character pronunciation, do NOT count as a wrong attempt
        if (wordIdx < (NSInteger)self.words.count) {
            WordModel *word = self.words[wordIdx];
            [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];
        }
    } else {
        // Wrong character — feedback
        [[AudioManager sharedManager] playSoundNamed:@"cuola.caf"];
        // BUG FIX: use weak self to avoid retaining deallocated VC
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [[AudioManager sharedManager] playSoundNamed:@"jixujiayou.caf"];
        });

        [UIView animateWithDuration:0.1f animations:^{
            cell.backgroundColor = [UIColor colorWithRed:1.0f green:0.2f blue:0.2f alpha:0.3f];
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3f animations:^{
                cell.backgroundColor = [UIColor clearColor];
            }];
        }];

        // Replay current target audio after a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf playCurrentTargetAudio];
        });
    }
}

#pragma mark - Popup Card

- (void)showPopupForCharIndex:(NSInteger)idx {
    self.popupCharIndex = idx;
    WordModel *word = self.words[idx];

    if (!self.fullSpell) {
        [[AudioManager sharedManager] stopCurrentSound];
    }

    if (self.popupCard) {
        [self.popupCard removeFromSuperview];
    }

    CGFloat cardW = 620;
    CGFloat cardH = 520;
    CGFloat cardX = (768 - cardW) / 2;
    CGFloat cardY = 80;

    self.popupCard = [[UIView alloc] initWithFrame:CGRectMake(cardX, cardY, cardW, cardH)];
    self.popupCard.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.92f];
    self.popupCard.layer.cornerRadius = 24;
    self.popupCard.clipsToBounds = YES;
    self.popupCard.layer.shadowColor = [UIColor blackColor].CGColor;
    self.popupCard.layer.shadowOpacity = 0.25;
    self.popupCard.layer.shadowRadius = 12;
    self.popupCard.layer.shadowOffset = CGSizeMake(0, 4);

    // Disable dim underneath while card is shown
    self.gameDimView.userInteractionEnabled = YES;

    // [确认] [返回] at top
    UIButton *confirmBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    confirmBtn.frame = CGRectMake(24, 16, 100, 44);
    confirmBtn.backgroundColor = [self primaryContainerColor];
    confirmBtn.layer.cornerRadius = 16;
    [confirmBtn setTitle:@"确认" forState:UIControlStateNormal];
    [confirmBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    confirmBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [confirmBtn addTarget:self action:@selector(submitPinyin) forControlEvents:UIControlEventTouchUpInside];
    [self.popupCard addSubview:confirmBtn];

    UIButton *returnPopupBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    returnPopupBtn.frame = CGRectMake(cardW - 24 - 100, 16, 100, 44);
    returnPopupBtn.backgroundColor = [self surfaceContainerColor];
    returnPopupBtn.layer.cornerRadius = 16;
    [returnPopupBtn setTitle:@"返回" forState:UIControlStateNormal];
    [returnPopupBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    returnPopupBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [returnPopupBtn addTarget:self action:@selector(dismissPopup) forControlEvents:UIControlEventTouchUpInside];
    [self.popupCard addSubview:returnPopupBtn];

    // Result bar (behind input + line, transparent initially)
    self.popupResultBar = [[UIView alloc] initWithFrame:CGRectMake(20, 75, cardW - 40, 85)];
    self.popupResultBar.backgroundColor = [UIColor clearColor];
    self.popupResultBar.layer.cornerRadius = 12;
    [self.popupCard addSubview:self.popupResultBar];

    // Text field
    self.popupInput = [[UITextField alloc] initWithFrame:CGRectMake(80, 90, cardW - 160, 50)];
    self.popupInput.borderStyle = UITextBorderStyleRoundedRect;
    self.popupInput.keyboardType = UIKeyboardTypeASCIICapable;
    self.popupInput.autocorrectionType = UITextAutocorrectionTypeNo;
    self.popupInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.popupInput.spellCheckingType = UITextSpellCheckingTypeNo;
    self.popupInput.returnKeyType = UIReturnKeyDone;
    self.popupInput.placeholder = @"输入拼音";
    self.popupInput.font = [UIFont systemFontOfSize:28];
    self.popupInput.textAlignment = NSTextAlignmentCenter;
    self.popupInput.delegate = (id<UITextFieldDelegate>)self;
    [self.popupCard addSubview:self.popupInput];

    // Line below input
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(80, 150, cardW - 160, 1.5)];
    line.backgroundColor = [UIColor lightGrayColor];
    [self.popupCard addSubview:line];

    // Character
    self.popupCharLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 230, cardW - 40, 240)];
    self.popupCharLabel.textAlignment = NSTextAlignmentCenter;
    self.popupCharLabel.font = [UIFont boldSystemFontOfSize:150];
    self.popupCharLabel.textColor = [UIColor darkTextColor];
    self.popupCharLabel.text = word.character;
    [self.popupCard addSubview:self.popupCharLabel];

    // Pre-fill input if user has previously typed for this word (fullSpell)
    if (self.fullSpell) {
        NSString *savedInput = self.userInputs[[@(idx) stringValue]];
        if (savedInput) {
            self.popupInput.text = savedInput;
        }
    }

    [self.canvasView addSubview:self.popupCard];

    // Animate in
    self.popupCard.transform = CGAffineTransformMakeScale(0.8, 0.8);
    self.popupCard.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{
        self.popupCard.transform = CGAffineTransformIdentity;
        self.popupCard.alpha = 1;
    } completion:^(BOOL finished) {
        [self.popupInput becomeFirstResponder];
    }];
}

- (void)submitPinyin {
    if (!self.popupCard || self.popupCharIndex < 0) return;

    NSInteger idx = self.popupCharIndex;
    self.popupCharIndex = -1; // Guard against double submission immediately!

    NSString *input = self.popupInput.text ?: @"";
    input = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    input = [input lowercaseString];
    input = [input stringByReplacingOccurrencesOfString:@"v" withString:@"ü"];
    input = [input stringByReplacingOccurrencesOfString:@"u:" withString:@"ü"];

    if (self.fullSpell) {
        // Full spell: just save input, no correct/wrong marking
        self.userInputs[[@(idx) stringValue]] = input;
        
        // Show user input on grid pinyin label
        NSInteger gridPos = 0;
        for (NSInteger i = 0; i < 16; i++) {
            if ([self.gridOrder[i] integerValue] == idx) {
                gridPos = i;
                break;
            }
        }
        self.pinyinLabels[gridPos].text = input;
        self.pinyinLabels[gridPos].font = [UIFont boldSystemFontOfSize:24];
        
        // Clear result bar (no feedback in full spell)
        self.popupResultBar.backgroundColor = [UIColor clearColor];
        
        [self saveGameProgress];
        [self updateFooterProgress];
        
        // Check if all 16 words have been filled
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.fullSpell) {
                if (strongSelf.userInputs.count >= 16) {
                    [strongSelf fullSpellEvaluate];
                } else {
                    [strongSelf closePopupAndContinue];
                }
            }
        });
        return;
    }

    // Pinyin game mode logic below
    WordModel *word = self.words[idx];
    NSString *expected = [word.pinyinWithoutTone lowercaseString];

    BOOL correct = [input isEqualToString:expected];

    // Find grid position where this word is displayed
    NSInteger gridPos = 0;
    for (NSInteger i = 0; i < 16; i++) {
        if ([self.gridOrder[i] integerValue] == idx) {
            gridPos = i;
            break;
        }
    }

    UIView *cell = self.gridCells[gridPos];
    UILabel *pyLbl = self.pinyinLabels[gridPos];
    self.totalAttempts++;

    if (correct) {
        self.correctCount++;
        self.popupResultBar.backgroundColor = [UIColor colorWithRed:0.2f green:0.8f blue:0.3f alpha:0.3f];
        [[AudioManager sharedManager] playSoundNamed:@"nizhenbang.caf"];

        // Update grid pinyin area: green background + user input
        pyLbl.backgroundColor = [UIColor colorWithRed:0.2f green:0.8f blue:0.3f alpha:0.3f];
        pyLbl.text = input;
        pyLbl.font = [UIFont boldSystemFontOfSize:24];

        self.charResults[@(idx)] = @{@"result": @"correct", @"input": input};
        [self.remainingIndices removeObject:@(idx)];
        
        if (idx == self.currentTargetIdx) {
            self.gameStep++;
        }
    } else {
        self.popupResultBar.backgroundColor = [UIColor colorWithRed:1.0f green:0.2f blue:0.2f alpha:0.3f];
        [[AudioManager sharedManager] playSoundNamed:@"jixujiayou.caf"];

        // Update grid pinyin area: red background + user input
        pyLbl.backgroundColor = [UIColor colorWithRed:1.0f green:0.2f blue:0.2f alpha:0.3f];
        pyLbl.text = input;
        pyLbl.font = [UIFont boldSystemFontOfSize:24];

        self.charResults[@(idx)] = @{@"result": @"wrong", @"input": input};
        
        if (idx == self.currentTargetIdx) {
            self.gameStep++;
        }
    }

    [self updateFooterProgress];

    // BUG FIX: use weak self — if user exits game in 2s window VC may be deallocated
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        PinyinMainViewController *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.popupCard) return; // already dismissed
        [strongSelf closePopupAndContinue];
    });
}

- (void)removeResultLabelFromCell:(UIView *)cell {
    for (UIView *sub in cell.subviews) {
        if (sub.tag == 888) {
            [sub removeFromSuperview];
        }
    }
}

- (void)dismissPopup {
    if (!self.popupCard) return;
    [self.popupInput resignFirstResponder];
    [self closePopupAndContinue];
}

- (void)closePopupAndContinue {
    [self.popupCard removeFromSuperview];
    self.popupCard = nil;
    self.popupCharIndex = -1;
    self.popupInput.delegate = nil;
    self.popupInput = nil;
    self.popupCharLabel = nil;
    self.popupResultBar = nil;

    if (self.gameDimView) {
        self.gameDimView.userInteractionEnabled = NO;
    }

    if (self.fullSpell) {
        // In full spell mode, don't auto-advance audio
        // Evaluation is triggered from submitPinyin or check button
        return;
    }

    if (self.correctCount >= 16 || self.remainingIndices.count == 0) {
        [self finishGame];
    } else {
        [self playCurrentTargetAudio];
    }
}

- (void)updateFooterProgress {
    self.footerProgressLabel.text = [NSString stringWithFormat:@"%ld/16", (long)self.correctCount];
}

- (void)fullSpellCheckTapped {
    [self fullSpellEvaluate];
}

- (void)fullSpellRestartTapped {
    if (self.popupCard) {
        [self.popupCard removeFromSuperview];
        self.popupCard = nil;
    }
    [self.userInputs removeAllObjects];
    [self.charResults removeAllObjects];
    [self resetGameState];
    self.correctCount = 0;
    [self saveGameProgress];
    // Rebuild grid
    [self beginGame];
}

- (void)fullSpellEvaluate {
    if (self.fullSpellCheckBtn) {
        self.fullSpellCheckBtn.enabled = NO;
    }
    
    NSInteger correctWords = 0;
    NSInteger totalChecked = 0;
    NSMutableArray *correctWordIndices = [NSMutableArray array];
    
    // Compare all userInputs against expected pinyin
    for (NSString *key in self.userInputs) {
        NSInteger wordIdx = [key integerValue];
        NSString *userInput = self.userInputs[key];
        WordModel *word = self.words[wordIdx];
        NSString *expected = [word.pinyinWithoutTone lowercaseString];
        
        BOOL isCorrect = [userInput isEqualToString:expected];
        totalChecked++;
        
        if (isCorrect) {
            correctWords++;
            [correctWordIndices addObject:@(wordIdx)];
            
            // Mark as correct in charResults
            self.charResults[key] = @{@"result": @"correct", @"input": userInput};
            
            // Find grid position and animate disappearance
            NSInteger gridPos = NSNotFound;
            for (NSInteger i = 0; i < 16; i++) {
                if ([self.gridOrder[i] integerValue] == wordIdx) {
                    gridPos = i;
                    break;
                }
            }
            
            if (gridPos != NSNotFound) {
                UILabel *charLbl = self.charLabels[gridPos];
                UILabel *pyLbl = self.pinyinLabels[gridPos];
                UIView *uline = self.underlineViews[gridPos];
                
                // "撕日历" animation: shrink + fade
                [UIView animateWithDuration:0.4 animations:^{
                    charLbl.transform = CGAffineTransformMakeScale(0.01, 0.01);
                    charLbl.alpha = 0;
                    pyLbl.alpha = 0;
                    uline.alpha = 0;
                } completion:^(BOOL finished) {
                    charLbl.text = @"";
                    charLbl.transform = CGAffineTransformIdentity;
                    charLbl.alpha = 1;
                    pyLbl.alpha = 1;
                    uline.hidden = YES;
                    uline.alpha = 1;
                }];
            }
        } else {
            // Mark as wrong in charResults (clear input for retry)
            self.charResults[key] = @{@"result": @"wrong", @"input": userInput};
            // Clear userInput so popup shows blank next time
            [self.userInputs removeObjectForKey:key];
            
            // Clear the grid pinyin display for wrong words
            NSInteger gridPos2 = NSNotFound;
            for (NSInteger i = 0; i < 16; i++) {
                if ([self.gridOrder[i] integerValue] == wordIdx) {
                    gridPos2 = i;
                    break;
                }
            }
            if (gridPos2 != NSNotFound) {
                self.pinyinLabels[gridPos2].text = @"";
            }
        }
    }
    
    // Remove correct words from remainingIndices
    for (NSNumber *correctIdx in correctWordIndices) {
        [self.remainingIndices removeObject:correctIdx];
    }
    
    self.correctCount += correctWords;
    [self updateFooterProgress];
    [self saveGameProgress];
    
    NSInteger wrongCount = totalChecked - correctWords;
    
    if (self.fullSpellCheckBtn) {
        self.fullSpellCheckBtn.enabled = YES;
    }
    
    if (self.remainingIndices.count == 0) {
        // All done!
        [self finishGame];
        return;
    }
    
    // Show result alert
    NSString *message = [NSString stringWithFormat:@"已完成 16/16\n其中 %ld 个正确，%ld 个错误\n请修改后重新检查",
                         (long)correctWords, (long)wrongCount];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"检查结果"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)finishGame {
    [[AudioManager sharedManager] playSoundNamed:@"nizhenbang.caf"];
    [self showConfetti];
    [self saveGameProgress];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self exitGame];
    });
}

- (void)exitGame {
    self.gameActive = NO;
    [self saveGameProgress];

    if (self.popupCard) {
        [self.popupCard removeFromSuperview];
        self.popupCard = nil;
    }
    if (self.gameDimView) {
        [self.gameDimView removeFromSuperview];
        self.gameDimView = nil;
    }

    // Clean up fullSpell check button
    if (self.fullSpellCheckBtn) {
        [self.fullSpellCheckBtn removeFromSuperview];
        self.fullSpellCheckBtn = nil;
    }
    if (self.fullSpellRestartBtn) {
        [self.fullSpellRestartBtn removeFromSuperview];
        self.fullSpellRestartBtn = nil;
    }

    [self stopConfetti];

    // Restore grid to normal
    for (NSInteger i = 0; i < 16; i++) {
        self.charLabels[i].backgroundColor = [UIColor clearColor];
        WordModel *w = (i < (NSInteger)self.words.count) ? self.words[i] : nil;
        self.charLabels[i].text = w ? w.character : @"";
        self.charLabels[i].transform = CGAffineTransformIdentity;
        self.charLabels[i].alpha = 1;
        self.underlineViews[i].hidden = !self.showingPinyin;
        self.underlineViews[i].backgroundColor = [UIColor lightGrayColor];
        self.underlineViews[i].alpha = 1;
        [self removeResultLabelFromCell:self.gridCells[i]];
        self.pinyinLabels[i].backgroundColor = [UIColor clearColor];
        self.pinyinLabels[i].text = w ? [w pinyinWithTone] : @"";
        self.pinyinLabels[i].font = [UIFont boldSystemFontOfSize:30];
        self.pinyinLabels[i].hidden = !self.showingPinyin;
        self.pinyinLabels[i].alpha = 1;
    }

    // Restore footer to game entry buttons
    for (SquishyButton *btn in self.footerGameBtns) {
        btn.hidden = NO;
    }
    self.footerModeLabel.hidden = YES;
    self.footerProgressLabel.hidden = YES;
    self.footerReplayBtn.hidden = YES;
    self.footerReturnBtn.hidden = YES;
    self.footerReturnBtn.enabled = YES;

    [self updateFooterModeLabel];

    self.gridOrder = nil;
}

- (void)updateFooterModeLabel {
    NSString *modeName = [self modeNameString];
    if (self.remainingIndices.count > 0 && self.remainingIndices.count < 16) {
        self.footerModeLabel.text = [NSString stringWithFormat:@"%@ (%ld/16)",
                                     modeName, (long)(16 - self.remainingIndices.count)];
    } else {
        self.footerModeLabel.text = modeName;
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (string.length == 0) return YES;
    for (NSUInteger i = 0; i < string.length; i++) {
        unichar c = [string characterAtIndex:i];
        if (c > 127 && c != 0x00FC) return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (self.spellingActive && self.spellingStarted) {
        [self spellingSubmit];
    } else {
        [self submitPinyin];
    }
    return NO;
}

#pragma mark - NSUserDefaults

- (void)saveGameProgress {
    NSMutableArray *remaining = [NSMutableArray array];
    for (NSNumber *n in self.remainingIndices) {
        [remaining addObject:n];
    }
    // BUG FIX: NSUserDefaults plist only supports NSString keys.
    // charResults uses @(idx) NSNumber keys → convert to string keys before saving.
    NSMutableDictionary *serializableResults = [NSMutableDictionary dictionary];
    for (id key in self.charResults) {
        NSString *strKey = [key isKindOfClass:[NSString class]] ? key : [key stringValue];
        serializableResults[strKey] = self.charResults[key];
    }
    NSDictionary *data = @{
        @"correct": @(self.correctCount),
        @"totalAttempts": @(self.totalAttempts),
        @"remaining": remaining,
        @"results": serializableResults,
        @"userInputs": (self.fullSpell && self.userInputs) ? self.userInputs : @{}
    };
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:self.savedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadSavedProgress {
    NSDictionary *data = [[NSUserDefaults standardUserDefaults] dictionaryForKey:self.savedKey];
    if (!data) {
        [self resetGameState];
        return;
    }
    self.correctCount = [data[@"correct"] integerValue];
    self.totalAttempts = [data[@"totalAttempts"] integerValue];
    NSArray *savedRemaining = data[@"remaining"];
    self.remainingIndices = savedRemaining ? [savedRemaining mutableCopy] : [NSMutableArray array];
    if (self.remainingIndices.count == 0) {
        [self resetGameState];
    }
    // BUG FIX: saved keys are NSString (converted in saveGameProgress), keep as-is
    NSDictionary *savedResults = data[@"results"];
    self.charResults = savedResults ? [savedResults mutableCopy] : [NSMutableDictionary dictionary];
    
    // Restore userInputs for fullSpell
    NSDictionary *savedInputs = data[@"userInputs"];
    if (savedInputs) {
        self.userInputs = [savedInputs mutableCopy];
    } else {
        [self.userInputs removeAllObjects];
    }

    // Only update footer label with saved progress text, do NOT touch grid UI
    [self updateFooterModeLabel];
}

#pragma mark - Confetti

- (void)showConfetti {
    CAEmitterLayer *emitter = [CAEmitterLayer layer];
    emitter.emitterPosition = CGPointMake(384, -20);
    emitter.emitterSize = CGSizeMake(768, 0);
    emitter.emitterShape = kCAEmitterLayerLine;
    emitter.emitterMode = kCAEmitterLayerOutline;
    emitter.seed = arc4random_uniform(1000);
    emitter.name = @"confetti";
    emitter.needsDisplayOnBoundsChange = NO;

    CGImageRef cgImage = [self confettiImage].CGImage;

    NSMutableArray *cells = [NSMutableArray array];
    NSArray *colors = @[
        (id)[UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.2 green:1.0 blue:0.2 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.2 green:0.2 blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:1.0 green:0.4 blue:0.7 alpha:1.0].CGColor,
    ];

    for (NSInteger i = 0; i < 5; i++) {
        CAEmitterCell *cell = [CAEmitterCell emitterCell];
        cell.contents = (__bridge id)cgImage;
        cell.color = (__bridge CGColorRef)colors[i % colors.count];
        cell.birthRate = 6;
        cell.lifetime = 8.0;
        cell.velocity = 200 + arc4random_uniform(150);
        cell.velocityRange = 80;
        cell.emissionLongitude = M_PI;
        cell.emissionRange = M_PI_4;
        cell.scale = 0.08;
        cell.scaleRange = 0.06;
        cell.spin = 2 * M_PI;
        cell.spinRange = M_PI;
        cell.yAcceleration = 80;
        [cells addObject:cell];
    }

    emitter.emitterCells = cells;
    [self.canvasView.layer addSublayer:emitter];
}

- (UIImage *)confettiImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(2, 2, 16, 16));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)stopConfetti {
    // BUG FIX: copy sublayers before iterating — removeFromSuperlayer mutates the array
    // causing "Collection was mutated while being enumerated" crash
    NSArray *sublayersCopy = [self.canvasView.layer.sublayers copy];
    for (CALayer *layer in sublayersCopy) {
        if ([layer.name isEqualToString:@"confetti"]) {
            [layer removeFromSuperlayer];
        }
    }
}

#pragma mark - Lesson Picker (matches MainScreen style)

- (void)chapterBtnClicked {
    [self showLessonPicker];
}

- (void)showLessonPicker {
    if (self.pickerOverlay) return;

    self.selectedBookForPicker = self.currentBook;

    self.pickerOverlay = [[UIView alloc] initWithFrame:self.canvasView.bounds];
    self.pickerOverlay.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];

    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissLessonPicker)];
    [self.pickerOverlay addGestureRecognizer:dismissTap];

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(134.0f, 212.0f, 500.0f, 600.0f)];
    container.backgroundColor = [self surfaceContainerLowestColor];
    container.layer.cornerRadius = 24.0f;
    container.clipsToBounds = YES;

    UITapGestureRecognizer *stopTap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [container addGestureRecognizer:stopTap];

    UILabel *pickerTitle = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 460.0f, 30.0f)];
    pickerTitle.text = @"选择课文章节";
    pickerTitle.textAlignment = NSTextAlignmentCenter;
    pickerTitle.font = [self fontWithName:@"Plus Jakarta Sans" size:22.0f];
    pickerTitle.textColor = [self primaryColor];
    [container addSubview:pickerTitle];

    UISegmentedControl *bookSegments = [[UISegmentedControl alloc] initWithItems:@[@"第一册", @"第二册", @"第三册"]];
    bookSegments.frame = CGRectMake(40.0f, 65.0f, 420.0f, 40.0f);
    bookSegments.selectedSegmentIndex = self.selectedBookForPicker - 1;
    [bookSegments addTarget:self action:@selector(pickerBookChanged:) forControlEvents:UIControlEventValueChanged];
    if ([bookSegments respondsToSelector:@selector(setTintColor:)]) {
        bookSegments.tintColor = [self primaryColor];
    }
    [container addSubview:bookSegments];

    UIView *lessonsGrid = [[UIView alloc] initWithFrame:CGRectMake(20.0f, 120.0f, 460.0f, 450.0f)];
    lessonsGrid.tag = 999;
    [container addSubview:lessonsGrid];

    [self rebuildPickerLessonsGridInsideContainer:lessonsGrid];

    [self.pickerOverlay addSubview:container];
    [self.canvasView addSubview:self.pickerOverlay];

    container.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
    self.pickerOverlay.alpha = 0.0f;
    [UIView animateWithDuration:0.25f animations:^{
        self.pickerOverlay.alpha = 1.0f;
        container.transform = CGAffineTransformIdentity;
    }];
}

- (void)pickerBookChanged:(UISegmentedControl *)sender {
    self.selectedBookForPicker = sender.selectedSegmentIndex + 1;

    UIView *grid = [sender.superview viewWithTag:999];
    if (grid) {
        for (UIView *v in grid.subviews) [v removeFromSuperview];
        [self rebuildPickerLessonsGridInsideContainer:grid];
    }
}

- (void)rebuildPickerLessonsGridInsideContainer:(UIView *)gridContainer {
    CGFloat btnW = 90.0f;
    CGFloat btnH = 60.0f;
    CGFloat gapX = 16.0f;
    CGFloat gapY = 16.0f;

    for (NSInteger i = 0; i < 20; i++) {
        NSInteger row = i / 4;
        NSInteger col = i % 4;
        NSInteger lessonNum = i + 1;

        CGFloat btnX = col * (btnW + gapX) + 20.0f;
        CGFloat btnY = row * (btnH + gapY) + 20.0f;

        UIColor *bgColor = [self surfaceContainerColor];
        UIColor *shadowColor = [self onSurfaceVariantColor];
        UIColor *textColor = [self onSurfaceColor];

        if (self.selectedBookForPicker == self.currentBook && lessonNum == self.currentLesson) {
            bgColor = [self primaryContainerColor];
            shadowColor = [self primaryColor];
        }

        SquishyButton *btn = [[SquishyButton alloc] initWithFrame:CGRectMake(btnX, btnY, btnW, btnH)
                                                   backgroundColor:bgColor
                                                       shadowColor:shadowColor
                                                      cornerRadius:12.0f];
        [btn setTitle:[NSString stringWithFormat:@"第%ld课", (long)lessonNum] forState:UIControlStateNormal];
        [btn setTitleColor:textColor forState:UIControlStateNormal];
        btn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:15.0f];
        btn.tag = lessonNum;
        [btn addTarget:self action:@selector(pickerLessonSelected:) forControlEvents:UIControlEventTouchUpInside];

        [gridContainer addSubview:btn];
    }
}

- (void)dismissLessonPicker {
    if (self.pickerOverlay) {
        UIView *container = self.pickerOverlay.subviews.firstObject;
        [UIView animateWithDuration:0.2f animations:^{
            self.pickerOverlay.alpha = 0.0f;
            container.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
        } completion:^(BOOL finished) {
            [self.pickerOverlay removeFromSuperview];
            self.pickerOverlay = nil;
        }];
    }
}

@end

#import "FlashcardViewController.h"
#import "TextbookManager.h"
#import "AudioManager.h"

#import "SquishyButton.h"

@interface FlashcardViewController ()

@property (strong, nonatomic) WordModel *wordModel;
@property (strong, nonatomic) UIView *cardView;
@property (strong, nonatomic) UILabel *pinyinLabel;
@property (strong, nonatomic) UILabel *charLabel;

@property (strong, nonatomic) UILabel *statusLabel;

// Game mode
@property (strong, nonatomic) UIView *footerView;
@property (strong, nonatomic) NSArray<WordModel *> *lessonWords;
@property (strong, nonatomic) NSArray<NSNumber *> *shuffledIndices;
@property (assign, nonatomic) NSInteger currentPlayIndex;
@property (assign, nonatomic) BOOL firstAppearance;
@property (assign, nonatomic) BOOL autoAdvancing;

@end

@implementation FlashcardViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.firstAppearance = YES;
    [self setupStaticUI];

    if (self.isGameMode) {
        [self setupGameModeUI];
    } else {
        [self reloadWordData];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.isGameMode && self.firstAppearance) {
        self.firstAppearance = NO;
        [self startAutoPlay];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopAutoAdvance];
    [[AudioManager sharedManager] stopCurrentSound];
}

#pragma mark - UI Setup

- (void)setupStaticUI {
    // 1. TopNavBar (frame: 0, 0, 768, 80)
    UIView *topNavBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 80.0f)];
    topNavBar.backgroundColor = [[self backgroundColor] colorWithAlphaComponent:0.95f];

    UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 79.5f, 768.0f, 0.5f)];
    topSeparator.backgroundColor = [self surfaceContainerColor];
    [topNavBar addSubview:topSeparator];

    UIView *bookIconView = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 16.0f, 48.0f, 48.0f)];
    bookIconView.backgroundColor = [self primaryContainerColor];
    bookIconView.layer.cornerRadius = 24.0f;

    UILabel *bookEmoji = [[UILabel alloc] initWithFrame:bookIconView.bounds];
    bookEmoji.text = @"✏️";
    bookEmoji.textAlignment = NSTextAlignmentCenter;
    bookEmoji.font = [UIFont systemFontOfSize:22.0f];
    [bookIconView addSubview:bookEmoji];
    [topNavBar addSubview:bookIconView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(100.0f, 16.0f, 180.0f, 48.0f)];
    titleLabel.text = @"考考你";
    titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:24.0f];
    titleLabel.textColor = [self primaryColor];
    [topNavBar addSubview:titleLabel];

    // Top Right control buttons
    SquishyButton *nextBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(320.0f, 16.0f, 130.0f, 48.0f)
                                                   backgroundColor:[self primaryContainerColor]
                                                       shadowColor:[self primaryColor]
                                                      cornerRadius:24.0f];
    [nextBtn setTitle:@"下一张卡片" forState:UIControlStateNormal];
    [nextBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    nextBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [nextBtn addTarget:self action:@selector(nextCardClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:nextBtn];

    SquishyButton *startBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(462.0f, 16.0f, 110.0f, 48.0f)
                                                    backgroundColor:[self primaryContainerColor]
                                                        shadowColor:[self primaryColor]
                                                       cornerRadius:24.0f];
    [startBtn setTitle:@"开始朗读" forState:UIControlStateNormal];
    [startBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    startBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [startBtn addTarget:self action:@selector(startBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:startBtn];

    SquishyButton *backBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(584.0f, 16.0f, 110.0f, 48.0f)
                                                  backgroundColor:[self primaryContainerColor]
                                                      shadowColor:[self primaryColor]
                                                     cornerRadius:24.0f];
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [backBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [backBtn addTarget:self action:@selector(backBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:backBtn];

    [self.canvasView addSubview:topNavBar];

    // 2. Giant Card (700x700, centered between nav bar and footer)
    self.cardView = [[UIView alloc] initWithFrame:CGRectMake(34.0f, 142.0f, 700.0f, 700.0f)];
    self.cardView.backgroundColor = [self surfaceContainerLowestColor];
    self.cardView.layer.cornerRadius = 40.0f;
    self.cardView.layer.shadowColor = [self primaryColor].CGColor;
    self.cardView.layer.shadowOpacity = 0.08f;
    self.cardView.layer.shadowRadius = 15.0f;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 10.0f);
    [self.canvasView addSubview:self.cardView];

    // Pinyin text at top of giant card
    self.pinyinLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 30.0f, 660.0f, 45.0f)];
    self.pinyinLabel.textAlignment = NSTextAlignmentCenter;
    self.pinyinLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:28.0f];
    self.pinyinLabel.textColor = [self onSurfaceVariantColor];
    [self.cardView addSubview:self.pinyinLabel];

    // Giant Character Label (center)
    self.charLabel = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 90.0f, 620.0f, 520.0f)];
    self.charLabel.textAlignment = NSTextAlignmentCenter;
    self.charLabel.font = [self fontWithName:@"Noto Serif" size:280.0f];
    self.charLabel.textColor = [self onSurfaceColor];
    self.charLabel.adjustsFontSizeToFitWidth = YES;
    [self.cardView addSubview:self.charLabel];

    // Status text at card bottom
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 640.0f, 660.0f, 30.0f)];
    self.statusLabel.text = @"";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:18.0f];
    self.statusLabel.textColor = [self onSurfaceVariantColor];
    [self.cardView addSubview:self.statusLabel];

    // 3. Footer toolbar (frame: 0, 904, 768, 120)
    self.footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 904.0f, 768.0f, 120.0f)];
    self.footerView.backgroundColor = [self surfaceContainerColor];
    self.footerView.clipsToBounds = NO;
    self.footerView.layer.shadowColor = [self primaryColor].CGColor;
    self.footerView.layer.shadowOpacity = 0.08f;
    self.footerView.layer.shadowRadius = 8.0f;
    self.footerView.layer.shadowOffset = CGSizeMake(0, -4.0f);
    UIView *footerView = self.footerView;

    // Cross Button (left)
    SquishyButton *crossBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(200.0f, 28.0f, 64.0f, 64.0f)
                                                   backgroundColor:[self colorFromHex:@"#ffdad6"]
                                                       shadowColor:[self colorFromHex:@"#ba1a1a"]
                                                      cornerRadius:32.0f];
    [crossBtn setTitle:@"❌" forState:UIControlStateNormal];
    crossBtn.titleLabel.font = [UIFont systemFontOfSize:22.0f];
    [crossBtn addTarget:self action:@selector(wrongEvaluationClicked) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:crossBtn];

    // Check Button (right)
    SquishyButton *checkBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(504.0f, 28.0f, 64.0f, 64.0f)
                                                   backgroundColor:[self primaryColor]
                                                       shadowColor:[self colorFromHex:@"#004e40"]
                                                      cornerRadius:32.0f];
    [checkBtn setTitle:@"✔️" forState:UIControlStateNormal];
    checkBtn.titleLabel.font = [UIFont systemFontOfSize:22.0f];
    [checkBtn addTarget:self action:@selector(correctEvaluationClicked) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:checkBtn];

    [self.canvasView addSubview:footerView];
}

#pragma mark - Data Loading

- (void)reloadWordData {
    self.wordModel = [[TextbookManager sharedManager] wordForBook:self.currentBook
                                                           lesson:self.currentLesson
                                                        wordIndex:self.selectedWordIndex];
    if (!self.wordModel) {
        NSLog(@"Error loading word book %ld lesson %ld idx %ld",
              (long)self.currentBook, (long)self.currentLesson, (long)self.selectedWordIndex);
        return;
    }

    self.pinyinLabel.hidden = NO;
    self.pinyinLabel.text = self.wordModel.pinyinWithTone;
    self.charLabel.frame = CGRectMake(40.0f, 90.0f, 620.0f, 520.0f);
    self.charLabel.font = [self fontWithName:@"Noto Serif" size:280.0f];
    self.charLabel.text = self.wordModel.character;
    self.statusLabel.text = @"";

    [self playStandardAudio];
}

#pragma mark - Audio Playback

- (void)playStandardAudio {
    [[AudioManager sharedManager] playSoundNamed:[self.wordModel audioFileName]];
}

#pragma mark - Game Mode (认读游戏)

- (void)setupGameModeUI {
    // Remove old footer subviews
    for (UIView *v in self.footerView.subviews) {
        [v removeFromSuperview];
    }

    // Load lesson words
    LessonModel *lesson = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    self.lessonWords = lesson.words;

    // Setup shuffled indices
    [self rebuildShuffledIndices];

    // Start from word 1
    self.currentPlayIndex = 1;
    self.selectedWordIndex = 1;

    // --- Footer game mode buttons ---
    // Row: 顺序(x:160) / 🔈重播(x:270,w:228) / 乱序(x:552)
    UIButton *orderBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    orderBtn.frame = CGRectMake(160.0f, 12.0f, 88.0f, 48.0f);
    orderBtn.backgroundColor = self.isShuffled ? [self surfaceContainerColor] : [self primaryColor];
    orderBtn.layer.cornerRadius = 10.0f;
    orderBtn.tag = 201;
    orderBtn.titleLabel.font = [UIFont systemFontOfSize:20.0f];
    [orderBtn setTitle:@"顺序" forState:UIControlStateNormal];
    [orderBtn setTitleColor:self.isShuffled ? [self onSurfaceVariantColor] : [UIColor whiteColor] forState:UIControlStateNormal];
    [orderBtn addTarget:self action:@selector(difficultyBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:orderBtn];

    SquishyButton *playBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(270.0f, 8.0f, 228.0f, 56.0f)
                                                  backgroundColor:[self colorFromHex:@"#70cfc2"]
                                                      shadowColor:[self primaryColor]
                                                     cornerRadius:28.0f];
    [playBtn setTitle:@"🔈 重播" forState:UIControlStateNormal];
    [playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    playBtn.titleLabel.font = [UIFont systemFontOfSize:20.0f];
    [playBtn addTarget:self action:@selector(gameManualPlay) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:playBtn];

    UIButton *shuffleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    shuffleBtn.frame = CGRectMake(552.0f, 12.0f, 88.0f, 48.0f);
    shuffleBtn.backgroundColor = self.isShuffled ? [self primaryColor] : [self surfaceContainerColor];
    shuffleBtn.layer.cornerRadius = 10.0f;
    shuffleBtn.tag = 202;
    shuffleBtn.titleLabel.font = [UIFont systemFontOfSize:20.0f];
    [shuffleBtn setTitle:@"乱序" forState:UIControlStateNormal];
    [shuffleBtn setTitleColor:self.isShuffled ? [UIColor whiteColor] : [self onSurfaceVariantColor] forState:UIControlStateNormal];
    [shuffleBtn addTarget:self action:@selector(difficultyBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:shuffleBtn];

    // Tap card to advance
    UITapGestureRecognizer *tapCard = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nextCardClicked)];
    self.cardView.userInteractionEnabled = YES;
    [self.cardView addGestureRecognizer:tapCard];
}

- (void)rebuildShuffledIndices {
    NSMutableArray *indices = [NSMutableArray array];
    for (NSInteger i = 1; i <= 16; i++) {
        [indices addObject:@(i)];
    }
    if (self.isShuffled) {
        for (NSInteger i = 15; i > 0; i--) {
            NSInteger j = arc4random_uniform((uint32_t)(i + 1));
            [indices exchangeObjectAtIndex:i withObjectAtIndex:j];
        }
    }
    self.shuffledIndices = indices;
}

- (NSInteger)actualWordIndex {
    return [self.shuffledIndices[self.currentPlayIndex - 1] integerValue];
}

- (void)startAutoPlay {
    WordModel *word = [self gameWordAtPlayIndex:self.currentPlayIndex];
    if (!word) return;

    self.wordModel = word;
    self.pinyinLabel.hidden = YES;
    self.charLabel.frame = CGRectMake(20.0f, 20.0f, 660.0f, 660.0f);
    self.charLabel.font = [self fontWithName:@"Noto Serif" size:400.0f];
    self.charLabel.text = word.character;
    self.charLabel.hidden = NO;
    self.selectedWordIndex = [self actualWordIndex];
    self.statusLabel.text = @"";

    [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];

    if (self.autoAdvancing) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(advanceToNextWord) object:nil];
        [self performSelector:@selector(advanceToNextWord) withObject:nil afterDelay:2.0f];
    }
}

- (WordModel *)gameWordAtPlayIndex:(NSInteger)playIndex {
    if (playIndex < 1 || playIndex > 16) return nil;
    NSInteger wordIdx = [self actualWordIndex];
    return [[TextbookManager sharedManager] wordForBook:self.currentBook lesson:self.currentLesson wordIndex:wordIdx];
}

- (void)advanceToNextWord {
    if (self.currentPlayIndex < 16) {
        self.currentPlayIndex++;
        [self startAutoPlay];
    } else {
        [self gameComplete];
    }
}

- (void)gameComplete {
    // Save completion count to NSUserDefaults
    NSString *modeKey = self.isShuffled ? @"hard" : @"easy";
    NSString *key = [NSString stringWithFormat:@"game_completion_b%ld_l%ld_%@",
                     (long)self.currentBook, (long)self.currentLesson, modeKey];
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    count++;
    [[NSUserDefaults standardUserDefaults] setInteger:count forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[AudioManager sharedManager] playSoundNamed:@"nizhenbang.caf"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"真棒！"
                                                                   message:[NSString stringWithFormat:@"本课16个字已全部学完！\n已学习 %ld 次", (long)count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"再学一次" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.currentPlayIndex = 1;
        [self startAutoPlay];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"返回" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)stopAutoAdvance {
    self.autoAdvancing = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(advanceToNextWord) object:nil];
}

- (void)gameManualPlay {
    [self stopAutoAdvance];
    [self startAutoPlay];
}

- (void)difficultyBtnTapped:(UIButton *)sender {
    BOOL newShuffled = (sender.tag == 202);
    if (newShuffled == self.isShuffled) return;

    self.isShuffled = newShuffled;
    [self rebuildShuffledIndices];

    // Update button styles
    UIButton *orderBtn = (UIButton *)[self.footerView viewWithTag:201];
    UIButton *shuffleBtn = (UIButton *)[self.footerView viewWithTag:202];
    orderBtn.backgroundColor = self.isShuffled ? [self surfaceContainerColor] : [self primaryColor];
    [orderBtn setTitleColor:self.isShuffled ? [self onSurfaceVariantColor] : [UIColor whiteColor] forState:UIControlStateNormal];
    shuffleBtn.backgroundColor = self.isShuffled ? [self primaryColor] : [self surfaceContainerColor];
    [shuffleBtn setTitleColor:self.isShuffled ? [UIColor whiteColor] : [self onSurfaceVariantColor] forState:UIControlStateNormal];

    // Restart game from word 1
    [self stopAutoAdvance];
    self.currentPlayIndex = 1;
    [self startAutoPlay];
}

#pragma mark - Actions

- (void)startBtnClicked {
    if (self.isGameMode) {
        [self stopAutoAdvance];
        self.autoAdvancing = YES;
        self.currentPlayIndex = 1;
        [self startAutoPlay];
        return;
    }
    [self playStandardAudio];
}

- (void)nextCardClicked {
    if (self.isGameMode) {
        [self stopAutoAdvance];
        [self advanceToNextWord];
        return;
    }

    if (self.selectedWordIndex < 16) {
        self.selectedWordIndex++;
        [self reloadWordData];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"真棒！"
                                                                       message:@"本课汉字已经全部学习完毕！"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"重新学" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            self.selectedWordIndex = 1;
            [self reloadWordData];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)backBtnClicked {
    [self stopAutoAdvance];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)wrongEvaluationClicked {
    self.statusLabel.text = @"❌ 下次继续努力！";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self nextCardClicked];
    });
}

- (void)correctEvaluationClicked {
    self.statusLabel.text = @"🎉 太棒了！回答正确！";
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self nextCardClicked];
    });
}

@end

#import "Game2ViewController.h"
#import "TextbookManager.h"
#import "AudioManager.h"
#if __has_include("SupabaseClient.h")
#import "SupabaseClient.h"
#endif
#import "SquishyButton.h"
#import <objc/runtime.h>

static const void *kWordModelKey = &kWordModelKey;
static const CGFloat kBubbleSize = 110.0f;

@interface Game2ViewController ()

@property (strong, nonatomic) NSArray<WordModel *> *words;
@property (strong, nonatomic) WordModel *targetWord;
@property (strong, nonatomic) NSMutableArray<UIButton *> *bubbles;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *bubbleSpeeds;
@property (strong, nonatomic) CADisplayLink *gameTimer;

@property (strong, nonatomic) UILabel *targetLabel;
@property (strong, nonatomic) UILabel *progressLabel;
@property (strong, nonatomic) NSMutableArray<UILabel *> *starLabels;

@property (strong, nonatomic) UIView *gameStage;

@property (assign, nonatomic) NSInteger wrongTapCount;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSNumber *> *wordFoundCounts;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSNumber *> *wrongTapDetails;
@property (strong, nonatomic) NSMutableSet<NSNumber *> *visibleIndices;
@property (assign, nonatomic) NSInteger remainingCount; // 16→0, 每个字找2次后减1

@property (assign, nonatomic) BOOL isEasy;
@property (assign, nonatomic) BOOL gameActive;
@property (assign, nonatomic) BOOL bubblesLocked;
@property (assign, nonatomic) NSInteger spawnCount;

@end

@implementation Game2ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.bubbles = [NSMutableArray array];
    self.bubbleSpeeds = [NSMutableArray array];
    self.starLabels = [NSMutableArray array];
    self.wordFoundCounts = [NSMutableDictionary dictionary];
    self.wrongTapDetails = [NSMutableDictionary dictionary];
    self.visibleIndices = [NSMutableSet set];
    self.wrongTapCount = 0;
    self.remainingCount = 16;
    self.spawnCount = 0;
    self.isEasy = YES;
    self.gameActive = NO;
    self.bubblesLocked = NO;

    LessonModel *lesson = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    self.words = lesson.words;

    [self setupStaticUI];
    [self startAccumulation];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopGameTimer];
    [[AudioManager sharedManager] stopCurrentSound];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - UI Setup

- (void)setupStaticUI {
    UIView *topNavBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 80.0f)];
    topNavBar.backgroundColor = [[self backgroundColor] colorWithAlphaComponent:0.95f];

    UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 79.5f, 768.0f, 0.5f)];
    topSeparator.backgroundColor = [self surfaceContainerColor];
    [topNavBar addSubview:topSeparator];

    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 16.0f, 48.0f, 48.0f)];
    iconLabel.text = @"🫧";
    iconLabel.font = [UIFont systemFontOfSize:32.0f];
    [topNavBar addSubview:iconLabel];

    self.targetLabel = [[UILabel alloc] initWithFrame:CGRectMake(100.0f, 16.0f, 350.0f, 48.0f)];
    self.targetLabel.text = @"请找到您听到的汉字";
    self.targetLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:24.0f];
    self.targetLabel.textColor = [self primaryColor];
    [topNavBar addSubview:self.targetLabel];

    self.progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(360.0f, 16.0f, 80.0f, 48.0f)];
    self.progressLabel.text = @"";
    self.progressLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:20.0f];
    self.progressLabel.textColor = [self onSurfaceVariantColor];
    self.progressLabel.textAlignment = NSTextAlignmentLeft;
    [topNavBar addSubview:self.progressLabel];

    SquishyButton *replayBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(452.0f, 16.0f, 110.0f, 48.0f)
                                                     backgroundColor:[self primaryContainerColor]
                                                         shadowColor:[self primaryColor]
                                                        cornerRadius:24.0f];
    [replayBtn setTitle:@"🔊 重播" forState:UIControlStateNormal];
    [replayBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    replayBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [replayBtn addTarget:self action:@selector(replayTargetSound) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:replayBtn];

    SquishyButton *backBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(574.0f, 16.0f, 110.0f, 48.0f)
                                                  backgroundColor:[self surfaceContainerColor]
                                                      shadowColor:[self onSurfaceVariantColor]
                                                     cornerRadius:24.0f];
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [backBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [backBtn addTarget:self action:@selector(backBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:backBtn];

    [self.canvasView addSubview:topNavBar];

    self.gameStage = [[UIView alloc] initWithFrame:CGRectMake(0, 80.0f, 768.0f, 824.0f)];
    self.gameStage.backgroundColor = [UIColor clearColor];
    self.gameStage.clipsToBounds = YES;
    [self.canvasView addSubview:self.gameStage];

    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 904.0f, 768.0f, 120.0f)];
    footerView.backgroundColor = [self backgroundColor];

    CGFloat centerY = 60.0f;

    UIButton *easyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    easyBtn.frame = CGRectMake(209.0f, centerY - 24.0f, 72.0f, 48.0f);
    easyBtn.backgroundColor = [self primaryColor];
    easyBtn.layer.cornerRadius = 10.0f;
    easyBtn.tag = 201;
    easyBtn.titleLabel.font = [UIFont systemFontOfSize:20.0f];
    [easyBtn setTitle:@"易" forState:UIControlStateNormal];
    [easyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [easyBtn addTarget:self action:@selector(difficultyTapped:) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:easyBtn];

    for (NSInteger i = 1; i <= 5; i++) {
        UILabel *star = [[UILabel alloc] initWithFrame:CGRectMake(297.0f + (i - 1) * 36.0f, centerY - 20.0f, 30.0f, 40.0f)];
        star.tag = 300 + i;
        star.textAlignment = NSTextAlignmentCenter;
        star.font = [UIFont systemFontOfSize:26.0f];
        star.userInteractionEnabled = NO;
        [footerView addSubview:star];
        [self.starLabels addObject:star];
    }

    UIButton *hardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hardBtn.frame = CGRectMake(487.0f, centerY - 24.0f, 72.0f, 48.0f);
    hardBtn.backgroundColor = [self surfaceContainerColor];
    hardBtn.layer.cornerRadius = 10.0f;
    hardBtn.tag = 202;
    hardBtn.titleLabel.font = [UIFont systemFontOfSize:20.0f];
    [hardBtn setTitle:@"难" forState:UIControlStateNormal];
    [hardBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    [hardBtn addTarget:self action:@selector(difficultyTapped:) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:hardBtn];

    [self updateDifficultyStars];
    [self.canvasView addSubview:footerView];
}

- (void)updateDifficultyStars {
    for (NSInteger i = 0; i < 5; i++) {
        UILabel *star = self.starLabels[i];
        if (self.isEasy) {
            if (i == 0) {
                star.text = @"★";
                star.textColor = [self primaryColor];
            } else {
                star.text = @"☆";
                star.textColor = [self onSurfaceVariantColor];
            }
        } else {
            star.text = @"★";
            star.textColor = [self primaryColor];
        }
    }
}

- (void)difficultyTapped:(UIButton *)sender {
    BOOL newEasy = (sender.tag == 201);
    if (newEasy == self.isEasy) return;
    self.isEasy = newEasy;

    UIButton *easyBtn = (UIButton *)[self.canvasView viewWithTag:201];
    UIButton *hardBtn = (UIButton *)[self.canvasView viewWithTag:202];
    if (self.isEasy) {
        easyBtn.backgroundColor = [self primaryColor];
        [easyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        hardBtn.backgroundColor = [self surfaceContainerColor];
        [hardBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    } else {
        easyBtn.backgroundColor = [self surfaceContainerColor];
        [easyBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
        hardBtn.backgroundColor = [self primaryColor];
        [hardBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    [self updateDifficultyStars];
}

#pragma mark - Game Lifecycle

- (void)startAccumulation {
    self.spawnCount = 0;
    [self startGameTimer];
    [self performSelector:@selector(spawnAccumulationBubble) withObject:nil afterDelay:0.0];
}

- (void)spawnAccumulationBubble {
    [self spawnBubble];
    self.spawnCount++;
    if (self.spawnCount == 4) {
        [self performSelector:@selector(beginGameplay) withObject:nil afterDelay:0.4];
    }
    if (self.spawnCount < 10) {
        [self performSelector:@selector(spawnAccumulationBubble) withObject:nil afterDelay:0.3];
    }
}

- (void)beginGameplay {
    self.gameActive = YES;
    [self pickTargetFromVisibleBubbles];
}

- (void)pickTargetFromVisibleBubbles {
    if (self.remainingCount <= 0) {
        [self gameComplete];
        return;
    }

    NSMutableArray *candidates = [NSMutableArray array];
    for (UIButton *bubble in self.bubbles) {
        if (bubble.center.y < 0 || bubble.center.y > 824.0f) continue;
        WordModel *word = objc_getAssociatedObject(bubble, kWordModelKey);
        NSInteger idx = [self wordIndexForCharacter:word.character];
        if (idx != NSNotFound && [self.wordFoundCounts[@(idx)] integerValue] < 2) {
            [candidates addObject:bubble];
        }
    }

    if (candidates.count == 0) {
        // Safe retry loop: if no candidates are visible on screen yet, try again in 0.5s
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && strongSelf.gameActive && !strongSelf.targetWord) {
                [strongSelf pickTargetFromVisibleBubbles];
            }
        });
        return;
    }

    UIButton *chosen = candidates[arc4random_uniform((uint32_t)candidates.count)];
    self.targetWord = objc_getAssociatedObject(chosen, kWordModelKey);
    self.targetLabel.text = @"请找到您听到的汉字";
    self.progressLabel.text = [NSString stringWithFormat:@"(%ld/16)", (long)(16 - self.remainingCount)];
    [self replayTargetSound];
}

- (void)replayTargetSound {
    if (self.targetWord) {
        [[AudioManager sharedManager] playSoundNamed:[self.targetWord audioFileName]];
    }
}

- (NSInteger)wordIndexForCharacter:(NSString *)character {
    for (NSInteger i = 0; i < self.words.count; i++) {
        if ([self.words[i].character isEqualToString:character]) {
            return i;
        }
    }
    return NSNotFound;
}

#pragma mark - Bubble Spawning

- (void)spawnBubble {
    CGFloat cardX = 30.0f + ((float)rand() / RAND_MAX) * (628.0f - kBubbleSize);

    UIButton *bubble = [UIButton buttonWithType:UIButtonTypeCustom];
    bubble.frame = CGRectMake(cardX, -55.0f, kBubbleSize, kBubbleSize);
    bubble.backgroundColor = [self colorFromHex:@"#e1fbee"];
    bubble.layer.cornerRadius = kBubbleSize / 2.0f;
    bubble.layer.borderWidth = 1.0f;
    bubble.layer.borderColor = [[self primaryColor] colorWithAlphaComponent:0.15f].CGColor;
    bubble.layer.shadowColor = [self primaryColor].CGColor;
    bubble.layer.shadowOpacity = 0.06f;
    bubble.layer.shadowRadius = 8.0f;
    bubble.layer.shadowOffset = CGSizeMake(0, 4.0f);

    WordModel *word = self.words[[self pickWordIndexForNewBubble]];
    [bubble setTitle:word.character forState:UIControlStateNormal];
    [bubble setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    bubble.titleLabel.font = [self fontWithName:@"Noto Serif" size:48.0f];
    objc_setAssociatedObject(bubble, kWordModelKey, word, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [bubble addTarget:self action:@selector(bubbleClicked:) forControlEvents:UIControlEventTouchUpInside];
    bubble.tag = self.bubbles.count;

    NSInteger wordIdx = [self wordIndexForCharacter:word.character];
    if (wordIdx != NSNotFound) {
        [self.visibleIndices addObject:@(wordIdx)];
    }

    [self.gameStage addSubview:bubble];
    [self.bubbles addObject:bubble];

    float speed = self.isEasy ? 0.6f : 1.2f;
    [self.bubbleSpeeds addObject:@(speed)];
}

- (NSInteger)pickWordIndexForNewBubble {
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSInteger i = 0; i < 16; i++) {
        // Prioritize words that are:
        // 1. Not currently visible on screen
        // 2. Not yet completed (found count < 2)
        if (![self.visibleIndices containsObject:@(i)] && [self.wordFoundCounts[@(i)] integerValue] < 2) {
            [candidates addObject:@(i)];
        }
    }
    
    if (candidates.count == 0) {
        // If all non-visible words are completed, search for visible words that are not completed
        for (NSInteger i = 0; i < 16; i++) {
            if ([self.wordFoundCounts[@(i)] integerValue] < 2) {
                [candidates addObject:@(i)];
            }
        }
    }
    
    if (candidates.count == 0) {
        // Fallback: if all 16 words are completed, just pick a non-visible one
        for (NSInteger i = 0; i < 16; i++) {
            if (![self.visibleIndices containsObject:@(i)]) {
                [candidates addObject:@(i)];
            }
        }
    }
    
    if (candidates.count == 0) {
        return arc4random_uniform(16);
    }
    
    return [candidates[arc4random_uniform((uint32_t)candidates.count)] integerValue];
}

#pragma mark - Game Timer

- (void)startGameTimer {
    [self stopGameTimer];
    self.gameTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateGamePhysics:)];
    [self.gameTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopGameTimer {
    if (self.gameTimer) {
        [self.gameTimer invalidate];
        self.gameTimer = nil;
    }
}

- (void)updateGamePhysics:(CADisplayLink *)timer {
    // 1. Move all bubbles down
    for (NSInteger i = 0; i < self.bubbles.count; i++) {
        UIButton *bubble = self.bubbles[i];
        float speed = [self.bubbleSpeeds[i] floatValue];
        bubble.center = CGPointMake(bubble.center.x, bubble.center.y + speed);
    }

    // 2. Resolve collisions (repulsion)
    for (int k = 0; k < 2; k++) {
        for (NSInteger i = 0; i < self.bubbles.count; i++) {
            UIButton *bubbleA = self.bubbles[i];
            for (NSInteger j = i + 1; j < self.bubbles.count; j++) {
                UIButton *bubbleB = self.bubbles[j];
                
                CGFloat dx = bubbleB.center.x - bubbleA.center.x;
                CGFloat dy = bubbleB.center.y - bubbleA.center.y;
                CGFloat dist = sqrt(dx*dx + dy*dy);
                CGFloat minDist = kBubbleSize + 8.0f; // bubble size + small buffer
                
                if (dist < minDist) {
                    if (dist == 0) {
                        dist = 0.1f;
                        dx = 0.1f;
                    }
                    
                    CGFloat overlap = minDist - dist;
                    CGFloat pushX = (dx / dist) * overlap * 0.5f;
                    CGFloat pushY = (dy / dist) * overlap * 0.5f;
                    
                    CGPoint centerA = bubbleA.center;
                    CGPoint centerB = bubbleB.center;
                    
                    centerA.x -= pushX;
                    centerA.y -= pushY;
                    centerB.x += pushX;
                    centerB.y += pushY;
                    
                    // Keep within horizontal boundaries: [30 + kBubbleSize/2, 30 + 628 - kBubbleSize/2]
                    CGFloat minX = 30.0f + kBubbleSize / 2.0f;
                    CGFloat maxX = 30.0f + 628.0f - kBubbleSize / 2.0f;
                    
                    if (centerA.x < minX) centerA.x = minX;
                    if (centerA.x > maxX) centerA.x = maxX;
                    if (centerB.x < minX) centerB.x = minX;
                    if (centerB.x > maxX) centerB.x = maxX;
                    
                    bubbleA.center = centerA;
                    bubbleB.center = centerB;
                }
            }
        }
    }

    // 3. Reset bubbles that fall past bottom
    for (NSInteger i = 0; i < self.bubbles.count; i++) {
        UIButton *bubble = self.bubbles[i];
        if (bubble.center.y > 824.0f + 60.0f) {
            WordModel *bubbleWord = objc_getAssociatedObject(bubble, kWordModelKey);
            BOOL wasTarget = (self.gameActive && self.targetWord &&
                              [bubbleWord.character isEqualToString:self.targetWord.character]);

            NSInteger oldIdx = [self wordIndexForCharacter:bubbleWord.character];
            if (oldIdx != NSNotFound) {
                [self.visibleIndices removeObject:@(oldIdx)];
            }

            CGFloat cardX = 30.0f + ((float)rand() / RAND_MAX) * (628.0f - kBubbleSize);
            bubble.center = CGPointMake(cardX + kBubbleSize / 2.0f, -55.0f);

            NSInteger newWordIdx = [self pickWordIndexForNewBubble];
            WordModel *newWord = self.words[newWordIdx];
            [bubble setTitle:newWord.character forState:UIControlStateNormal];
            objc_setAssociatedObject(bubble, kWordModelKey, newWord, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self.visibleIndices addObject:@(newWordIdx)];

            float newSpeed = self.isEasy ? 0.6f : 1.2f;
            self.bubbleSpeeds[i] = @(newSpeed);

            if (wasTarget) {
                self.targetWord = nil;
                [self pickTargetFromVisibleBubbles];
            }
        }
    }
}

#pragma mark - Bubble Click

- (void)bubbleClicked:(UIButton *)sender {
    if (self.bubblesLocked || !self.gameActive) return;

    WordModel *bubbleWord = objc_getAssociatedObject(sender, kWordModelKey);
    if (!bubbleWord || !self.targetWord) return;

    if ([bubbleWord.character isEqualToString:self.targetWord.character]) {
        [self handleCorrectTapOnBubble:sender];
    } else {
        [self handleWrongTapOnBubble:sender];
    }
}

- (void)handleCorrectTapOnBubble:(UIButton *)sender {
    WordModel *bubbleWord = objc_getAssociatedObject(sender, kWordModelKey);
    NSInteger wordIdx = [self wordIndexForCharacter:bubbleWord.character];
    if (wordIdx != NSNotFound) {
        NSInteger count = [self.wordFoundCounts[@(wordIdx)] integerValue] + 1;
        self.wordFoundCounts[@(wordIdx)] = @(count);
        if (count >= 2) {
            self.remainingCount--;
        }
    }
    self.progressLabel.text = [NSString stringWithFormat:@"(%ld/16)", (long)(16 - self.remainingCount)];

    [UIView animateWithDuration:0.25f animations:^{
        sender.transform = CGAffineTransformMakeScale(1.4f, 1.4f);
        sender.alpha = 0.0f;
    } completion:^(BOOL finished) {
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0f;

        if (wordIdx != NSNotFound) {
            [self.visibleIndices removeObject:@(wordIdx)];
        }

        CGFloat cardX = 30.0f + ((float)rand() / RAND_MAX) * (628.0f - kBubbleSize);
        sender.center = CGPointMake(cardX + kBubbleSize / 2.0f, -55.0f);

        NSInteger newWordIdx = [self pickWordIndexForNewBubble];
        WordModel *newWord = self.words[newWordIdx];
        [sender setTitle:newWord.character forState:UIControlStateNormal];
        objc_setAssociatedObject(sender, kWordModelKey, newWord, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.visibleIndices addObject:@(newWordIdx)];
    }];

    self.targetWord = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.remainingCount <= 0) {
            [self gameComplete];
        } else {
            [self pickTargetFromVisibleBubbles];
        }
    });
}

- (void)handleWrongTapOnBubble:(UIButton *)sender {
    self.wrongTapCount++;

    WordModel *bubbleWord = objc_getAssociatedObject(sender, kWordModelKey);
    if (bubbleWord) {
        NSString *ch = bubbleWord.character;
        NSInteger count = [self.wrongTapDetails[ch] integerValue] + 1;
        self.wrongTapDetails[ch] = @(count);
    }

    [self shakeView:sender];
    [[AudioManager sharedManager] playSoundNamed:@"cuola.caf"];

    self.bubblesLocked = YES;
    for (UIButton *b in self.bubbles) {
        b.userInteractionEnabled = NO;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.bubblesLocked = NO;
        if (strongSelf.gameActive) {
            for (UIButton *b in strongSelf.bubbles) {
                b.userInteractionEnabled = YES;
            }
        }
    });
}

#pragma mark - Game Complete

- (void)gameComplete {
    self.gameActive = NO;
    [self stopGameTimer];

#if __has_include("SupabaseClient.h")
    [[SupabaseClient sharedClient] saveProgressWithFeature:@"game2"
                                                bookNumber:self.currentBook
                                              lessonNumber:self.currentLesson
                                                 wordIndex:-1
                                                completion:nil];
#endif

    [[AudioManager sharedManager] playSoundNamed:@"nizhenbang.caf"];
    [self showConfetti];

    NSInteger totalWrong = self.wrongTapCount;
    NSInteger stars = 5;
    NSString *evaluation;
    if (totalWrong == 0) {
        stars = 5;
        evaluation = @"🌟 完美！";
    } else if (totalWrong <= 2) {
        stars = 4;
        evaluation = @"✨ 很好！";
    } else if (totalWrong <= 5) {
        stars = 3;
        evaluation = @"👍 不错！";
    } else if (totalWrong <= 10) {
        stars = 2;
        evaluation = @"💪 加油！";
    } else {
        stars = 1;
        evaluation = @"🌱 继续努力！";
    }

    NSString *modeKey = self.isEasy ? @"easy" : @"hard";
    NSString *detailKey = [NSString stringWithFormat:@"game2_details_b%ld_l%ld_%@",
                           (long)self.currentBook, (long)self.currentLesson, modeKey];
    NSMutableDictionary *details = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:detailKey] mutableCopy];
    if (!details) details = [NSMutableDictionary dictionary];
    NSInteger compCount = [details[@"completionCount"] integerValue] + 1;
    details[@"completionCount"] = @(compCount);
    details[@"wrongTapCount"] = @(self.wrongTapCount);
    details[@"wrongTapDetails"] = self.wrongTapDetails;
    [[NSUserDefaults standardUserDefaults] setObject:details forKey:detailKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *starStr = @"";
    for (NSInteger i = 0; i < stars; i++) {
        starStr = [starStr stringByAppendingString:@"★"];
    }
    for (NSInteger i = stars; i < 5; i++) {
        starStr = [starStr stringByAppendingString:@"☆"];
    }

    NSMutableString *wrongDetailStr = [NSMutableString string];
    NSArray *sortedChars = [self.wrongTapDetails.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    for (NSString *ch in sortedChars) {
        if (wrongDetailStr.length > 0) [wrongDetailStr appendString:@" "];
        [wrongDetailStr appendFormat:@"%@(%@)", ch, self.wrongTapDetails[ch]];
    }
    NSString *wrongLine = (wrongDetailStr.length > 0) ?
        [NSString stringWithFormat:@"点错：%@", wrongDetailStr] : @"";

    // BUG FIX: use weak self — if user exits within 0.5s VC may be deallocated
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *message = [NSString stringWithFormat:
                             @"全部正确！找到了 32 个字\n点错了 %ld 次\n%@\n%@\n已完成 %ld 次",
                             (long)strongSelf.wrongTapCount, wrongLine, evaluation, (long)compCount];
        if (totalWrong > 0) {
            message = [NSString stringWithFormat:
                       @"全部完成！找到了 32 个字\n点错了 %ld 次\n%@\n%@\n已完成 %ld 次",
                       (long)strongSelf.wrongTapCount, wrongLine, evaluation, (long)compCount];
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"通关成功！"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"再玩一次" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [strongSelf stopConfetti];
            [strongSelf restartGame];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"返回" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [strongSelf stopConfetti];
            [strongSelf backBtnClicked];
        }]];
        [strongSelf presentViewController:alert animated:YES completion:nil];
    });
}

- (void)restartGame {
    for (UIButton *b in self.bubbles) {
        [b removeFromSuperview];
    }
    [self.bubbles removeAllObjects];
    [self.bubbleSpeeds removeAllObjects];

    self.wrongTapCount = 0;
    self.remainingCount = 16;
    self.spawnCount = 0;
    self.gameActive = NO;
    self.bubblesLocked = NO;
    [self.wordFoundCounts removeAllObjects];
    [self.wrongTapDetails removeAllObjects];
    [self.visibleIndices removeAllObjects];
    self.targetWord = nil;
    self.targetLabel.text = @"请找到您听到的汉字";
    self.progressLabel.text = @"";

    [self startAccumulation];
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

    CGColorRef gold = [UIColor colorWithRed:1.0 green:0.84 blue:0.0 alpha:1.0].CGColor;
    CGColorRef teal = [UIColor colorWithRed:0.26 green:0.80 blue:0.64 alpha:1.0].CGColor;
    CGColorRef coral = [UIColor colorWithRed:1.0 green:0.41 blue:0.38 alpha:1.0].CGColor;
    CGColorRef purple = [UIColor colorWithRed:0.55 green:0.35 blue:0.89 alpha:1.0].CGColor;
    CGColorRef blue = [UIColor colorWithRed:0.29 green:0.63 blue:0.86 alpha:1.0].CGColor;
    CGColorRef colorRefs[] = {gold, teal, coral, purple, blue};

    CGImageRef cgImage = [self confettiImage].CGImage;

    NSMutableArray *cells = [NSMutableArray array];
    for (NSInteger ci = 0; ci < 5; ci++) {
        CAEmitterCell *cell = [CAEmitterCell emitterCell];
        cell.contents = (__bridge id)cgImage;
        cell.color = colorRefs[ci];
        cell.birthRate = 6;
        cell.lifetime = 6.0f;
        cell.lifetimeRange = 2.0f;
        cell.velocity = 200.0f;
        cell.velocityRange = 100.0f;
        cell.emissionLongitude = M_PI / 2;
        cell.emissionRange = M_PI / 4;
        cell.spin = 4.0f;
        cell.spinRange = 2.0f;
        cell.scale = 0.6f;
        cell.scaleRange = 0.3f;
        cell.yAcceleration = 150.0f;
        cell.xAcceleration = 20.0f;
        [cells addObject:cell];
    }
    emitter.emitterCells = cells;

    [self.canvasView.layer addSublayer:emitter];
}

- (UIImage *)confettiImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(10, 10), NO, 1.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0, 0, 10, 10)];
    [[UIColor whiteColor] setFill];
    [path fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)stopConfetti {
    // BUG FIX: copy sublayers before iterating — removeFromSuperlayer mutates the array
    NSArray *sublayersCopy = [self.canvasView.layer.sublayers copy];
    for (CALayer *layer in sublayersCopy) {
        if ([layer.name isEqualToString:@"confetti"]) {
            [layer removeFromSuperlayer];
        }
    }
}

#pragma mark - Helpers

- (void)shakeView:(UIView *)view {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.duration = 0.07f;
    animation.repeatCount = 3;
    animation.autoreverses = YES;
    animation.fromValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x - 8.0f, view.center.y)];
    animation.toValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x + 8.0f, view.center.y)];
    [view.layer addAnimation:animation forKey:@"position"];
}

- (void)backBtnClicked {
    [self stopConfetti];
    [self.navigationController popViewControllerAnimated:YES];
}

- (UIColor *)outlineVariantColor {
    return [self colorFromHex:@"#bdc9c4"];
}

@end

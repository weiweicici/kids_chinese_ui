#import "Game2ViewController.h"
#import "TextbookManager.h"
#import "AudioManager.h"
#import "SquishyButton.h"

@interface Game2ViewController ()

@property (strong, nonatomic) NSArray<WordModel *> *words;
@property (strong, nonatomic) WordModel *targetWord;
@property (strong, nonatomic) NSMutableArray<UIButton *> *bubbles;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *bubbleSpeeds;
@property (strong, nonatomic) CADisplayLink *gameTimer;

@property (assign, nonatomic) NSInteger score; // Target: 5 correct pops
@property (strong, nonatomic) UILabel *targetLabel;
@property (strong, nonatomic) NSMutableArray<UILabel *> *starLabels;

@property (strong, nonatomic) UIView *gameStage;

@end

@implementation Game2ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.bubbles = [NSMutableArray array];
    self.bubbleSpeeds = [NSMutableArray array];
    self.starLabels = [NSMutableArray array];
    self.score = 0;
    
    LessonModel *lesson = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    self.words = lesson.words;
    
    [self setupStaticUI];
    [self startGame];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self stopGameTimer];
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
    
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 16.0f, 48.0f, 48.0f)];
    iconLabel.text = @"🫧";
    iconLabel.font = [UIFont systemFontOfSize:32.0f];
    [topNavBar addSubview:iconLabel];
    
    self.targetLabel = [[UILabel alloc] initWithFrame:CGRectMake(100.0f, 16.0f, 350.0f, 48.0f)];
    self.targetLabel.text = @"请找到：";
    self.targetLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:24.0f];
    self.targetLabel.textColor = [self primaryColor];
    [topNavBar addSubview:self.targetLabel];
    
    // Buttons right
    SquishyButton *replayBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(462.0f, 16.0f, 110.0f, 48.0f)
                                                     backgroundColor:[self primaryContainerColor]
                                                         shadowColor:[self primaryColor]
                                                        cornerRadius:24.0f];
    [replayBtn setTitle:@"🔊 重播" forState:UIControlStateNormal];
    [replayBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    replayBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [replayBtn addTarget:self action:@selector(replayTargetSound) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:replayBtn];
    
    SquishyButton *backBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(584.0f, 16.0f, 110.0f, 48.0f)
                                                  backgroundColor:[self surfaceContainerColor]
                                                      shadowColor:[self onSurfaceVariantColor]
                                                     cornerRadius:24.0f];
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    [backBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [backBtn addTarget:self action:@selector(backBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:backBtn];
    
    [self.canvasView addSubview:topNavBar];
    
    // 2. Main Game Stage (frame: 0, 80, 768, 824)
    self.gameStage = [[UIView alloc] initWithFrame:CGRectMake(0, 80.0f, 768.0f, 824.0f)];
    self.gameStage.backgroundColor = [UIColor clearColor];
    self.gameStage.clipsToBounds = YES;
    [self.canvasView addSubview:self.gameStage];
    
    // 3. Footer Stars rating (frame: 0, 904, 768, 120)
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 904.0f, 768.0f, 120.0f)];
    footerView.backgroundColor = [self backgroundColor];
    
    // Left side: score indicators (5 stars)
    UIView *starsContainer = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 30.0f, 250.0f, 60.0f)];
    starsContainer.backgroundColor = [self primaryContainerColor];
    starsContainer.layer.cornerRadius = 30.0f;
    starsContainer.layer.borderWidth = 1.0f;
    starsContainer.layer.borderColor = [[self primaryColor] colorWithAlphaComponent:0.15f].CGColor;
    
    for (NSInteger i = 0; i < 5; i++) {
        UILabel *star = [[UILabel alloc] initWithFrame:CGRectMake(15.0f + i * 44.0f, 10.0f, 40.0f, 40.0f)];
        star.text = @"☆";
        star.textAlignment = NSTextAlignmentCenter;
        star.font = [UIFont systemFontOfSize:30.0f];
        star.textColor = [self colorFromHex:@"#FFD700"]; // Golden color
        [starsContainer addSubview:star];
        [self.starLabels addObject:star];
    }
    [footerView addSubview:starsContainer];
    
    // Right side: static 5 golden stars rating as decoration
    UIView *decorContainer = [[UIView alloc] initWithFrame:CGRectMake(478.0f, 30.0f, 250.0f, 60.0f)];
    decorContainer.backgroundColor = [self surfaceContainerColor];
    decorContainer.layer.cornerRadius = 30.0f;
    decorContainer.layer.borderWidth = 1.0f;
    decorContainer.layer.borderColor = [self outlineVariantColor].CGColor;
    
    for (NSInteger i = 0; i < 5; i++) {
        UILabel *star = [[UILabel alloc] initWithFrame:CGRectMake(15.0f + i * 44.0f, 10.0f, 40.0f, 40.0f)];
        star.text = @"★";
        star.textAlignment = NSTextAlignmentCenter;
        star.font = [UIFont systemFontOfSize:30.0f];
        star.textColor = [self colorFromHex:@"#FFD700"];
        [decorContainer addSubview:star];
    }
    [footerView addSubview:decorContainer];
    
    [self.canvasView addSubview:footerView];
}

- (void)startGame {
    self.score = 0;
    [self updateScoreStars];
    
    // Clear old bubbles
    for (UIButton *b in self.bubbles) {
        [b removeFromSuperview];
    }
    [self.bubbles removeAllObjects];
    [self.bubbleSpeeds removeAllObjects];
    
    [self selectNewTarget];
    
    // Spawn 6 bubble cards at staggered heights
    // Bounds of stage: w=768, h=824. 
    // We space horizontal slots: x from 80 to 688 (safe bounds)
    CGFloat stepY = 824.0f / 6.0f;
    for (NSInteger i = 0; i < 6; i++) {
        CGFloat startY = 824.0f + i * stepY; // Spawn below screen or staggered
        [self spawnBubbleAtIndex:i yPosition:startY];
    }
    
    [self startPlatformTimer];
}

- (void)selectNewTarget {
    // Pick a random word from lesson
    self.targetWord = self.words[arc4random_uniform((uint32_t)self.words.count)];
    self.targetLabel.text = [NSString stringWithFormat:@"请找到：%@", self.targetWord.character];
    
    // Guarantee that at least one of the active bubbles contains this target character!
    BOOL targetExists = NO;
    for (UIButton *b in self.bubbles) {
        if ([b.titleLabel.text isEqualToString:self.targetWord.character]) {
            targetExists = YES;
            break;
        }
    }
    
    if (!targetExists && self.bubbles.count > 0) {
        // Swap one random active bubble to be the target
        NSInteger randIdx = arc4random_uniform((uint32_t)self.bubbles.count);
        UIButton *bubble = self.bubbles[randIdx];
        [bubble setTitle:self.targetWord.character forState:UIControlStateNormal];
        
        UILabel *pinyin = [bubble viewWithTag:101];
        if (pinyin) {
            pinyin.text = self.targetWord.pinyinWithTone;
        }
    }
    
    [self replayTargetSound];
}

- (void)replayTargetSound {
    [[AudioManager sharedManager] playSoundNamed:[self.targetWord audioFileName]];
}

- (void)spawnBubbleAtIndex:(NSInteger)index yPosition:(CGFloat)y {
    CGFloat cardSize = 110.0f;
    
    // Spacing between columns
    CGFloat colW = 688.0f / 6.0f;
    CGFloat randomOffsetX = ((float)rand() / RAND_MAX) * (colW - cardSize);
    CGFloat cardX = 40.0f + index * colW + randomOffsetX;
    
    UIButton *bubble = [UIButton buttonWithType:UIButtonTypeCustom];
    bubble.frame = CGRectMake(cardX, y, cardSize, cardSize);
    bubble.backgroundColor = [self colorFromHex:@"#e1fbee"]; // Pastel green bubble
    bubble.layer.cornerRadius = cardSize / 2.0f; // Make it circular!
    bubble.layer.borderWidth = 1.0f;
    bubble.layer.borderColor = [[self primaryColor] colorWithAlphaComponent:0.15f].CGColor;
    
    // Bubble shadow
    bubble.layer.shadowColor = [self primaryColor].CGColor;
    bubble.layer.shadowOpacity = 0.06f;
    bubble.layer.shadowRadius = 8.0f;
    bubble.layer.shadowOffset = CGSizeMake(0, 4.0f);
    
    // Select character (guaranteed target if first book layout, else random)
    WordModel *word = [self selectRandomWordWithIndex:index];
    [bubble setTitle:word.character forState:UIControlStateNormal];
    [bubble setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    bubble.titleLabel.font = [self fontWithName:@"Noto Serif" size:48.0f];
    
    // Pinyin text on top of character inside bubble
    UILabel *pinyinLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 12.0f, 90.0f, 20.0f)];
    pinyinLabel.text = word.pinyinWithTone;
    pinyinLabel.textAlignment = NSTextAlignmentCenter;
    pinyinLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:13.0f];
    pinyinLabel.textColor = [[self onSurfaceVariantColor] colorWithAlphaComponent:0.5f];
    pinyinLabel.tag = 101;
    [bubble addSubview:pinyinLabel];
    
    [bubble addTarget:self action:@selector(bubbleClicked:) forControlEvents:UIControlEventTouchUpInside];
    bubble.tag = index;
    
    [self.gameStage addSubview:bubble];
    
    if (index < self.bubbles.count) {
        self.bubbles[index] = bubble;
    } else {
        [self.bubbles addObject:bubble];
    }
    
    // Speed range: 1.5 to 3.0 points/tick
    float speed = 1.5f + (((float)rand() / RAND_MAX) * 1.5f);
    if (index < self.bubbleSpeeds.count) {
        self.bubbleSpeeds[index] = @(speed);
    } else {
        [self.bubbleSpeeds addObject:@(speed)];
    }
}

- (WordModel *)selectRandomWordWithIndex:(NSInteger)index {
    // If it's the first bubble we spawn, or by 20% chance, force targetWord to ensure presence
    if (index == 0 || (arc4random_uniform(10) < 2)) {
        if (self.targetWord) return self.targetWord;
    }
    return self.words[arc4random_uniform((uint32_t)self.words.count)];
}

- (WordModel *)selectRandomWordWithTargetGuarantee {
    // Count targets on screen
    BOOL targetOnScreen = NO;
    for (UIButton *b in self.bubbles) {
        if (b.alpha > 0.5f && [b.titleLabel.text isEqualToString:self.targetWord.character]) {
            targetOnScreen = YES;
            break;
        }
    }
    
    if (!targetOnScreen && self.targetWord) {
        return self.targetWord;
    }
    return self.words[arc4random_uniform((uint32_t)self.words.count)];
}

#pragma mark - Game Loop update

- (void)startPlatformTimer {
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
    // Update bubble translation vertical speed
    for (NSInteger i = 0; i < self.bubbles.count; i++) {
        UIButton *bubble = self.bubbles[i];
        float speed = [self.bubbleSpeeds[i] floatValue];
        
        CGPoint newCenter = CGPointMake(bubble.center.x, bubble.center.y - speed);
        bubble.center = newCenter;
        
        // If bubble goes off top screen bounds (y < -60)
        if (bubble.center.y < -60.0f) {
            // Respawn at bottom
            CGFloat randomOffsetX = ((float)rand() / RAND_MAX) * (688.0f/6.0f - 110.0f);
            CGFloat cardX = 40.0f + i * (688.0f/6.0f) + randomOffsetX;
            bubble.center = CGPointMake(cardX + 55.0f, 824.0f + 60.0f);
            
            // Re-assign character
            WordModel *word = [self selectRandomWordWithTargetGuarantee];
            [bubble setTitle:word.character forState:UIControlStateNormal];
            
            UILabel *pinyin = [bubble viewWithTag:101];
            if (pinyin) {
                pinyin.text = word.pinyinWithTone;
            }
            
            // Set new speed
            float newSpeed = 1.5f + (((float)rand() / RAND_MAX) * 1.5f);
            self.bubbleSpeeds[i] = @(newSpeed);
        }
    }
}

#pragma mark - Click Action

- (void)bubbleClicked:(UIButton *)sender {
    NSString *tappedChar = sender.titleLabel.text;
    
    if ([tappedChar isEqualToString:self.targetWord.character]) {
        // Correct!
        [[AudioManager sharedManager] playSoundNamed:@"1-1-1.mp3"]; // pop audio sound effect placeholder
        
        // Play bubble pop scale outward animation
        [UIView animateWithDuration:0.25f animations:^{
            sender.transform = CGAffineTransformMakeScale(1.4f, 1.4f);
            sender.alpha = 0.0f;
        } completion:^(BOOL finished) {
            sender.transform = CGAffineTransformIdentity;
            sender.alpha = 1.0f;
            
            // Immediately respawn bubble at bottom of screen
            NSInteger i = sender.tag;
            CGFloat randomOffsetX = ((float)rand() / RAND_MAX) * (688.0f/6.0f - 110.0f);
            CGFloat cardX = 40.0f + i * (688.0f/6.0f) + randomOffsetX;
            sender.center = CGPointMake(cardX + 55.0f, 824.0f + 60.0f);
            
            // Re-assign random character
            WordModel *word = [self selectRandomWordWithTargetGuarantee];
            [sender setTitle:word.character forState:UIControlStateNormal];
            
            UILabel *pinyin = [sender viewWithTag:101];
            if (pinyin) {
                pinyin.text = word.pinyinWithTone;
            }
        }];
        
        self.score++;
        [self updateScoreStars];
        
        if (self.score >= 5) {
            // Victory!
            [self stopGameTimer];
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"通关成功！"
                                                                           message:@"恭喜你！消灭了所有泡泡字！"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self backBtnClicked];
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            // Next target selection
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self selectNewTarget];
            });
        }
    } else {
        // Incorrect bubble clicked! Play shake animation
        [self shakeView:sender];
        [self replayTargetSound];
    }
}

- (void)shakeView:(UIView *)view {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.duration = 0.07f;
    animation.repeatCount = 3;
    animation.autoreverses = YES;
    animation.fromValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x - 8.0f, view.center.y)];
    animation.toValue = [NSValue valueWithCGPoint:CGPointMake(view.center.x + 8.0f, view.center.y)];
    [view.layer addAnimation:animation forKey:@"position"];
}

- (void)updateScoreStars {
    for (NSInteger i = 0; i < 5; i++) {
        UILabel *star = self.starLabels[i];
        if (i < self.score) {
            star.text = @"★"; // Filled star
        } else {
            star.text = @"☆"; // Empty star
        }
    }
}

- (void)backBtnClicked {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Outline styling helper

- (UIColor *)outlineVariantColor {
    return [self colorFromHex:@"#bdc9c4"];
}

@end

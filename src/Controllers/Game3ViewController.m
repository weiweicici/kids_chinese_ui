#import "Game3ViewController.h"
#import "TextbookManager.h"
#import "AudioManager.h"
#import "SquishyButton.h"

#pragma mark - CharacterCell (self-contained grid cell with rice-grid drawing)

@interface CharacterCell : UIView

@property (strong, nonatomic) UILabel *charLabel;
@property (assign, nonatomic, getter=isFound) BOOL found;

- (void)setCharacter:(NSString *)character;
- (void)flashWrong;
- (void)markFound;

@end

@implementation CharacterCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.borderWidth = 2.0f;
        self.layer.borderColor = [UIColor colorWithRed:165.0f/255.0f green:214.0f/255.0f blue:167.0f/255.0f alpha:1.0f].CGColor;
        self.layer.cornerRadius = 4.0f;
        self.layer.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.12f].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 2.0f);
        self.layer.shadowOpacity = 1.0f;
        self.layer.shadowRadius = 4.0f;

        self.charLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, 4, 4)];
        self.charLabel.textAlignment = NSTextAlignmentCenter;
        self.charLabel.font = [UIFont boldSystemFontOfSize:100.0f];
        self.charLabel.textColor = [UIColor darkTextColor];
        self.charLabel.numberOfLines = 1;
        self.charLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.charLabel.layer.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.25f].CGColor;
        self.charLabel.layer.shadowOffset = CGSizeMake(1.0f, 2.0f);
        self.charLabel.layer.shadowOpacity = 1.0f;
        self.charLabel.layer.shadowRadius = 1.0f;
        [self addSubview:self.charLabel];
    }
    return self;
}

- (void)setCharacter:(NSString *)character {
    self.charLabel.text = character;
}

- (void)markFound {
    self.found = YES;
    self.layer.borderColor = [UIColor colorWithRed:46.0f/255.0f green:125.0f/255.0f blue:50.0f/255.0f alpha:1.0f].CGColor;
    self.backgroundColor = [UIColor colorWithRed:235.0f/255.0f green:248.0f/255.0f blue:235.0f/255.0f alpha:1.0f];
}

- (void)flashWrong {
    self.layer.borderColor = [UIColor redColor].CGColor;
    self.backgroundColor = [UIColor colorWithRed:255.0f/255.0f green:220.0f/255.0f blue:220.0f/255.0f alpha:1.0f];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        weakSelf.layer.borderColor = [UIColor colorWithRed:165.0f/255.0f green:214.0f/255.0f blue:167.0f/255.0f alpha:1.0f].CGColor;
        weakSelf.backgroundColor = [UIColor whiteColor];
    });
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat inset = 8.0f;

    UIColor *lineColor = [UIColor colorWithRed:255.0f/255.0f green:212.0f/255.0f blue:212.0f/255.0f alpha:1.0f];
    [lineColor setStroke];

    CGFloat lengths[] = {4.0f, 4.0f};
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineDash(ctx, 0, lengths, 2);
    CGContextSetLineWidth(ctx, 1.0f);

    CGPoint center = CGPointMake(w / 2, h / 2);

    CGContextMoveToPoint(ctx, inset, center.y);
    CGContextAddLineToPoint(ctx, w - inset, center.y);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, center.x, inset);
    CGContextAddLineToPoint(ctx, center.x, h - inset);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, inset, inset);
    CGContextAddLineToPoint(ctx, w - inset, h - inset);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, w - inset, inset);
    CGContextAddLineToPoint(ctx, inset, h - inset);
    CGContextStrokePath(ctx);
}

@end

#pragma mark - Game3ViewController

@interface Game3ViewController ()

@property (strong, nonatomic) NSArray<WordModel *> *words;
@property (strong, nonatomic) NSMutableArray<CharacterCell *> *cells;
@property (strong, nonatomic) NSMutableArray<NSNumber *> *foundIndices;

@property (strong, nonatomic) UILabel *targetLabel;
@property (strong, nonatomic) UILabel *progressLabel;
@property (strong, nonatomic) NSMutableArray<UILabel *> *starLabels;

@property (strong, nonatomic) UIView *gridContainer;

@property (assign, nonatomic) NSInteger currentTargetIndex;
@property (assign, nonatomic) NSInteger wrongTapCount;
@property (assign, nonatomic) NSInteger totalFoundCount;
@property (assign, nonatomic) BOOL isEasy;
@property (assign, nonatomic) BOOL gameCompleted;
@property (assign, nonatomic) BOOL animating;
@property (assign, nonatomic) BOOL firstAppearance;

@end

@implementation Game3ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.cells = [NSMutableArray array];
    self.foundIndices = [NSMutableArray array];
    self.starLabels = [NSMutableArray array];
    self.currentTargetIndex = -1;
    self.wrongTapCount = 0;
    self.totalFoundCount = 0;
    self.isEasy = YES;
    self.gameCompleted = NO;
    self.animating = NO;
    self.firstAppearance = YES;

    LessonModel *lesson = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    self.words = lesson.words;

    [self setupStaticUI];
    [self buildGrid];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.firstAppearance) {
        self.firstAppearance = NO;
        [self pickNextTarget];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[AudioManager sharedManager] stopCurrentSound];
}

#pragma mark - UI Setup

- (void)setupStaticUI {
    UIView *topNavBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 80.0f)];
    topNavBar.backgroundColor = [[self backgroundColor] colorWithAlphaComponent:0.95f];

    UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 79.5f, 768.0f, 0.5f)];
    topSeparator.backgroundColor = [self surfaceContainerColor];
    [topNavBar addSubview:topSeparator];

    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 16.0f, 48.0f, 48.0f)];
    iconLabel.text = @"🔍";
    iconLabel.font = [UIFont systemFontOfSize:32.0f];
    [topNavBar addSubview:iconLabel];

    self.targetLabel = [[UILabel alloc] initWithFrame:CGRectMake(100.0f, 16.0f, 250.0f, 48.0f)];
    self.targetLabel.text = @"请听声音找字";
    self.targetLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:24.0f];
    self.targetLabel.textColor = [self primaryColor];
    [topNavBar addSubview:self.targetLabel];

    self.progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(360.0f, 16.0f, 80.0f, 48.0f)];
    self.progressLabel.text = @"(0/16)";
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

    // Grid container — centered in game area
    CGFloat gridSize = 700.0f;
    CGFloat gridX = (768.0f - gridSize) / 2;
    CGFloat gridY = 80.0f + (824.0f - gridSize) / 2;
    self.gridContainer = [[UIView alloc] initWithFrame:CGRectMake(gridX, gridY, gridSize, gridSize)];
    self.gridContainer.backgroundColor = [UIColor clearColor];
    [self.canvasView addSubview:self.gridContainer];

    // Footer
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

    if (!self.gameCompleted) {
        [self rebuildGrid];
    }
}

#pragma mark - Grid

- (void)buildGrid {
    for (CharacterCell *cell in self.cells) {
        [cell removeFromSuperview];
    }
    [self.cells removeAllObjects];

    NSMutableArray *order = [NSMutableArray array];
    for (NSInteger i = 0; i < 16; i++) [order addObject:@(i)];
    if (!self.isEasy) {
        for (NSInteger i = 15; i > 0; i--) {
            [order exchangeObjectAtIndex:i withObjectAtIndex:arc4random_uniform((uint32_t)(i + 1))];
        }
    }

    CGFloat cellSize = 700.0f / 4;
    for (NSInteger i = 0; i < 16; i++) {
        NSInteger row = i / 4;
        NSInteger col = i % 4;
        CGRect frame = CGRectMake(col * cellSize, row * cellSize, cellSize, cellSize);

        NSInteger wordIdx = [order[i] integerValue];
        WordModel *word = self.words[wordIdx];

        CharacterCell *cell = [[CharacterCell alloc] initWithFrame:frame];
        cell.tag = wordIdx;
        [cell setCharacter:word.character];

        if ([self.foundIndices containsObject:@(wordIdx)]) {
            [cell markFound];
        }

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cellTapped:)];
        [cell addGestureRecognizer:tap];

        [self.gridContainer addSubview:cell];
        [self.cells addObject:cell];
    }
}

- (void)rebuildGrid {
    // Same as buildGrid but preserves found state
    for (CharacterCell *cell in self.cells) {
        [cell removeFromSuperview];
    }
    [self.cells removeAllObjects];

    NSMutableArray *order = [NSMutableArray array];
    for (NSInteger i = 0; i < 16; i++) [order addObject:@(i)];
    if (!self.isEasy) {
        for (NSInteger i = 15; i > 0; i--) {
            [order exchangeObjectAtIndex:i withObjectAtIndex:arc4random_uniform((uint32_t)(i + 1))];
        }
    }

    CGFloat cellSize = 700.0f / 4;
    for (NSInteger i = 0; i < 16; i++) {
        NSInteger row = i / 4;
        NSInteger col = i % 4;
        CGRect frame = CGRectMake(col * cellSize, row * cellSize, cellSize, cellSize);

        NSInteger wordIdx = [order[i] integerValue];
        WordModel *word = self.words[wordIdx];

        CharacterCell *cell = [[CharacterCell alloc] initWithFrame:frame];
        cell.tag = wordIdx;
        [cell setCharacter:word.character];

        if ([self.foundIndices containsObject:@(wordIdx)]) {
            [cell markFound];
        }

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cellTapped:)];
        [cell addGestureRecognizer:tap];

        [self.gridContainer addSubview:cell];
        [self.cells addObject:cell];
    }
}

#pragma mark - Game Logic

- (void)pickNextTarget {
    if (self.gameCompleted) return;

    NSMutableArray *remaining = [NSMutableArray array];
    for (NSInteger i = 0; i < 16; i++) {
        if (![self.foundIndices containsObject:@(i)]) {
            [remaining addObject:@(i)];
        }
    }

    if (remaining.count == 0) {
        [self gameComplete];
        return;
    }

    NSInteger randIdx = arc4random_uniform((uint32_t)remaining.count);
    self.currentTargetIndex = [remaining[randIdx] integerValue];
    [self replayTargetSound];
}

- (void)replayTargetSound {
    if (self.currentTargetIndex >= 0 && self.currentTargetIndex < 16) {
        [[AudioManager sharedManager] playSoundNamed:[self.words[self.currentTargetIndex] audioFileName]];
    }
}

- (void)cellTapped:(UITapGestureRecognizer *)sender {
    if (self.animating || self.gameCompleted) return;

    CharacterCell *cell = (CharacterCell *)sender.view;
    NSInteger wordIdx = cell.tag;

    if ([self.foundIndices containsObject:@(wordIdx)]) return;

    if (wordIdx == self.currentTargetIndex) {
        [self handleCorrectAtCell:cell wordIndex:wordIdx];
    } else {
        [self handleWrongAtCell:cell];
    }
}

- (void)handleCorrectAtCell:(CharacterCell *)cell wordIndex:(NSInteger)wordIdx {
    self.animating = YES;

    [self.foundIndices addObject:@(wordIdx)];
    self.totalFoundCount++;
    self.progressLabel.text = [NSString stringWithFormat:@"(%ld/16)", (long)self.totalFoundCount];

    // Play word sound as positive reinforcement
    [[AudioManager sharedManager] playSoundNamed:[self.words[wordIdx] audioFileName]];

    // Visual feedback
    [UIView animateWithDuration:0.15f animations:^{
        cell.transform = CGAffineTransformMakeScale(1.1f, 1.1f);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15f animations:^{
            cell.transform = CGAffineTransformIdentity;
        }];
    }];
    [cell markFound];

    // Pick next target after brief pause
    // BUG FIX: use weak self — if user exits within 0.6s VC may be deallocated
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.animating = NO;
        [strongSelf pickNextTarget];
    });
}

- (void)handleWrongAtCell:(CharacterCell *)cell {
    self.wrongTapCount++;
    self.animating = YES;

    [[AudioManager sharedManager] playSoundNamed:@"cuola.caf"];
    [cell flashWrong];

    // BUG FIX: use weak self
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.animating = NO;
    });
}

#pragma mark - Game Complete

- (void)gameComplete {
    self.gameCompleted = YES;

    [[AudioManager sharedManager] playSoundNamed:@"nizhenbang.caf"];
    [self showConfetti];

    NSString *modeKey = self.isEasy ? @"easy" : @"hard";
    NSString *detailKey = [NSString stringWithFormat:@"game3_details_b%ld_l%ld_%@",
                           (long)self.currentBook, (long)self.currentLesson, modeKey];
    NSMutableDictionary *details = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:detailKey] mutableCopy];
    if (!details) details = [NSMutableDictionary dictionary];
    NSInteger compCount = [details[@"completionCount"] integerValue] + 1;
    details[@"completionCount"] = @(compCount);
    details[@"wrongTapCount"] = @(self.wrongTapCount);
    [[NSUserDefaults standardUserDefaults] setObject:details forKey:detailKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // BUG FIX: use weak self — if user exits within 0.3s VC may be deallocated
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *title, *message;
        if (strongSelf.wrongTapCount == 0) {
            title = @"完美通关！";
            message = [NSString stringWithFormat:@"全部答对！你真棒！\n已完成 %ld 次", (long)compCount];
        } else {
            title = @"通关成功！";
            message = [NSString stringWithFormat:@"找到了全部 16/16 个字\n点错了 %ld 次\n已完成 %ld 次",
                       (long)strongSelf.wrongTapCount, (long)compCount];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
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
    [self.foundIndices removeAllObjects];
    self.currentTargetIndex = -1;
    self.wrongTapCount = 0;
    self.totalFoundCount = 0;
    self.gameCompleted = NO;
    self.animating = NO;
    self.targetLabel.text = @"请听声音找字";
    self.progressLabel.text = @"(0/16)";

    [self rebuildGrid];
    [self pickNextTarget];
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

- (void)backBtnClicked {
    [self stopConfetti];
    [self.navigationController popViewControllerAnimated:YES];
}

@end

#import "Game1ViewController.h"
#import "TextbookManager.h"
#import "AudioManager.h"
#import "SquishyButton.h"

@interface Game1ViewController ()

@property (strong, nonatomic) NSArray<WordModel *> *words;
@property (strong, nonatomic) NSMutableArray<UIView *> *slots;
@property (strong, nonatomic) NSMutableArray<UIButton *> *cards;
@property (strong, nonatomic) NSMutableArray<NSValue *> *benchCenters;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, UIButton *> *slotOccupants;

@property (strong, nonatomic) UIView *benchView;

@end

@implementation Game1ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.slots = [NSMutableArray array];
    self.cards = [NSMutableArray array];
    self.benchCenters = [NSMutableArray array];
    self.slotOccupants = [NSMutableDictionary dictionary];
    
    // Fetch curriculum characters
    LessonModel *lesson = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    self.words = lesson.words;
    
    [self setupStaticUI];
    [self renderGameContent];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
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
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 16.0f, 300.0f, 48.0f)];
    titleLabel.text = @"帮我找位置";
    titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:32.0f];
    titleLabel.textColor = [self primaryColor];
    [topNavBar addSubview:titleLabel];
    
    // Buttons right
    SquishyButton *checkBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(442.0f, 16.0f, 130.0f, 48.0f)
                                                    backgroundColor:[self primaryContainerColor]
                                                        shadowColor:[self primaryColor]
                                                       cornerRadius:24.0f];
    [checkBtn setTitle:@"🔍 检查顺序" forState:UIControlStateNormal];
    [checkBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    checkBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [checkBtn addTarget:self action:@selector(checkPlacements) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:checkBtn];
    
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
    
    // 2. Bottom bench (frame: 40, 660, 688, 220)
    self.benchView = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 660.0f, 688.0f, 220.0f)];
    self.benchView.backgroundColor = [self surfaceContainerColor];
    self.benchView.layer.cornerRadius = 24.0f;
    
    self.benchView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.benchView.layer.shadowOpacity = 0.05f;
    self.benchView.layer.shadowRadius = 8.0f;
    self.benchView.layer.shadowOffset = CGSizeMake(0, 4.0f);
    [self.canvasView addSubview:self.benchView];
}

- (void)renderGameContent {
    // 3. Grid Slots (y: 120, size 480x480)
    // 4 columns, slot size 100, gap 26.
    // Center alignment: (768 - 478) / 2 = 145 left margin.
    for (NSInteger idx = 0; idx < 16; idx++) {
        NSInteger row = idx / 4;
        NSInteger col = idx % 4;
        
        CGFloat slotX = 145.0f + col * (100.0f + 26.0f);
        CGFloat slotY = 120.0f + row * (100.0f + 26.0f);
        
        UIView *slot = [[UIView alloc] initWithFrame:CGRectMake(slotX, slotY, 100.0f, 100.0f)];
        slot.backgroundColor = [self colorFromHex:@"#70cfc2"]; // Light teal
        slot.layer.cornerRadius = 16.0f;
        slot.layer.borderWidth = 2.0f;
        
        // Dashed border effect in iOS
        CAShapeLayer *dashedBorder = [CAShapeLayer layer];
        dashedBorder.strokeColor = [UIColor colorWithWhite:1.0f alpha:0.5f].CGColor;
        dashedBorder.fillColor = nil;
        dashedBorder.lineDashPattern = @[@4, @4];
        dashedBorder.path = [UIBezierPath bezierPathWithRoundedRect:slot.bounds cornerRadius:16.0f].CGPath;
        dashedBorder.frame = slot.bounds;
        [slot.layer addSublayer:dashedBorder];
        
        // Add slot index number (centered, translucent)
        UILabel *numLabel = [[UILabel alloc] initWithFrame:slot.bounds];
        numLabel.text = [NSString stringWithFormat:@"%ld", (long)(idx + 1)];
        numLabel.textAlignment = NSTextAlignmentCenter;
        numLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:36.0f];
        numLabel.textColor = [UIColor whiteColor];
        numLabel.alpha = 0.4f;
        [slot addSubview:numLabel];
        
        [self.canvasView addSubview:slot];
        [self.slots addObject:slot];
    }
    
    // 4. Draggable Cards on the Bench (shuffled)
    // Shuffled words
    NSMutableArray<WordModel *> *shuffledWords = [self.words mutableCopy];
    for (NSInteger i = shuffledWords.count - 1; i > 0; i--) {
        NSInteger j = arc4random_uniform((uint32_t)(i + 1));
        [shuffledWords exchangeObjectAtIndex:i withObjectAtIndex:j];
    }
    
    // Place them in 2 rows of 8 cards inside the bench
    CGFloat cardSize = 64.0f;
    CGFloat gapX = 19.0f;
    
    for (NSInteger idx = 0; idx < 16; idx++) {
        WordModel *word = shuffledWords[idx];
        
        NSInteger row = idx / 8;
        NSInteger col = idx % 8;
        
        // Row 1: y=690, Row 2: y=780
        CGFloat cardX = 40.0f + gapX + col * (cardSize + gapX);
        CGFloat cardY = 660.0f + 30.0f + row * (cardSize + 26.0f);
        
        // Store center coordinate in canvas coordinates
        CGPoint center = CGPointMake(cardX + cardSize/2.0f, cardY + cardSize/2.0f);
        [self.benchCenters addObject:[NSValue valueWithCGPoint:center]];
        
        // Create card view
        UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
        card.frame = CGRectMake(cardX, cardY, cardSize, cardSize);
        card.backgroundColor = [self colorFromHex:@"#e1fbee"]; // Pastel green
        card.layer.cornerRadius = 16.0f;
        
        // Tactile card shadow
        card.layer.shadowColor = [self primaryColor].CGColor;
        card.layer.shadowOpacity = 0.08f;
        card.layer.shadowRadius = 4.0f;
        card.layer.shadowOffset = CGSizeMake(0, 2.0f);
        
        [card setTitle:word.character forState:UIControlStateNormal];
        [card setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
        card.titleLabel.font = [self fontWithName:@"Noto Serif" size:36.0f];
        
        // Apply random rotation (+/- 5 degrees) for a playful disordered look
        CGFloat rotation = ((float)rand() / RAND_MAX) * 10.0f - 5.0f;
        card.transform = CGAffineTransformMakeRotation(rotation * M_PI / 180.0f);
        
        // Tag card with its 1-indexed original order in shuffledWords to map bench original position
        card.tag = idx + 1; 
        
        // Attach drag gesture
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        [card addGestureRecognizer:pan];
        
        [self.canvasView addSubview:card];
        [self.cards addObject:card];
    }
}

#pragma mark - Pan Drag Gesture Handler

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    UIButton *card = (UIButton *)gesture.view;
    CGPoint translation = [gesture translationInView:self.canvasView];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self.canvasView bringSubviewToFront:card];
        card.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.15f, 1.15f);
        
        // If card was in a slot, free that slot
        for (NSNumber *slotKey in [self.slotOccupants allKeys]) {
            if (self.slotOccupants[slotKey] == card) {
                [self.slotOccupants removeObjectForKey:slotKey];
                break;
            }
        }
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint newCenter = CGPointMake(card.center.x + translation.x, card.center.y + translation.y);
        card.center = newCenter;
        [gesture setTranslation:CGPointZero inView:self.canvasView];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        // Find closest slot
        UIView *closestSlot = nil;
        CGFloat minDistance = CGFLOAT_MAX;
        NSInteger closestSlotIndex = -1;
        
        for (NSInteger i = 0; i < 16; i++) {
            UIView *slot = self.slots[i];
            CGPoint slotCenterInCanvas = [self.canvasView convertPoint:slot.center fromView:slot.superview];
            CGFloat dist = hypot(card.center.x - slotCenterInCanvas.x, card.center.y - slotCenterInCanvas.y);
            
            if (dist < 60.0f) { // Touch target intersection window
                if (dist < minDistance) {
                    minDistance = dist;
                    closestSlot = slot;
                    closestSlotIndex = i;
                }
            }
        }
        
        if (closestSlot && closestSlotIndex >= 0) {
            UIButton *occupant = self.slotOccupants[@(closestSlotIndex)];
            if (occupant == nil) {
                // Snap card to slot
                CGPoint targetCenter = [self.canvasView convertPoint:closestSlot.center fromView:closestSlot.superview];
                [UIView animateWithDuration:0.15f animations:^{
                    card.center = targetCenter;
                    card.transform = CGAffineTransformIdentity;
                }];
                self.slotOccupants[@(closestSlotIndex)] = card;
                
                // Play standard character sound when placed in grid slot
                [self playWordSound:card.titleLabel.text];
            } else {
                // Slot occupied, send card back to bench
                [self sendCardBackToBench:card];
            }
        } else {
            // Drop outside, bounce back to bench
            [self sendCardBackToBench:card];
        }
    }
}

- (void)sendCardBackToBench:(UIButton *)card {
    NSInteger cardIndex = card.tag - 1; // tag 1-16
    CGPoint benchCenter = [self.benchCenters[cardIndex] CGPointValue];
    CGFloat rotation = ((float)rand() / RAND_MAX) * 10.0f - 5.0f;
    
    [UIView animateWithDuration:0.25f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        card.center = benchCenter;
        card.transform = CGAffineTransformMakeRotation(rotation * M_PI / 180.0f);
    } completion:nil];
}

#pragma mark - Verification

- (void)checkPlacements {
    BOOL allCorrect = YES;
    BOOL anyPlaced = NO;
    
    for (NSInteger i = 0; i < 16; i++) {
        UIButton *card = self.slotOccupants[@(i)];
        if (!card) continue;
        anyPlaced = YES;
        
        WordModel *correctWord = self.words[i];
        NSString *placedChar = card.titleLabel.text;
        
        if ([placedChar isEqualToString:correctWord.character]) {
            // Correct placement!
            [UIView animateWithDuration:0.2f animations:^{
                card.layer.borderWidth = 4.0f;
                card.layer.borderColor = [self primaryColor].CGColor; // Mint green highlight
            }];
        } else {
            // Incorrect! Highlight red and slide back to bench after 1.2s delay
            allCorrect = NO;
            [UIView animateWithDuration:0.2f animations:^{
                card.layer.borderWidth = 4.0f;
                card.layer.borderColor = [UIColor redColor].CGColor; // Red warning highlight
            }];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self sendCardBackToBench:card];
                card.layer.borderWidth = 0.0f;
            });
            
            [self.slotOccupants removeObjectForKey:@(i)];
        }
    }
    
    if (!anyPlaced) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"请先把汉字卡片拖放到网格里！"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    if (allCorrect && self.slotOccupants.count == 16) {
        // Complete victory!
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"恭喜你！"
                                                                       message:@"太棒了！你已经帮所有字找到了正确的位置！"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self backBtnClicked];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)playWordSound:(NSString *)character {
    for (WordModel *word in self.words) {
        if ([word.character isEqualToString:character]) {
            [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];
            break;
        }
    }
}

- (void)backBtnClicked {
    [self.navigationController popViewControllerAnimated:YES];
}

@end

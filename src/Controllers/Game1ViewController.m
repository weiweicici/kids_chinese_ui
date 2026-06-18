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
@property (strong, nonatomic) NSMutableArray<NSNumber *> *lockedSlots;

@property (strong, nonatomic) UIView *benchView;
@property (strong, nonatomic) UIView *checkBtn;

@end

@implementation Game1ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.slots = [NSMutableArray array];
    self.cards = [NSMutableArray array];
    self.benchCenters = [NSMutableArray array];
    self.slotOccupants = [NSMutableDictionary dictionary];
    self.lockedSlots = [NSMutableArray array];

    LessonModel *lesson = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    self.words = lesson.words;

    [self buildGameUI];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[AudioManager sharedManager] stopCurrentSound];
}

- (void)buildGameUI {
    // Remove all previous content
    for (UIView *v in self.canvasView.subviews) {
        [v removeFromSuperview];
    }

    [self.slots removeAllObjects];
    [self.cards removeAllObjects];
    [self.benchCenters removeAllObjects];
    [self.slotOccupants removeAllObjects];
    [self.lockedSlots removeAllObjects];

    // 1. TopNavBar
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

    SquishyButton *checkBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(442.0f, 16.0f, 130.0f, 48.0f)
                                                    backgroundColor:[self primaryContainerColor]
                                                        shadowColor:[self primaryColor]
                                                       cornerRadius:24.0f];
    [checkBtn setTitle:@"🔍 检查顺序" forState:UIControlStateNormal];
    [checkBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    checkBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    checkBtn.hidden = !self.isShuffled;
    checkBtn.tag = 100;
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

    topNavBar.tag = 101;
    [self.canvasView addSubview:topNavBar];

    // 2. Grid slots (520x520, cell 130px — balanced between size and card space)
    CGFloat gridSize = 520.0f;
    CGFloat gridX = (768.0f - gridSize) / 2;
    CGFloat gridY = 100.0f;
    CGFloat cellSize = gridSize / 4;

    for (NSInteger idx = 0; idx < 16; idx++) {
        NSInteger row = idx / 4;
        NSInteger col = idx % 4;

        UIView *slot = [[UIView alloc] initWithFrame:CGRectMake(gridX + col * cellSize, gridY + row * cellSize, cellSize, cellSize)];
        slot.backgroundColor = [UIColor whiteColor];
        slot.layer.borderWidth = 2.0f;
        slot.layer.borderColor = [UIColor colorWithRed:165.0f/255.0f green:214.0f/255.0f blue:167.0f/255.0f alpha:1.0f].CGColor;
        slot.layer.cornerRadius = 4.0f;
        slot.layer.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.08f].CGColor;
        slot.layer.shadowOffset = CGSizeMake(0, 1.0f);
        slot.layer.shadowOpacity = 1.0f;
        slot.layer.shadowRadius = 2.0f;

        // Rice grid dashed lines
        CAShapeLayer *dashedCross = [CAShapeLayer layer];
        dashedCross.strokeColor = [UIColor colorWithRed:255.0f/255.0f green:212.0f/255.0f blue:212.0f/255.0f alpha:1.0f].CGColor;
        dashedCross.fillColor = nil;
        dashedCross.lineDashPattern = @[@4, @4];
        dashedCross.lineWidth = 1.0f;
        CGMutablePathRef path = CGPathCreateMutable();
        CGFloat inset = 8.0f;
        CGFloat midX = cellSize / 2;
        CGFloat midY = cellSize / 2;
        CGPathMoveToPoint(path, NULL, inset, midY);
        CGPathAddLineToPoint(path, NULL, cellSize - inset, midY);
        CGPathMoveToPoint(path, NULL, midX, inset);
        CGPathAddLineToPoint(path, NULL, midX, cellSize - inset);
        CGPathMoveToPoint(path, NULL, inset, inset);
        CGPathAddLineToPoint(path, NULL, cellSize - inset, cellSize - inset);
        CGPathMoveToPoint(path, NULL, cellSize - inset, inset);
        CGPathAddLineToPoint(path, NULL, inset, cellSize - inset);
        dashedCross.path = path;
        CGPathRelease(path);
        [slot.layer addSublayer:dashedCross];

        [self.canvasView addSubview:slot];
        [self.slots addObject:slot];
    }

    // 3. Bench — starts right below grid
    CGFloat benchY = gridY + gridSize + 16.0f;
    CGFloat benchH = 1024.0f - benchY - 46.0f;
    self.benchView = [[UIView alloc] initWithFrame:CGRectMake(40.0f, benchY, 688.0f, benchH)];
    self.benchView.backgroundColor = [self surfaceContainerColor];
    self.benchView.layer.cornerRadius = 24.0f;
    self.benchView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.benchView.layer.shadowOpacity = 0.05f;
    self.benchView.layer.shadowRadius = 8.0f;
    self.benchView.layer.shadowOffset = CGSizeMake(0, 4.0f);
    [self.canvasView addSubview:self.benchView];

    // 4. Cards (88x88 — larger for easier tapping)
    CGFloat cardSize = 88.0f;
    CGFloat totalRowWidth = 8 * cardSize + 7 * 10.0f;
    CGFloat benchContentX = 40.0f + (688.0f - totalRowWidth) / 2;

    CGFloat diffAreaH = 40.0f;
    CGFloat cardAreaTop = 12.0f;
    CGFloat cardAreaH = benchH - diffAreaH - cardAreaTop - 12.0f;
    CGFloat rowGap = fmax(8.0f, (cardAreaH - 2 * cardSize) / 3);

    NSMutableArray<WordModel *> *orderedWords = [self.words mutableCopy];
    if (self.isShuffled) {
        for (NSInteger i = orderedWords.count - 1; i > 0; i--) {
            NSInteger j = arc4random_uniform((uint32_t)(i + 1));
            [orderedWords exchangeObjectAtIndex:i withObjectAtIndex:j];
        }
    }

    // Store word order mapping: card tag → actual word index (1-based)
    for (NSInteger idx = 0; idx < 16; idx++) {
        WordModel *word = orderedWords[idx];
        NSInteger row = idx / 8;
        NSInteger col = idx % 8;

        CGFloat cardX = benchContentX + col * (cardSize + 10.0f);
        CGFloat cardY = benchY + cardAreaTop + rowGap + row * (cardSize + rowGap);
        CGPoint center = CGPointMake(cardX + cardSize / 2.0f, cardY + cardSize / 2.0f);
        [self.benchCenters addObject:[NSValue valueWithCGPoint:center]];

        UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
        card.frame = CGRectMake(cardX, cardY, cardSize, cardSize);
        card.backgroundColor = [UIColor colorWithRed:225.0f/255.0f green:251.0f/255.0f blue:238.0f/255.0f alpha:1.0f];
        card.layer.cornerRadius = 12.0f;
        card.layer.shadowColor = [self primaryColor].CGColor;
        card.layer.shadowOpacity = 0.10f;
        card.layer.shadowRadius = 4.0f;
        card.layer.shadowOffset = CGSizeMake(0, 2.0f);

        [card setTitle:word.character forState:UIControlStateNormal];
        [card setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
        card.titleLabel.font = [UIFont boldSystemFontOfSize:42.0f];

        CGFloat rotation = ((float)rand() / RAND_MAX) * 10.0f - 5.0f;
        card.transform = CGAffineTransformMakeRotation(rotation * M_PI / 180.0f);
        card.tag = idx + 1;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        [card addGestureRecognizer:pan];

        [self.canvasView addSubview:card];
        [self.cards addObject:card];
    }

    // 5. Difficulty selector — added LAST so always on top in z-order
    CGFloat diffRowY = benchY + benchH - 36.0f;

    UILabel *easyLabel = [[UILabel alloc] initWithFrame:CGRectMake(180.0f, diffRowY, 30.0f, 30.0f)];
    easyLabel.text = @"易";
    easyLabel.font = [UIFont systemFontOfSize:18.0f];
    easyLabel.textColor = self.isShuffled ? [self onSurfaceVariantColor] : [self primaryColor];
    easyLabel.textAlignment = NSTextAlignmentCenter;
    easyLabel.userInteractionEnabled = NO;
    easyLabel.tag = 201;
    [self.canvasView addSubview:easyLabel];

    // Stars — purely visual UILabels (no gesture recognizers)
    for (NSInteger i = 1; i <= 5; i++) {
        UILabel *star = [[UILabel alloc] initWithFrame:CGRectMake(215.0f + (i - 1) * 30.0f, diffRowY, 30.0f, 36.0f)];
        star.tag = 300 + i;
        star.textAlignment = NSTextAlignmentCenter;
        star.font = [UIFont systemFontOfSize:22.0f];
        star.textColor = [UIColor clearColor];
        star.userInteractionEnabled = NO; // purely visual
        [self.canvasView addSubview:star];
    }

    UILabel *hardLabel = [[UILabel alloc] initWithFrame:CGRectMake(395.0f, diffRowY, 30.0f, 30.0f)];
    hardLabel.text = @"难";
    hardLabel.font = [UIFont systemFontOfSize:18.0f];
    hardLabel.textColor = self.isShuffled ? [self primaryColor] : [self onSurfaceVariantColor];
    hardLabel.textAlignment = NSTextAlignmentCenter;
    hardLabel.userInteractionEnabled = NO;
    hardLabel.tag = 202;
    [self.canvasView addSubview:hardLabel];

    // BUG 1 FIX: Use invisible UIButton overlays for touch targets.
    // UILabel+UITapGestureRecognizer fails on iOS 9 when UIPanGestureRecognizers exist
    // on sibling views. UIButton UIControlEventTouchUpInside uses the UIControl touch
    // tracking path (same as SquishyButton) which is not affected by this iOS 9 bug.
    // "Easy" touch target — covers 易 label + star 1 zone
    UIButton *easyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    easyBtn.frame = CGRectMake(175.0f, diffRowY - 4.0f, 80.0f, 44.0f);
    easyBtn.backgroundColor = [UIColor clearColor];
    easyBtn.tag = 401; // easy mode
    [easyBtn addTarget:self action:@selector(difficultyBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.canvasView addSubview:easyBtn];

    // "Hard" touch target — covers star 5 + 难 label zone
    UIButton *hardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hardBtn.frame = CGRectMake(330.0f, diffRowY - 4.0f, 100.0f, 44.0f);
    hardBtn.backgroundColor = [UIColor clearColor];
    hardBtn.tag = 402; // hard mode
    [hardBtn addTarget:self action:@selector(difficultyBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.canvasView addSubview:hardBtn];

    [self updateStarsDisplay];
}

- (void)updateStarsDisplay {
    for (NSInteger i = 1; i <= 5; i++) {
        UILabel *star = (UILabel *)[self.canvasView viewWithTag:300 + i];
        if (self.isShuffled) {
            star.text = @"★";
            star.textColor = [self primaryColor];
        } else {
            if (i == 1) {
                star.text = @"★";
                star.textColor = [self primaryColor];
            } else {
                star.text = @"☆";
                star.textColor = [self onSurfaceVariantColor];
            }
        }
    }
}

// BUG 1 FIX: UIButton target-action replaces UITapGestureRecognizer on UILabel.
- (void)difficultyBtnTapped:(UIButton *)sender {
    BOOL newShuffled = (sender.tag == 402); // 402 = hard, 401 = easy
    if (newShuffled == self.isShuffled) return;
    self.isShuffled = newShuffled;

    // Remove old cards and reset state
    for (UIButton *card in self.cards) {
        [card removeFromSuperview];
    }
    [self.cards removeAllObjects];
    [self.benchCenters removeAllObjects];
    [self.slotOccupants removeAllObjects];
    [self.lockedSlots removeAllObjects];

    // Rebuild cards with new order
    [self rebuildCards];

    // BUG 1 FIX: After rebuildCards, new card views are on top of the invisible
    // UIButton touch targets. Bring the buttons back to front so touches reach them.
    UIButton *easyHitBtn = (UIButton *)[self.canvasView viewWithTag:401];
    UIButton *hardHitBtn = (UIButton *)[self.canvasView viewWithTag:402];
    if (easyHitBtn) [self.canvasView bringSubviewToFront:easyHitBtn];
    if (hardHitBtn) [self.canvasView bringSubviewToFront:hardHitBtn];

    // Show/hide check button
    SquishyButton *checkBtn = (SquishyButton *)[self.canvasView viewWithTag:100];
    checkBtn.hidden = !self.isShuffled;

    // Update labels
    UILabel *easyLabel = (UILabel *)[self.canvasView viewWithTag:201];
    UILabel *hardLabel = (UILabel *)[self.canvasView viewWithTag:202];
    easyLabel.textColor = self.isShuffled ? [self onSurfaceVariantColor] : [self primaryColor];
    hardLabel.textColor = self.isShuffled ? [self primaryColor] : [self onSurfaceVariantColor];

    [self updateStarsDisplay];
}

- (void)rebuildCards {
    // Recompute layout (must match buildGameUI)
    CGFloat gridY = 100.0f;
    CGFloat gridSize = 520.0f;
    CGFloat benchY = gridY + gridSize + 16.0f;
    CGFloat benchH = 1024.0f - benchY - 46.0f;
    CGFloat cardSize = 88.0f;
    CGFloat totalRowWidth = 8 * cardSize + 7 * 10.0f;
    CGFloat benchContentX = 40.0f + (688.0f - totalRowWidth) / 2;
    CGFloat diffAreaH = 40.0f;
    CGFloat cardAreaTop = 12.0f;
    CGFloat cardAreaH = benchH - diffAreaH - cardAreaTop - 12.0f;
    CGFloat rowGap = fmax(8.0f, (cardAreaH - 2 * cardSize) / 3);

    NSMutableArray<WordModel *> *orderedWords = [self.words mutableCopy];
    if (self.isShuffled) {
        for (NSInteger i = orderedWords.count - 1; i > 0; i--) {
            NSInteger j = arc4random_uniform((uint32_t)(i + 1));
            [orderedWords exchangeObjectAtIndex:i withObjectAtIndex:j];
        }
    }

    for (NSInteger idx = 0; idx < 16; idx++) {
        WordModel *word = orderedWords[idx];
        NSInteger row = idx / 8;
        NSInteger col = idx % 8;

        CGFloat cardX = benchContentX + col * (cardSize + 10.0f);
        CGFloat cardY = benchY + cardAreaTop + rowGap + row * (cardSize + rowGap);
        CGPoint center = CGPointMake(cardX + cardSize / 2.0f, cardY + cardSize / 2.0f);
        [self.benchCenters addObject:[NSValue valueWithCGPoint:center]];

        UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
        card.frame = CGRectMake(cardX, cardY, cardSize, cardSize);
        card.backgroundColor = [UIColor colorWithRed:225.0f/255.0f green:251.0f/255.0f blue:238.0f/255.0f alpha:1.0f];
        card.layer.cornerRadius = 12.0f;
        card.layer.shadowColor = [self primaryColor].CGColor;
        card.layer.shadowOpacity = 0.10f;
        card.layer.shadowRadius = 4.0f;
        card.layer.shadowOffset = CGSizeMake(0, 2.0f);

        [card setTitle:word.character forState:UIControlStateNormal];
        [card setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
        card.titleLabel.font = [UIFont boldSystemFontOfSize:42.0f];

        CGFloat rotation = ((float)rand() / RAND_MAX) * 10.0f - 5.0f;
        card.transform = CGAffineTransformMakeRotation(rotation * M_PI / 180.0f);
        card.tag = idx + 1;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
        [card addGestureRecognizer:pan];

        [self.canvasView addSubview:card];
        [self.cards addObject:card];
    }
}

#pragma mark - Pan Drag Gesture

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    UIButton *card = (UIButton *)gesture.view;
    CGPoint translation = [gesture translationInView:self.canvasView];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        // BUG 2 FIX: Reset transform to identity FIRST before anything else.
        // If the card was returned to bench with a rotation transform, starting a
        // new drag while the rotation is active confuses iOS 9 pan gesture tracking.
        card.transform = CGAffineTransformIdentity;
        [self.canvasView bringSubviewToFront:card];
        card.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.15f, 1.15f);

        // Remove from slotOccupants (card is being lifted)
        for (NSNumber *slotKey in [self.slotOccupants allKeys]) {
            if (self.slotOccupants[slotKey] == card) {
                [self.slotOccupants removeObjectForKey:slotKey];
                // BUG 2 FIX: Also remove from lockedSlots so an un-placed card
                // doesn't leave a permanently locked-but-empty slot.
                [self.lockedSlots removeObject:slotKey];
                break;
            }
        }
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        card.center = CGPointMake(card.center.x + translation.x, card.center.y + translation.y);
        [gesture setTranslation:CGPointZero inView:self.canvasView];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        UIView *closestSlot = nil;
        CGFloat minDistance = CGFLOAT_MAX;
        NSInteger closestSlotIndex = -1;

        for (NSInteger i = 0; i < 16; i++) {
            if ([self.lockedSlots containsObject:@(i)]) continue;
            UIView *slot = self.slots[i];
            CGPoint slotCenter = [self.canvasView convertPoint:slot.center fromView:slot.superview];
            CGFloat dist = hypot(card.center.x - slotCenter.x, card.center.y - slotCenter.y);
            if (dist < 60.0f && dist < minDistance) {
                minDistance = dist;
                closestSlot = slot;
                closestSlotIndex = i;
            }
        }

        if (closestSlot && closestSlotIndex >= 0) {
            UIButton *occupant = self.slotOccupants[@(closestSlotIndex)];
            if (occupant == nil) {
                if (!self.isShuffled) {
                    [self easyModeCheckPlacement:card slotIndex:closestSlotIndex closestSlot:closestSlot];
                } else {
                    CGPoint targetCenter = [self.canvasView convertPoint:closestSlot.center fromView:closestSlot.superview];
                    [UIView animateWithDuration:0.15f animations:^{
                        card.center = targetCenter;
                        card.transform = CGAffineTransformIdentity;
                    }];
                    self.slotOccupants[@(closestSlotIndex)] = card;
                    [self playWordSound:card.titleLabel.text];
                }
            } else {
                [self sendCardBackToBench:card];
            }
        } else {
            [self sendCardBackToBench:card];
        }
    }
}

- (void)easyModeCheckPlacement:(UIButton *)card slotIndex:(NSInteger)slotIndex closestSlot:(UIView *)closestSlot {
    WordModel *correctWord = self.words[slotIndex];

    if ([card.titleLabel.text isEqualToString:correctWord.character]) {
        CGPoint targetCenter = [self.canvasView convertPoint:closestSlot.center fromView:closestSlot.superview];
        [UIView animateWithDuration:0.15f animations:^{
            card.center = targetCenter;
            card.transform = CGAffineTransformIdentity;
        }];
        card.layer.borderWidth = 3.0f;
        card.layer.borderColor = [UIColor colorWithRed:46.0f/255.0f green:125.0f/255.0f blue:50.0f/255.0f alpha:1.0f].CGColor;
        self.slotOccupants[@(slotIndex)] = card;
        [self.lockedSlots addObject:@(slotIndex)];
        [self playWordSound:card.titleLabel.text];

        if (self.lockedSlots.count == 16) {
            [self gameComplete];
        }
    } else {
        [self sendCardBackToBench:card];
        [[AudioManager sharedManager] playSoundNamed:@"cuola.caf"];
    }
}

- (void)sendCardBackToBench:(UIButton *)card {
    NSInteger cardIndex = card.tag - 1;
    if (cardIndex < 0 || cardIndex >= (NSInteger)self.benchCenters.count) return;
    CGPoint benchCenter = [self.benchCenters[cardIndex] CGPointValue];
    CGFloat rotation = ((float)rand() / RAND_MAX) * 10.0f - 5.0f;

    // BUG 2 FIX: Do NOT animate card.transform inside the animation block.
    // Animating transform inside UIView animateWithDuration on iOS 9 can leave
    // the view's user interaction permanently disabled when completion:nil is used.
    // Fix: animate only center, allow user interaction during animation, and apply
    // rotation in the completion block so transform state is always clean.
    [UIView animateWithDuration:0.25f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        card.center = benchCenter;
        card.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        // Apply rotation after center animation so it never interferes with pan tracking
        card.transform = CGAffineTransformMakeRotation(rotation * M_PI / 180.0f);
    }];
}

#pragma mark - Verification (Hard Mode)

- (void)checkPlacements {
    BOOL allCorrect = YES;
    BOOL anyPlaced = NO;

    for (NSInteger i = 0; i < 16; i++) {
        if ([self.lockedSlots containsObject:@(i)]) continue;

        UIButton *card = self.slotOccupants[@(i)];
        if (!card) continue;
        anyPlaced = YES;

        if ([card.titleLabel.text isEqualToString:self.words[i].character]) {
            [UIView animateWithDuration:0.2f animations:^{
                card.layer.borderWidth = 3.0f;
                card.layer.borderColor = [UIColor colorWithRed:46.0f/255.0f green:125.0f/255.0f blue:50.0f/255.0f alpha:1.0f].CGColor;
            }];
            [self.lockedSlots addObject:@(i)];
            [self playWordSound:card.titleLabel.text];
        } else {
            allCorrect = NO;
            [UIView animateWithDuration:0.2f animations:^{
                card.layer.borderWidth = 3.0f;
                card.layer.borderColor = [UIColor redColor].CGColor;
            }];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self sendCardBackToBench:card];
                card.layer.borderWidth = 0.0f;
                card.layer.borderColor = [UIColor clearColor].CGColor;
            });
            [self.slotOccupants removeObjectForKey:@(i)];
        }
    }

    NSInteger totalPlaced = self.slotOccupants.count + self.lockedSlots.count;

    if (!anyPlaced && self.lockedSlots.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                       message:@"请先把汉字卡片拖放到网格里！"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    if (allCorrect && totalPlaced == 16) {
        [self gameComplete];
    }
}

#pragma mark - Game Complete

- (void)gameComplete {
    NSString *modeKey = self.isShuffled ? @"hard" : @"easy";
    NSString *key = [NSString stringWithFormat:@"game1_completion_b%ld_l%ld_%@",
                     (long)self.currentBook, (long)self.currentLesson, modeKey];
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    count++;
    [[NSUserDefaults standardUserDefaults] setInteger:count forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Play correct sound first
    [[AudioManager sharedManager] playSoundNamed:@"nizhenbang.caf"];

    // Confetti effect
    [self showConfetti];

    // Show alert with delay so sound plays first
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"恭喜你！"
                                                                       message:[NSString stringWithFormat:@"宝贝，全对了，你真棒！\n已完成 %ld 次", (long)count]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"再玩一次" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self stopConfetti];
            [self buildGameUI];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"返回" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self stopConfetti];
            [self backBtnClicked];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - Confetti Animation

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
    for (CALayer *layer in self.canvasView.layer.sublayers) {
        if ([layer.name isEqualToString:@"confetti"]) {
            [layer removeFromSuperlayer];
        }
    }
}

#pragma mark - Audio

- (void)playWordSound:(NSString *)character {
    for (WordModel *word in self.words) {
        if ([word.character isEqualToString:character]) {
            [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];
            break;
        }
    }
}

- (void)backBtnClicked {
    [self stopConfetti];
    [self.navigationController popViewControllerAnimated:YES];
}

@end

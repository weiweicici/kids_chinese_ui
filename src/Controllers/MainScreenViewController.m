#import "MainScreenViewController.h"
#import "TextbookManager.h"
#import "AudioManager.h"
#if __has_include("SupabaseClient.h")
#import "SupabaseClient.h"
#endif
#import "SquishyButton.h"
#import "RiceCellView.h"
#import "FlashcardViewController.h"
#import "Game1ViewController.h"
#import "Game2ViewController.h"
#import "Game3ViewController.h"

@interface MainScreenViewController ()

@property (strong, nonatomic) LessonModel *lessonModel;
@property (strong, nonatomic) UIView *gridContainer;
@property (strong, nonatomic) UILabel *titleLabel;

// Lesson Picker UI Overlay
@property (strong, nonatomic) UIView *pickerOverlay;
@property (assign, nonatomic) NSInteger selectedBookForPicker;

@property (strong, nonatomic) NSMutableArray<RiceCellView *> *cellViews;
@property (assign, nonatomic) NSInteger selectedWordIndex;

@end

@implementation MainScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.currentBook = 1;
    self.currentLesson = 1;
    self.selectedBookForPicker = 1;
    self.cellViews = [NSMutableArray array];
    self.selectedWordIndex = -1;
    
    [self setupStaticUI];
    [self reloadLessonData];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // Stop sound playing when transitioning out of main screen
    [[AudioManager sharedManager] stopCurrentSound];
}

#pragma mark - UI Setup

- (void)setupStaticUI {
    // 1. TopNavBar (frame: 0, 0, 768, 80)
    UIView *topNavBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 80.0f)];
    topNavBar.backgroundColor = [[self backgroundColor] colorWithAlphaComponent:0.95f];
    
    // Add bottom separator
    UIView *topSeparator = [[UIView alloc] initWithFrame:CGRectMake(0, 79.5f, 768.0f, 0.5f)];
    topSeparator.backgroundColor = [self surfaceContainerColor];
    [topNavBar addSubview:topSeparator];
    
    // Back button (small arrow, pushed from HomeScreen)
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(4, 20, 40, 40);
    [backBtn setTitle:@"◀" forState:UIControlStateNormal];
    [backBtn setTitleColor:[self onSurfaceVariantColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont systemFontOfSize:22];
    [backBtn addTarget:self action:@selector(backToHome) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:backBtn];
    
    // Book icon (circle with icon)
    UIView *bookIconView = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 16.0f, 48.0f, 48.0f)];
    bookIconView.backgroundColor = [self primaryContainerColor];
    bookIconView.layer.cornerRadius = 24.0f;
    bookIconView.layer.masksToBounds = YES;
    
    UILabel *bookEmoji = [[UILabel alloc] initWithFrame:bookIconView.bounds];
    bookEmoji.text = @"📖";
    bookEmoji.textAlignment = NSTextAlignmentCenter;
    bookEmoji.font = [UIFont systemFontOfSize:22.0f];
    [bookIconView addSubview:bookEmoji];
    [topNavBar addSubview:bookIconView];
    
    // Title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(100.0f, 16.0f, 210.0f, 48.0f)];
    self.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:24.0f];
    self.titleLabel.textColor = [self primaryColor];
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    [topNavBar addSubview:self.titleLabel];
    
    // Squishy Buttons in Topbar
    SquishyButton *menuBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(320.0f, 16.0f, 110.0f, 48.0f)
                                                  backgroundColor:[self primaryContainerColor]
                                                      shadowColor:[self primaryColor]
                                                     cornerRadius:24.0f];
    [menuBtn setTitle:@"章节目录" forState:UIControlStateNormal];
    [menuBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    menuBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [menuBtn addTarget:self action:@selector(menuBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:menuBtn];
    
    SquishyButton *followBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(442.0f, 16.0f, 110.0f, 48.0f)
                                                    backgroundColor:[self primaryContainerColor]
                                                        shadowColor:[self primaryColor]
                                                       cornerRadius:24.0f];
    [followBtn setTitle:@"全文跟读" forState:UIControlStateNormal];
    [followBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    followBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [followBtn addTarget:self action:@selector(followBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:followBtn];
    
    SquishyButton *readBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(564.0f, 16.0f, 110.0f, 48.0f)
                                                  backgroundColor:[self primaryContainerColor]
                                                      shadowColor:[self primaryColor]
                                                     cornerRadius:24.0f];
    [readBtn setTitle:@"全文朗读" forState:UIControlStateNormal];
    [readBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    readBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [readBtn addTarget:self action:@selector(readBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:readBtn];
    
    // Hamburger menu placeholder
    UIButton *hamburgerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hamburgerBtn.frame = CGRectMake(686.0f, 16.0f, 48.0f, 48.0f);
    hamburgerBtn.layer.cornerRadius = 24.0f;
    [hamburgerBtn setTitle:@"☰" forState:UIControlStateNormal];
    [hamburgerBtn setTitleColor:[self primaryColor] forState:UIControlStateNormal];
    hamburgerBtn.titleLabel.font = [UIFont systemFontOfSize:26.0f];
    [hamburgerBtn addTarget:self action:@selector(menuBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [topNavBar addSubview:hamburgerBtn];
    
    [self.canvasView addSubview:topNavBar];
    
    // 2. Character Grid Container (tiled as large as possible)
    // 768x1024 canvas: top bar 80, bottom nav 100 → available 844 height
    CGFloat gridSize = 700.0f;
    CGFloat gridX = (768.0f - gridSize) / 2;
    CGFloat gridY = 80.0f + (844.0f - gridSize) / 2;
    self.gridContainer = [[UIView alloc] initWithFrame:CGRectMake(gridX, gridY, gridSize, gridSize)];
    self.gridContainer.backgroundColor = [UIColor clearColor];
    [self.canvasView addSubview:self.gridContainer];
    
    // 3. BottomNavBar (frame: 0, 924, 768, 100)
    UIView *bottomNavBar = [[UIView alloc] initWithFrame:CGRectMake(0, 924.0f, 768.0f, 100.0f)];
    bottomNavBar.backgroundColor = [self surfaceContainerLowestColor];
    
    // Top shadow for BottomNavBar
    bottomNavBar.layer.shadowColor = [self primaryColor].CGColor;
    bottomNavBar.layer.shadowOpacity = 0.05f;
    bottomNavBar.layer.shadowRadius = 8.0f;
    bottomNavBar.layer.shadowOffset = CGSizeMake(0, -4.0f);
    
    // Active Tab: 拼字游戏 (Tab 1)
    SquishyButton *tab1 = [[SquishyButton alloc] initWithFrame:CGRectMake(40.0f, 18.0f, 130.0f, 64.0f)
                                               backgroundColor:[self primaryContainerColor]
                                                   shadowColor:[self primaryColor]
                                                  cornerRadius:16.0f];
    [tab1 setTitle:@"🧩 拼字游戏" forState:UIControlStateNormal];
    [tab1 setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    tab1.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [tab1 addTarget:self action:@selector(tab1Clicked) forControlEvents:UIControlEventTouchUpInside];
    [bottomNavBar addSubview:tab1];
    
    // Tab 2: 跳字游戏
    SquishyButton *tab2 = [[SquishyButton alloc] initWithFrame:CGRectMake(186.0f, 18.0f, 130.0f, 64.0f)
                                               backgroundColor:[self primaryContainerColor]
                                                   shadowColor:[self primaryColor]
                                                  cornerRadius:16.0f];
    [tab2 setTitle:@"🫧 跳字游戏" forState:UIControlStateNormal];
    [tab2 setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    tab2.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [tab2 addTarget:self action:@selector(tab2Clicked) forControlEvents:UIControlEventTouchUpInside];
    [bottomNavBar addSubview:tab2];
    
    // Tab 3: 找字游戏
    SquishyButton *tab3 = [[SquishyButton alloc] initWithFrame:CGRectMake(332.0f, 18.0f, 130.0f, 64.0f)
                                               backgroundColor:[self primaryContainerColor]
                                                   shadowColor:[self primaryColor]
                                                  cornerRadius:16.0f];
    [tab3 setTitle:@"🔍 找字游戏" forState:UIControlStateNormal];
    [tab3 setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    tab3.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [tab3 addTarget:self action:@selector(tab3Clicked) forControlEvents:UIControlEventTouchUpInside];
    [bottomNavBar addSubview:tab3];
    
    // Tab 4: 认读游戏
    SquishyButton *tab4 = [[SquishyButton alloc] initWithFrame:CGRectMake(478.0f, 18.0f, 130.0f, 64.0f)
                                               backgroundColor:[self primaryContainerColor]
                                                   shadowColor:[self primaryColor]
                                                  cornerRadius:16.0f];
    [tab4 setTitle:@"👁️ 认读游戏" forState:UIControlStateNormal];
    [tab4 setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    tab4.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:16.0f];
    [tab4 addTarget:self action:@selector(tab4Clicked) forControlEvents:UIControlEventTouchUpInside];
    [bottomNavBar addSubview:tab4];
    
    // Award button: Trophy circle
    UIButton *awardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    awardBtn.frame = CGRectMake(664.0f, 18.0f, 64.0f, 64.0f);
    awardBtn.backgroundColor = [self secondaryContainerColor];
    awardBtn.layer.cornerRadius = 32.0f;
    awardBtn.layer.borderWidth = 4.0f;
    awardBtn.layer.borderColor = [self surfaceContainerLowestColor].CGColor;
    [awardBtn setTitle:@"🏆" forState:UIControlStateNormal];
    awardBtn.titleLabel.font = [UIFont systemFontOfSize:28.0f];
    [awardBtn addTarget:self action:@selector(awardBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    
    awardBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    awardBtn.layer.shadowOpacity = 0.15f;
    awardBtn.layer.shadowRadius = 4.0f;
    awardBtn.layer.shadowOffset = CGSizeMake(0, 2.0f);
    [bottomNavBar addSubview:awardBtn];
    
    [self.canvasView addSubview:bottomNavBar];

}

#pragma mark - Reload Data

- (void)reloadLessonData {
    [[AudioManager sharedManager] stopCurrentSound];
    self.lessonModel = [[TextbookManager sharedManager] lessonForBook:self.currentBook lesson:self.currentLesson];
    if (!self.lessonModel) {
        NSLog(@"Error: Lesson data not found for book %ld lesson %ld", (long)self.currentBook, (long)self.currentLesson);
        return;
    }
    
    // Update topbar title
    self.titleLabel.text = [NSString stringWithFormat:@"第%@册 第%ld课", 
                            [self chineseNumberForBook:self.currentBook], 
                            (long)self.currentLesson];
    
    // Remove previous cell views
    for (RiceCellView *cell in self.cellViews) {
        [cell removeFromSuperview];
    }
    [self.cellViews removeAllObjects];
    self.selectedWordIndex = -1;
    
    // Render 4x4 rice grid (16 characters, evenly tiled)
    CGFloat cellSize = self.gridContainer.frame.size.width / 4;
    NSArray<WordModel *> *words = self.lessonModel.words;
    for (NSInteger idx = 0; idx < 16; idx++) {
        if (idx >= words.count) break;
        WordModel *word = words[idx];
        
        NSInteger row = idx / 4;
        NSInteger col = idx % 4;
        
        CGRect cellFrame = CGRectMake(col * cellSize, row * cellSize, cellSize, cellSize);
        RiceCellView *cell = [self createCellForWord:word frame:cellFrame index:idx];
        [self.gridContainer addSubview:cell];
        [self.cellViews addObject:cell];
    }
}

- (RiceCellView *)createCellForWord:(WordModel *)word frame:(CGRect)frame index:(NSInteger)index {
    RiceCellView *cell = [[RiceCellView alloc] initWithFrame:frame];
    [cell setCharacter:word.character];

    __weak typeof(self) weakSelf = self;
    cell.onTouchDown = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // Deselect previous cell
        if (strongSelf.selectedWordIndex >= 0 && strongSelf.selectedWordIndex < strongSelf.cellViews.count) {
            RiceCellView *prevCell = strongSelf.cellViews[strongSelf.selectedWordIndex];
            prevCell.selected = NO;
        }

        strongSelf.selectedWordIndex = index;

        // Play audio
        [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];
    };

    return cell;
}

#pragma mark - Actions

- (void)backToHome {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cardClicked:(RiceCellView *)sender {
    // Handled by onTouchDown block in createCellForWord:
}

- (void)followBtnClicked {
    // Play follow along audio: e.g. "1-1a.mp3"
    [[AudioManager sharedManager] playSoundNamed:[self.lessonModel readAlongAudioFileName]];
}

- (void)readBtnClicked {
    // Play read aloud audio: e.g. "1-1.mp3"
    [[AudioManager sharedManager] playSoundNamed:[self.lessonModel readAloudAudioFileName]];
}

- (void)tab1Clicked {
    // Navigate to Game 1 (Hanzi Quest)
    Game1ViewController *gameVC = [[Game1ViewController alloc] init];
    gameVC.currentBook = self.currentBook;
    gameVC.currentLesson = self.currentLesson;
    [self.navigationController pushViewController:gameVC animated:YES];
}

- (void)tab2Clicked {
    // Navigate to Game 2 (Bubble Pop)
    Game2ViewController *gameVC = [[Game2ViewController alloc] init];
    gameVC.currentBook = self.currentBook;
    gameVC.currentLesson = self.currentLesson;
    [self.navigationController pushViewController:gameVC animated:YES];
}

- (void)tab3Clicked {
    Game3ViewController *gameVC = [[Game3ViewController alloc] init];
    gameVC.currentBook = self.currentBook;
    gameVC.currentLesson = self.currentLesson;
    [self.navigationController pushViewController:gameVC animated:YES];
}

- (void)tab4Clicked {
    FlashcardViewController *flashcardVC = [[FlashcardViewController alloc] init];
    flashcardVC.currentBook = self.currentBook;
    flashcardVC.currentLesson = self.currentLesson;
    flashcardVC.selectedWordIndex = 1;
    flashcardVC.isGameMode = YES;
    flashcardVC.isShuffled = NO;
    [self.navigationController pushViewController:flashcardVC animated:YES];
}

- (void)comingSoonAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"敬请期待"
                                                                   message:@"该游戏还在开发中，快去试试其他游戏吧！"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)awardBtnClicked {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"我的荣誉"
                                                                   message:@"完成关卡游戏即可赢取奖杯奖励！"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"加油" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Lesson Picker modal

- (void)menuBtnClicked {
    if (self.pickerOverlay) {
        return;
    }
    
    self.selectedBookForPicker = self.currentBook;
    
    // Create grey translucent backdrop overlay
    self.pickerOverlay = [[UIView alloc] initWithFrame:self.canvasView.bounds];
    self.pickerOverlay.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    
    // Tap to dismiss
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissLessonPicker)];
    [self.pickerOverlay addGestureRecognizer:tap];
    
    // Center container card
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(134.0f, 212.0f, 500.0f, 600.0f)];
    container.backgroundColor = [self surfaceContainerLowestColor];
    container.layer.cornerRadius = 24.0f;
    container.clipsToBounds = YES;
    
    // Stop tap passing through to background
    UITapGestureRecognizer *stopTap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [container addGestureRecognizer:stopTap];
    
    // Title
    UILabel *pickerTitle = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 20.0f, 460.0f, 30.0f)];
    pickerTitle.text = @"选择课文章节";
    pickerTitle.textAlignment = NSTextAlignmentCenter;
    pickerTitle.font = [self fontWithName:@"Plus Jakarta Sans" size:22.0f];
    pickerTitle.textColor = [self primaryColor];
    [container addSubview:pickerTitle];
    
    // Segment Control for Books
    UISegmentedControl *bookSegments = [[UISegmentedControl alloc] initWithItems:@[@"第一册", @"第二册", @"第三册"]];
    bookSegments.frame = CGRectMake(40.0f, 65.0f, 420.0f, 40.0f);
    bookSegments.selectedSegmentIndex = self.selectedBookForPicker - 1;
    [bookSegments addTarget:self action:@selector(pickerBookChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Apply styling matching the color palette
    if ([bookSegments respondsToSelector:@selector(setTintColor:)]) {
        bookSegments.tintColor = [self primaryColor];
    }
    [container addSubview:bookSegments];
    
    // Container for lesson buttons grid (we'll rebuild it)
    UIView *lessonsGrid = [[UIView alloc] initWithFrame:CGRectMake(20.0f, 120.0f, 460.0f, 450.0f)];
    lessonsGrid.tag = 999;
    [container addSubview:lessonsGrid];
    
    [self rebuildPickerLessonsGridInsideContainer:lessonsGrid];
    
    [self.pickerOverlay addSubview:container];
    [self.canvasView addSubview:self.pickerOverlay];
    
    // Animation entrance
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
        // Clear old buttons
        for (UIView *v in grid.subviews) {
            [v removeFromSuperview];
        }
        [self rebuildPickerLessonsGridInsideContainer:grid];
    }
}

- (void)rebuildPickerLessonsGridInsideContainer:(UIView *)gridContainer {
    // Render 20 lessons grid (4 cols x 5 rows)
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
        
        // Highlight current lesson in current book
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

- (void)pickerLessonSelected:(UIButton *)sender {
    self.currentBook = self.selectedBookForPicker;
    self.currentLesson = sender.tag;

    [self reloadLessonData];
    [self dismissLessonPicker];

#if __has_include("SupabaseClient.h")
    [[SupabaseClient sharedClient] saveProgressWithFeature:@"main"
                                                bookNumber:self.currentBook
                                              lessonNumber:self.currentLesson
                                                 wordIndex:-1
                                                completion:nil];
#endif
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

#pragma mark - Helper

- (NSString *)chineseNumberForBook:(NSInteger)book {
    if (book == 1) return @"一";
    if (book == 2) return @"二";
    if (book == 3) return @"三";
    return [NSString stringWithFormat:@"%ld", (long)book];
}

@end

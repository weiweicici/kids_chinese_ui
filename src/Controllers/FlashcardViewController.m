#import "FlashcardViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "TextbookManager.h"
#import "AudioManager.h"
#import "GifPlayerView.h"
#import "SquishyButton.h"

@interface FlashcardViewController () <AVAudioRecorderDelegate>

@property (strong, nonatomic) WordModel *wordModel;
@property (strong, nonatomic) UIView *cardView;
@property (strong, nonatomic) UILabel *pinyinLabel;
@property (strong, nonatomic) UILabel *charLabel;
@property (strong, nonatomic) GifPlayerView *gifPlayer;
@property (strong, nonatomic) UILabel *statusLabel;
@property (strong, nonatomic) SquishyButton *micButton;

@property (strong, nonatomic) AVAudioRecorder *recorder;
@property (strong, nonatomic) AVAudioPlayer *recordedPlayer;
@property (assign, nonatomic) BOOL isRecording;

// Game mode
@property (strong, nonatomic) UIView *footerView;
@property (strong, nonatomic) NSArray<WordModel *> *lessonWords;
@property (strong, nonatomic) NSArray<NSNumber *> *shuffledIndices;
@property (strong, nonatomic) NSTimer *advanceTimer;
@property (assign, nonatomic) NSInteger currentPlayIndex;

@end

@implementation FlashcardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isRecording = NO;
    
    [self setupStaticUI];
    [self reloadWordData];
    
    if (self.isGameMode) {
        [self setupGameModeUI];
    } else {
        [self requestMicrophonePermission];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.gifPlayer stop];
    [[AudioManager sharedManager] stopCurrentSound];
    
    if (self.isGameMode) {
        [self.advanceTimer invalidate];
        self.advanceTimer = nil;
    }
    
    [self.recorder stop];
    self.recorder.delegate = nil;
    self.recorder = nil;
    
    [self.recordedPlayer stop];
    self.recordedPlayer.delegate = nil;
    self.recordedPlayer = nil;
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
    
    // 2. Giant Card (centered frame: x=134, y=242, size 500x500)
    self.cardView = [[UIView alloc] initWithFrame:CGRectMake(134.0f, 242.0f, 500.0f, 500.0f)];
    self.cardView.backgroundColor = [self surfaceContainerLowestColor];
    self.cardView.layer.cornerRadius = 40.0f;
    self.cardView.layer.shadowColor = [self primaryColor].CGColor;
    self.cardView.layer.shadowOpacity = 0.08f;
    self.cardView.layer.shadowRadius = 15.0f;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 10.0f);
    [self.canvasView addSubview:self.cardView];
    
    // Pinyin text at top of giant card
    self.pinyinLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 30.0f, 460.0f, 40.0f)];
    self.pinyinLabel.textAlignment = NSTextAlignmentCenter;
    self.pinyinLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:28.0f];
    self.pinyinLabel.textColor = [self onSurfaceVariantColor];
    [self.cardView addSubview:self.pinyinLabel];
    
    // Giant Character Label (center)
    self.charLabel = [[UILabel alloc] initWithFrame:CGRectMake(50.0f, 80.0f, 400.0f, 320.0f)];
    self.charLabel.textAlignment = NSTextAlignmentCenter;
    self.charLabel.font = [self fontWithName:@"Noto Serif" size:240.0f];
    self.charLabel.textColor = [self onSurfaceColor];
    self.charLabel.adjustsFontSizeToFitWidth = YES;
    [self.cardView addSubview:self.charLabel];
    
    // Stroke GIF view overlay (same bounds, initially hidden)
    self.gifPlayer = [[GifPlayerView alloc] initWithFrame:CGRectMake(100.0f, 100.0f, 300.0f, 300.0f)];
    self.gifPlayer.hidden = YES;
    [self.cardView addSubview:self.gifPlayer];
    
    // Status text at card bottom
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 430.0f, 460.0f, 30.0f)];
    self.statusLabel.text = @"按住录音，松开结束";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:18.0f];
    self.statusLabel.textColor = [self onSurfaceVariantColor];
    [self.cardView addSubview:self.statusLabel];
    
    // 3. Audio Control Mic Button (x=324, y=682, size 120x120)
    self.micButton = [[SquishyButton alloc] initWithFrame:CGRectMake(324.0f, 682.0f, 120.0f, 120.0f)
                                          backgroundColor:[self colorFromHex:@"#70cfc2"]
                                              shadowColor:[self primaryColor]
                                             cornerRadius:60.0f];
    [self.micButton setTitle:@"🎙️" forState:UIControlStateNormal];
    self.micButton.titleLabel.font = [UIFont systemFontOfSize:54.0f];
    
    // Touch events for recording
    [self.micButton addTarget:self action:@selector(startRecording) forControlEvents:UIControlEventTouchDown];
    [self.micButton addTarget:self action:@selector(stopRecording) forControlEvents:UIControlEventTouchUpInside];
    [self.micButton addTarget:self action:@selector(stopRecording) forControlEvents:UIControlEventTouchUpOutside];
    
    [self.canvasView addSubview:self.micButton];
    
    // 4. Footer toolbar (frame: 0, 904, 768, 120)
    self.footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 904.0f, 768.0f, 120.0f)];
    self.footerView.backgroundColor = [self surfaceContainerColor];
    self.footerView.clipsToBounds = NO;
    self.footerView.layer.shadowColor = [self primaryColor].CGColor;
    self.footerView.layer.shadowOpacity = 0.08f;
    self.footerView.layer.shadowRadius = 8.0f;
    self.footerView.layer.shadowOffset = CGSizeMake(0, -4.0f);
    UIView *footerView = self.footerView;
    
    // Cross Button (left)
    SquishyButton *crossBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(146.0f, 28.0f, 64.0f, 64.0f)
                                                   backgroundColor:[self colorFromHex:@"#ffdad6"]
                                                       shadowColor:[self colorFromHex:@"#ba1a1a"]
                                                      cornerRadius:32.0f];
    [crossBtn setTitle:@"❌" forState:UIControlStateNormal];
    crossBtn.titleLabel.font = [UIFont systemFontOfSize:22.0f];
    [crossBtn addTarget:self action:@selector(wrongEvaluationClicked) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:crossBtn];
    
    // Compare Button (center)
    SquishyButton *compareBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(234.0f, 28.0f, 300.0f, 64.0f)
                                                     backgroundColor:[self primaryContainerColor]
                                                         shadowColor:[self primaryColor]
                                                        cornerRadius:16.0f];
    [compareBtn setTitle:@"🗣️ 比一比" forState:UIControlStateNormal];
    [compareBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    compareBtn.titleLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:20.0f];
    [compareBtn addTarget:self action:@selector(compareClicked) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:compareBtn];
    
    // Check Button (right)
    SquishyButton *checkBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(558.0f, 28.0f, 64.0f, 64.0f)
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
    // Return stroke animation view to standard state
    [self stopStrokeAnimation];
    
    self.wordModel = [[TextbookManager sharedManager] wordForBook:self.currentBook 
                                                          lesson:self.currentLesson 
                                                       wordIndex:self.selectedWordIndex];
    if (!self.wordModel) {
        NSLog(@"Error loading word book %ld lesson %ld idx %ld", 
              (long)self.currentBook, (long)self.currentLesson, (long)self.selectedWordIndex);
        return;
    }
    
    self.pinyinLabel.text = self.wordModel.pinyinWithTone;
    self.charLabel.text = self.wordModel.character;
    self.statusLabel.text = @"按住录音，松开结束";
    
    // Start playback of new character pronunciation
    [self playStandardAudio];
    [self playStrokeAnimation];
}

#pragma mark - Audio Playback

- (void)playStandardAudio {
    [[AudioManager sharedManager] playSoundNamed:[self.wordModel audioFileName]];
}

- (void)playStrokeAnimation {
    if ([self.wordModel hasStrokeGif]) {
        self.gifPlayer.hidden = NO;
        self.charLabel.hidden = YES;
        [self.gifPlayer playGifNamed:[self.wordModel strokeGifName]];
        
        // Auto stop after 5.0 seconds to save CPU cycles and RAM
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopStrokeAnimation) object:nil];
        [self performSelector:@selector(stopStrokeAnimation) withObject:nil afterDelay:5.0f];
    } else {
        self.gifPlayer.hidden = YES;
        self.charLabel.hidden = NO;
    }
}

- (void)stopStrokeAnimation {
    [self.gifPlayer stop];
    self.gifPlayer.hidden = YES;
    self.charLabel.hidden = NO;
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
    // 🔈 Manual play (left)
    SquishyButton *playBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(40.0f, 12.0f, 200.0f, 48.0f)
                                                  backgroundColor:[self colorFromHex:@"#70cfc2"]
                                                      shadowColor:[self primaryColor]
                                                     cornerRadius:24.0f];
    [playBtn setTitle:@"🔈 手动播放" forState:UIControlStateNormal];
    [playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    playBtn.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    [playBtn addTarget:self action:@selector(gameManualPlay) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:playBtn];

    // 🖌️ Replay stroke (right)
    SquishyButton *strokeBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(260.0f, 12.0f, 200.0f, 48.0f)
                                                    backgroundColor:[self primaryContainerColor]
                                                        shadowColor:[self primaryColor]
                                                       cornerRadius:24.0f];
    [strokeBtn setTitle:@"🖌️ 再播放笔画" forState:UIControlStateNormal];
    [strokeBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    strokeBtn.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    [strokeBtn addTarget:self action:@selector(gameReplayStroke) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:strokeBtn];

    // Difficulty selector (bottom row)
    // "易" label
    UILabel *easyLabel = [[UILabel alloc] initWithFrame:CGRectMake(180.0f, 72.0f, 30.0f, 36.0f)];
    easyLabel.text = @"易";
    easyLabel.font = [UIFont systemFontOfSize:20.0f];
    easyLabel.textColor = [self isShuffled] ? [self onSurfaceVariantColor] : [self primaryColor];
    easyLabel.textAlignment = NSTextAlignmentCenter;
    easyLabel.userInteractionEnabled = NO;
    easyLabel.tag = 201;
    [self.footerView addSubview:easyLabel];

    // 5 stars — purely visual UILabels (no gesture recognizers)
    // BUG 1 FIX: UILabel+UITapGestureRecognizer fails on iOS 9 when UIPanGestureRecognizers
    // exist on sibling views. Stars are visual-only; invisible UIButton overlays handle taps.
    for (NSInteger i = 1; i <= 5; i++) {
        UILabel *star = [[UILabel alloc] initWithFrame:CGRectMake(215.0f + (i - 1) * 32.0f, 72.0f, 30.0f, 36.0f)];
        star.tag = 300 + i;
        star.textAlignment = NSTextAlignmentCenter;
        star.font = [UIFont systemFontOfSize:22.0f];
        star.userInteractionEnabled = NO; // purely visual
        [self.footerView addSubview:star];
    }

    // "难" label
    UILabel *hardLabel = [[UILabel alloc] initWithFrame:CGRectMake(395.0f, 72.0f, 30.0f, 36.0f)];
    hardLabel.text = @"难";
    hardLabel.font = [UIFont systemFontOfSize:20.0f];
    hardLabel.textColor = [self isShuffled] ? [self primaryColor] : [self onSurfaceVariantColor];
    hardLabel.textAlignment = NSTextAlignmentCenter;
    hardLabel.userInteractionEnabled = NO;
    hardLabel.tag = 202;
    [self.footerView addSubview:hardLabel];

    // Invisible UIButton touch targets — reliable UIControlEventTouchUpInside on iOS 9
    UIButton *easyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    easyBtn.frame = CGRectMake(175.0f, 68.0f, 80.0f, 44.0f);
    easyBtn.backgroundColor = [UIColor clearColor];
    easyBtn.tag = 401;
    [easyBtn addTarget:self action:@selector(difficultyBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:easyBtn];

    UIButton *hardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    hardBtn.frame = CGRectMake(330.0f, 68.0f, 100.0f, 44.0f);
    hardBtn.backgroundColor = [UIColor clearColor];
    hardBtn.tag = 402;
    [hardBtn addTarget:self action:@selector(difficultyBtnTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.footerView addSubview:hardBtn];

    [self updateStarsDisplay];

    // Start auto-play
    [self startAutoPlay];
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
    [self.advanceTimer invalidate];
    self.advanceTimer = nil;

    WordModel *word = [self gameWordAtPlayIndex:self.currentPlayIndex];
    if (!word) return;

    // Display word
    self.wordModel = word;
    self.pinyinLabel.text = word.pinyinWithTone;
    self.charLabel.text = word.character;
    self.charLabel.hidden = NO;
    self.selectedWordIndex = [self actualWordIndex];

    // Play audio immediately
    [self playStandardAudio];

    // Play stroke GIF after 1.5s
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playStrokeAnimation) object:nil];
    [self performSelector:@selector(playStrokeAnimation) withObject:nil afterDelay:1.5f];

    // Advance to next word after 5s total
    self.advanceTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                         target:self
                                                       selector:@selector(advanceToNextWord)
                                                       userInfo:nil
                                                        repeats:NO];
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

- (void)gameManualPlay {
    [self.advanceTimer invalidate];
    self.advanceTimer = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playStrokeAnimation) object:nil];
    [self stopStrokeAnimation];
    [self startAutoPlay];
}

- (void)gameReplayStroke {
    [self.gifPlayer stop];
    self.gifPlayer.hidden = YES;
    self.charLabel.hidden = NO;

    WordModel *word = [self gameWordAtPlayIndex:self.currentPlayIndex];
    if (!word) return;

    [[AudioManager sharedManager] playSoundNamed:[word audioFileName]];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playStrokeAnimation) object:nil];
    [self performSelector:@selector(playStrokeAnimation) withObject:nil afterDelay:0.3f];
}

// BUG 1 FIX: UIButton target-action replaces UITapGestureRecognizer on UILabel.
- (void)difficultyBtnTapped:(UIButton *)sender {
    NSInteger tag = sender.tag; // 401 = easy, 402 = hard

    BOOL newShuffled = (tag == 402);
    if (newShuffled == self.isShuffled) return; // no change

    self.isShuffled = newShuffled;
    [self rebuildShuffledIndices];

    // Update labels
    UILabel *easyLabel = [self.footerView viewWithTag:201];
    UILabel *hardLabel = [self.footerView viewWithTag:202];
    easyLabel.textColor = self.isShuffled ? [self onSurfaceVariantColor] : [self primaryColor];
    hardLabel.textColor = self.isShuffled ? [self primaryColor] : [self onSurfaceVariantColor];

    [self updateStarsDisplay];

    // Restart game from word 1
    [self.advanceTimer invalidate];
    self.advanceTimer = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playStrokeAnimation) object:nil];
    [self stopStrokeAnimation];
    self.currentPlayIndex = 1;
    [self startAutoPlay];
}

- (void)updateStarsDisplay {
    for (NSInteger i = 1; i <= 5; i++) {
        UILabel *star = (UILabel *)[self.footerView viewWithTag:300 + i];
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

#pragma mark - Voice Recording (AVAudioRecorder)

- (void)requestMicrophonePermission {
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupAudioRecorder];
            });
        } else {
            NSLog(@"Microphone permission denied");
        }
    }];
}

- (void)setupAudioRecorder {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"child_recording.wav"];
    NSURL *url = [NSURL fileURLWithPath:path];
    
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(16000.0f),
        AVNumberOfChannelsKey: @(1),
        AVLinearPCMBitDepthKey: @(16),
        AVLinearPCMIsBigEndianKey: @(NO),
        AVLinearPCMIsFloatKey: @(NO)
    };
    
    NSError *error = nil;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:url settings:settings error:&error];
    if (error || !self.recorder) {
        NSLog(@"Error creating AVAudioRecorder: %@", error);
    }
    self.recorder.delegate = self;
    [self.recorder prepareToRecord];
}

- (void)startRecording {
    if (self.isRecording) return;
    
    // Stop standard player
    [[AudioManager sharedManager] stopCurrentSound];
    [self.recordedPlayer stop];
    self.recordedPlayer = nil;
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    if ([self.recorder record]) {
        self.isRecording = YES;
        self.statusLabel.text = @"🔴 正在录音中...";
        self.micButton.backgroundColor = [UIColor colorWithRed:235.0f/255.0f green:104.0f/255.0f blue:76.0f/255.0f alpha:1.0f]; // Red pulse color
    }
}

- (void)stopRecording {
    if (!self.isRecording) return;
    
    [self.recorder stop];
    self.isRecording = NO;
    self.statusLabel.text = @"✅ 录音保存成功！";
    self.micButton.backgroundColor = [self colorFromHex:@"#70cfc2"]; // Reset teal color
}

#pragma mark - Actions

- (void)startBtnClicked {
    if (self.isGameMode) {
        [self gameManualPlay];
        return;
    }
    [self playStandardAudio];
    [self playStrokeAnimation];
}

- (void)nextCardClicked {
    if (self.isGameMode) {
        [self.advanceTimer invalidate];
        self.advanceTimer = nil;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(playStrokeAnimation) object:nil];
        [self stopStrokeAnimation];
        if (self.currentPlayIndex < 16) {
            self.currentPlayIndex++;
            [self startAutoPlay];
        } else {
            [self gameComplete];
        }
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
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)compareClicked {
    [[AudioManager sharedManager] stopCurrentSound];
    [self.recordedPlayer stop];
    self.recordedPlayer = nil;
    
    // Play standard audio first
    [self playStandardAudio];
    self.statusLabel.text = @"🔊 播放标准发音...";
    
    // Play recorded child voice after standard audio completes
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"child_recording.wav"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            self.statusLabel.text = @"🔊 播放你的发音...";
            
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
            
            NSError *error = nil;
            self.recordedPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&error];
            if (!error && self.recordedPlayer) {
                [self.recordedPlayer play];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    self.statusLabel.text = @"按住录音，松开结束";
                });
            } else {
                NSLog(@"Error playing child recording: %@", error);
            }
        } else {
            self.statusLabel.text = @"⚠️ 没有发现你的录音，请按住麦克风说话";
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                self.statusLabel.text = @"按住录音，松开结束";
            });
        }
    });
}

- (void)wrongEvaluationClicked {
    // Show hud alert or auto-advance
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

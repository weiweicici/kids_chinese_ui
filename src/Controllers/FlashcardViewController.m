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

@end

@implementation FlashcardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isRecording = NO;
    
    [self setupStaticUI];
    [self reloadWordData];
    [self requestMicrophonePermission];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self.gifPlayer stop];
    [[AudioManager sharedManager] stopCurrentSound];
    
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
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 904.0f, 768.0f, 120.0f)];
    footerView.backgroundColor = [self surfaceContainerColor];
    footerView.layer.shadowColor = [self primaryColor].CGColor;
    footerView.layer.shadowOpacity = 0.08f;
    footerView.layer.shadowRadius = 8.0f;
    footerView.layer.shadowOffset = CGSizeMake(0, -4.0f);
    
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
    [self playStandardAudio];
    [self playStrokeAnimation];
}

- (void)nextCardClicked {
    if (self.selectedWordIndex < 16) {
        self.selectedWordIndex++;
        [self reloadWordData];
    } else {
        // Book chapter finished
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

#import "AudioManager.h"
#import <AVFoundation/AVFoundation.h>

@interface AudioManager () <AVAudioPlayerDelegate>
@property (strong, nonatomic) AVAudioPlayer *player;
@property (strong, nonatomic) NSMutableArray *retiredPlayers;
@property (assign, nonatomic) BOOL isLoading;
@property (copy, nonatomic) void (^completionBlock)(void);
@end

@implementation AudioManager

+ (instancetype)sharedManager {
    static AudioManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _retiredPlayers = [NSMutableArray array];
        // Pre-activate audio session so first play is instant
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
    }
    return self;
}

- (void)playSoundNamed:(NSString *)soundName {
    [self stopCurrentSound];

    NSString *path = [self pathForSoundFile:soundName];
    if (!path) {
        NSLog(@"Error: Sound file not found: %@", soundName);
        return;
    }

    self.isLoading = YES;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.isLoading) {
                return;
            }
            self.isLoading = NO;
            if (!data) {
                NSLog(@"Error: Could not load audio data for %@", soundName);
                return;
            }

            NSError *error = nil;
            AVAudioPlayer *newPlayer = [[AVAudioPlayer alloc] initWithData:data error:&error];
            if (error || !newPlayer) {
                NSLog(@"Error initializing AVAudioPlayer for %@: %@", soundName, error);
                return;
            }

            newPlayer.delegate = self;
            [newPlayer prepareToPlay];
            [newPlayer play];
            self.player = newPlayer;
        });
    });
}

- (void)playSoundNamed:(NSString *)soundName completion:(void (^)(void))completion {
    [self playSoundNamed:soundName];
    self.completionBlock = completion;
}

- (void)stopCurrentSound {
    self.isLoading = NO;
    self.completionBlock = nil;
    if (self.player) {
        AVAudioPlayer *oldPlayer = self.player;
        oldPlayer.delegate = nil;
        if (oldPlayer.isPlaying) {
            [oldPlayer stop];
        }
        self.player = nil;
        [self.retiredPlayers addObject:oldPlayer];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self.retiredPlayers removeObject:oldPlayer];
        });
    }
}

- (BOOL)isPlaying {
    return self.player && self.player.isPlaying;
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (player == self.player) {
        AVAudioPlayer *oldPlayer = self.player;
        oldPlayer.delegate = nil;
        self.player = nil;
        [self.retiredPlayers addObject:oldPlayer];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self.retiredPlayers removeObject:oldPlayer];
        });
        if (self.completionBlock) {
            self.completionBlock();
            self.completionBlock = nil;
        }
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    NSLog(@"Audio decode error: %@", error);
    if (player == self.player) {
        self.player.delegate = nil;
        self.player = nil;
    }
}

#pragma mark - Path Helper

- (NSString *)pathForSoundFile:(NSString *)soundName {
    NSString *baseName = [soundName stringByDeletingPathExtension];
    NSString *extension = [soundName pathExtension];
    if (extension.length == 0) {
        extension = @"mp3";
    }
    
    // 1. Try Bundle
    NSString *path = [[NSBundle mainBundle] pathForResource:baseName ofType:extension];
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // Try bundle ChineseWordmp3 directory
    path = [[NSBundle mainBundle] pathForResource:baseName ofType:extension inDirectory:@"ChineseWordmp3"];
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // 2. Try relative path (sandbox documents or working directory)
    path = [NSString stringWithFormat:@"ChineseWordmp3/%@", soundName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    return nil;
}

@end

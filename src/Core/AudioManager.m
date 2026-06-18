#import "AudioManager.h"
#import <AVFoundation/AVFoundation.h>

@interface AudioManager () <AVAudioPlayerDelegate>
@property (strong, nonatomic) AVAudioPlayer *player;
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

- (void)playSoundNamed:(NSString *)soundName {
    [self stopCurrentSound];
    
    NSString *path = [self pathForSoundFile:soundName];
    if (!path) {
        NSLog(@"Error: Sound file not found: %@", soundName);
        return;
    }
    
    NSURL *url = [NSURL fileURLWithPath:path];
    NSError *error = nil;
    
    // Set session category for native playback on speakers
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (error || !self.player) {
        NSLog(@"Error initializing AVAudioPlayer for file %@: %@", soundName, error);
        self.player = nil;
        return;
    }
    
    self.player.delegate = self;
    [self.player prepareToPlay];
    [self.player play];
}

- (void)stopCurrentSound {
    if (self.player) {
        if (self.player.isPlaying) {
            [self.player stop];
        }
        self.player.delegate = nil;
        self.player = nil; // Deallocate player immediately
    }
}

- (BOOL)isPlaying {
    return self.player && self.player.isPlaying;
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    // Release resources immediately upon completion of sound
    if (player == self.player) {
        self.player.delegate = nil;
        self.player = nil;
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
    
    // 2. Try absolute workspace path
    path = [NSString stringWithFormat:@"/Users/macmini/Downloads/kids_chinese_ui/ChineseWordmp3/%@", soundName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // 3. Try relative path
    path = [NSString stringWithFormat:@"ChineseWordmp3/%@", soundName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    return nil;
}

@end

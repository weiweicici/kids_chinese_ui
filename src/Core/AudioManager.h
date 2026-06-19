#import <Foundation/Foundation.h>

@interface AudioManager : NSObject

+ (instancetype)sharedManager;

// Play sound file by name (e.g. "1-1-1.mp3")
- (void)playSoundNamed:(NSString *)soundName;

// Play sound with completion block called when playback finishes
- (void)playSoundNamed:(NSString *)soundName completion:(void (^)(void))completion;

// Stop any currently playing audio and release resources
- (void)stopCurrentSound;

// Query if a sound is currently playing
- (BOOL)isPlaying;

@end

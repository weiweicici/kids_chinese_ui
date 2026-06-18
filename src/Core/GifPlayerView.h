#import <UIKit/UIKit.h>

@interface GifPlayerView : UIView

// Starts playback of a stroke order animation GIF by filename
- (void)playGifNamed:(NSString *)gifName;

// Stops playback, removes timers, and deallocates CGImageSource file handles
- (void)stop;

@end

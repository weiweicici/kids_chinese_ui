#import "GifPlayerView.h"
#import <ImageIO/ImageIO.h>

@interface GifPlayerView ()

@property (assign, nonatomic) CGImageSourceRef imageSource;
@property (assign, nonatomic) NSInteger frameCount;
@property (strong, nonatomic) NSMutableArray *frameDelaySum; // Cumulative prefix sum of frame durations
@property (readwrite, nonatomic) float totalDuration;
@property (assign, nonatomic) CFTimeInterval startTime;
@property (assign, nonatomic) NSInteger currentFrameIndex;

@property (strong, nonatomic) CADisplayLink *displayLink;

@end

@implementation GifPlayerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _currentFrameIndex = -1;
    }
    return self;
}

- (void)playGifNamed:(NSString *)gifName {
    [self stop];
    
    NSString *path = [self pathForGifFile:gifName];
    if (!path) {
        NSLog(@"Error: GIF file not found: %@", gifName);
        return;
    }
    
    NSURL *url = [NSURL fileURLWithPath:path];
    self.imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!self.imageSource) {
        NSLog(@"Error: Failed to create image source for GIF: %@", gifName);
        return;
    }
    
    self.frameCount = CGImageSourceGetCount(self.imageSource);
    self.frameDelaySum = [NSMutableArray arrayWithCapacity:self.frameCount];
    
    float accum = 0.0f;
    for (NSInteger i = 0; i < self.frameCount; i++) {
        float delay = [self delayTimeAtIndex:i];
        accum += delay;
        [self.frameDelaySum addObject:@(accum)];
    }
    self.totalDuration = accum;
    
    if (self.frameCount > 0 && self.totalDuration > 0) {
        self.startTime = CACurrentMediaTime();
        self.currentFrameIndex = -1;
        
        // Start rendering timer aligned with screen refresh
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkTick:)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}

- (void)stop {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
    
    if (self.imageSource) {
        CFRelease(self.imageSource);
        self.imageSource = NULL;
    }
    
    self.frameCount = 0;
    self.frameDelaySum = nil;
    self.currentFrameIndex = -1;
    self.layer.contents = nil;
}

- (float)delayTimeAtIndex:(NSInteger)index {
    float delay = 0.1f; // Default 100ms
    CFDictionaryRef dictRef = CGImageSourceCopyPropertiesAtIndex(self.imageSource, index, NULL);
    if (dictRef) {
        NSDictionary *properties = (__bridge NSDictionary *)dictRef;
        NSDictionary *gifProperties = properties[(NSString *)kCGImagePropertyGIFDictionary];
        if (gifProperties) {
            NSNumber *unclampedDelay = gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
            if (unclampedDelay && [unclampedDelay floatValue] > 0.0f) {
                delay = [unclampedDelay floatValue];
            } else {
                NSNumber *clampedDelay = gifProperties[(NSString *)kCGImagePropertyGIFDelayTime];
                if (clampedDelay && [clampedDelay floatValue] > 0.0f) {
                    delay = [clampedDelay floatValue];
                }
            }
        }
        CFRelease(dictRef);
    }
    return delay;
}

- (void)displayLinkTick:(CADisplayLink *)link {
    if (!self.imageSource || self.frameCount == 0) return;
    
    CFTimeInterval elapsed = CACurrentMediaTime() - self.startTime;
    float currentPlayTime = fmod(elapsed, self.totalDuration);
    
    NSInteger frameIndex = 0;
    for (NSInteger i = 0; i < self.frameCount; i++) {
        float delaySum = [self.frameDelaySum[i] floatValue];
        if (currentPlayTime <= delaySum) {
            frameIndex = i;
            break;
        }
    }
    
    // Only update and decode if frame index changed to save CPU cycles
    if (frameIndex != self.currentFrameIndex) {
        self.currentFrameIndex = frameIndex;
        
        // Decode frame ON-DEMAND, releasing immediately after assigning to backing layer
        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(self.imageSource, frameIndex, NULL);
        if (cgImage) {
            self.layer.contents = (__bridge id)cgImage;
            CGImageRelease(cgImage); // Free raw bitmap representation
        }
    }
}

- (void)dealloc {
    [self stop];
}

#pragma mark - Path Helper

- (NSString *)pathForGifFile:(NSString *)gifName {
    NSString *baseName = [gifName stringByDeletingPathExtension];
    
    // 1. Try Bundle
    NSString *path = [[NSBundle mainBundle] pathForResource:baseName ofType:@"gif"];
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // Try bundle ChineseWordmp3 directory
    path = [[NSBundle mainBundle] pathForResource:baseName ofType:@"gif" inDirectory:@"ChineseWordmp3"];
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // 2. Try absolute workspace path
    path = [NSString stringWithFormat:@"/Users/macmini/Downloads/kids_chinese_ui/ChineseWordmp3/%@", gifName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // 3. Try relative path
    path = [NSString stringWithFormat:@"ChineseWordmp3/%@", gifName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    return nil;
}

@end

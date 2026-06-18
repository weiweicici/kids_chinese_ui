#import "BaseViewController.h"
#import <mach/mach.h>

@interface BaseViewController ()

@end

@implementation BaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Set standard window background to dark grey to look nice when letterboxed
    self.view.backgroundColor = [UIColor colorWithWhite:0.08f alpha:1.0f];
    
    // Initialize standard canvas view fixed at design resolution
    self.canvasView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 1024.0f)];
    self.canvasView.backgroundColor = [self backgroundColor];
    self.canvasView.clipsToBounds = YES;
    [self.view addSubview:self.canvasView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self logMemoryFootprint:@"View Did Appear"];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CGRect bounds = self.view.bounds;
    CGFloat scaleX = bounds.size.width / 768.0f;
    CGFloat scaleY = bounds.size.height / 1024.0f;
    CGFloat scale = MIN(scaleX, scaleY);
    
    // Reset transform to get correct coordinates
    self.canvasView.transform = CGAffineTransformIdentity;
    self.canvasView.frame = CGRectMake(0, 0, 768.0f, 1024.0f);
    self.canvasView.center = CGPointMake(bounds.size.width / 2.0f, bounds.size.height / 2.0f);
    self.canvasView.transform = CGAffineTransformMakeScale(scale, scale);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self logMemoryFootprint:@"Memory Warning Received"];
    
    // Custom iOS 9 view unloading helper to save RAM
    if (self.isViewLoaded && self.view.window == nil) {
        self.canvasView = nil;
        self.view = nil;
    }
}

- (void)logMemoryFootprint:(NSString *)tag {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = MACH_TASK_BASIC_INFO_COUNT;
    kern_return_t kerr = task_info(mach_task_self(),
                                   MACH_TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if (kerr == KERN_SUCCESS) {
        CGFloat memoryInMB = (CGFloat)info.resident_size / (1024.0f * 1024.0f);
        NSLog(@"[Memory Diagnostics - %@ - %@]: Resident Size: %.2f MB", 
              NSStringFromClass([self class]), tag, memoryInMB);
    }
}

#pragma mark - Font Helper

- (UIFont *)fontWithName:(NSString *)fontName size:(CGFloat)size {
    UIFont *font = [UIFont fontWithName:fontName size:size];
    if (!font) {
        if ([fontName containsString:@"Noto Serif"]) {
            font = [UIFont fontWithName:@"Georgia" size:size];
        } else if ([fontName containsString:@"Plus Jakarta Sans"]) {
            font = [UIFont systemFontOfSize:size];
        } else {
            font = [UIFont systemFontOfSize:size];
        }
    }
    return font;
}

#pragma mark - Color Hex Parser

- (UIColor *)colorFromHex:(NSString *)hexString {
    unsigned int rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if ([hexString hasPrefix:@"#"]) {
        [scanner setScanLocation:1];
    }
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0
                           green:((float)((rgbValue & 0xFF00) >> 8))/255.0
                            blue:((float)(rgbValue & 0xFF))/255.0
                           alpha:1.0];
}

#pragma mark - Styling Methods (Jade Sprout)

- (UIColor *)primaryColor {
    return [self colorFromHex:@"#006b58"];
}

- (UIColor *)primaryContainerColor {
    return [self colorFromHex:@"#66c2aa"];
}

- (UIColor *)backgroundColor {
    return [self colorFromHex:@"#f4fbf8"];
}

- (UIColor *)onSurfaceColor {
    return [self colorFromHex:@"#161d1b"];
}

- (UIColor *)onSurfaceVariantColor {
    return [self colorFromHex:@"#3e4945"];
}

- (UIColor *)surfaceContainerColor {
    return [self colorFromHex:@"#e8efec"];
}

- (UIColor *)surfaceContainerLowestColor {
    return [self colorFromHex:@"#ffffff"];
}

- (UIColor *)secondaryContainerColor {
    return [self colorFromHex:@"#fc9d41"];
}

@end

#import <UIKit/UIKit.h>

@interface BaseViewController : UIViewController

// The 768x1024 design canvas. All subviews should be added to this canvasView.
@property (strong, nonatomic) UIView *canvasView;

// Helper to scale a font to fit the current layout scaling factor
- (UIFont *)fontWithName:(NSString *)fontName size:(CGFloat)size;

// Styling helpers
- (UIColor *)primaryColor;
- (UIColor *)primaryContainerColor;
- (UIColor *)backgroundColor;
- (UIColor *)onSurfaceColor;
- (UIColor *)onSurfaceVariantColor;
- (UIColor *)surfaceContainerColor;
- (UIColor *)surfaceContainerLowestColor;
- (UIColor *)secondaryContainerColor;
- (UIColor *)colorFromHex:(NSString *)hexString;

@end

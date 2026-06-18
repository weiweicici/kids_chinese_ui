#import <UIKit/UIKit.h>

@interface SquishyButton : UIButton

// Custom initializer with styling colors
- (instancetype)initWithFrame:(CGRect)frame 
              backgroundColor:(UIColor *)bgColor 
                  shadowColor:(UIColor *)shadowColor 
                 cornerRadius:(CGFloat)radius;

@end

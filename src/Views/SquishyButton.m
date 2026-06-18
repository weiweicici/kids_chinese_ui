#import "SquishyButton.h"

@interface SquishyButton ()
@property (strong, nonatomic) UIView *shadowView;
@property (strong, nonatomic) UIColor *normalBgColor;
@property (strong, nonatomic) UIColor *shadowBgColor;
@property (assign, nonatomic) BOOL isPressed;
@end

@implementation SquishyButton

- (instancetype)initWithFrame:(CGRect)frame 
              backgroundColor:(UIColor *)bgColor 
                  shadowColor:(UIColor *)shadowColor 
                 cornerRadius:(CGFloat)radius {
    self = [super initWithFrame:frame];
    if (self) {
        self.normalBgColor = bgColor;
        self.shadowBgColor = shadowColor;
        self.isPressed = NO;
        
        self.layer.cornerRadius = radius;
        self.layer.masksToBounds = YES;
        self.backgroundColor = bgColor;
        
        // Add a 4px high darker bottom shadow view inside the button
        _shadowView = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 4.0f, frame.size.width, 4.0f)];
        _shadowView.backgroundColor = shadowColor;
        _shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [self addSubview:_shadowView];
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    
    if (highlighted && !self.isPressed) {
        self.isPressed = YES;
        // Shift content down by 4px and hide shadow to simulate flattened 3D button
        [UIView animateWithDuration:0.05f animations:^{
            self.titleEdgeInsets = UIEdgeInsetsMake(4.0f, 0.0f, 0.0f, 0.0f);
            self.imageEdgeInsets = UIEdgeInsetsMake(4.0f, 0.0f, 0.0f, 0.0f);
            self.shadowView.alpha = 0.0f;
        }];
    } else if (!highlighted && self.isPressed) {
        self.isPressed = NO;
        // Restore contents to initial position
        [UIView animateWithDuration:0.05f animations:^{
            self.titleEdgeInsets = UIEdgeInsetsZero;
            self.imageEdgeInsets = UIEdgeInsetsZero;
            self.shadowView.alpha = 1.0f;
        }];
    }
}

@end

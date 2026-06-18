#import "RiceCellView.h"

@interface RiceCellView ()

@property (strong, nonatomic) UILabel *charLabel;

@end

@implementation RiceCellView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.borderWidth = 2.0f;
        self.layer.borderColor = [UIColor colorWithRed:165.0f/255.0f green:214.0f/255.0f blue:167.0f/255.0f alpha:1.0f].CGColor;
        self.layer.cornerRadius = 4.0f;

        self.layer.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.12f].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 2.0f);
        self.layer.shadowOpacity = 1.0f;
        self.layer.shadowRadius = 4.0f;

        self.charLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.bounds, 4, 4)];
        self.charLabel.textAlignment = NSTextAlignmentCenter;
        self.charLabel.font = [UIFont boldSystemFontOfSize:100.0f];
        self.charLabel.textColor = [UIColor darkTextColor];
        self.charLabel.numberOfLines = 1;
        self.charLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        self.charLabel.layer.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.25f].CGColor;
        self.charLabel.layer.shadowOffset = CGSizeMake(1.0f, 2.0f);
        self.charLabel.layer.shadowOpacity = 1.0f;
        self.charLabel.layer.shadowRadius = 1.0f;

        [self addSubview:self.charLabel];
    }
    return self;
}

- (void)setCharacter:(NSString *)character {
    self.charLabel.text = character;
}

- (void)setSelected:(BOOL)selected {
    _selected = selected;
    if (selected) {
        self.layer.borderColor = [UIColor colorWithRed:46.0f/255.0f green:125.0f/255.0f blue:50.0f/255.0f alpha:1.0f].CGColor;
    } else {
        self.layer.borderColor = [UIColor colorWithRed:165.0f/255.0f green:214.0f/255.0f blue:167.0f/255.0f alpha:1.0f].CGColor;
        // Cancel any pending background fade and reset immediately
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeBackgroundToWhite) object:nil];
        self.backgroundColor = [UIColor whiteColor];
    }
}

- (void)fadeBackgroundToWhite {
    [UIView animateWithDuration:0.3f animations:^{
        self.backgroundColor = [UIColor whiteColor];
    }];
}

#pragma mark - Touch

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.1f animations:^{
        self.transform = CGAffineTransformMakeScale(0.92f, 0.92f);
        self.layer.shadowOpacity = 0.5f;
        self.backgroundColor = [UIColor colorWithRed:165.0f/255.0f green:214.0f/255.0f blue:167.0f/255.0f alpha:1.0f];
    }];
    if (self.onTouchDown) {
        self.onTouchDown();
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.15f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = CGAffineTransformIdentity;
        self.layer.shadowOpacity = 1.0f;
    } completion:nil];
    self.selected = YES;
    [self performSelector:@selector(fadeBackgroundToWhite) withObject:nil afterDelay:0.5f];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [UIView animateWithDuration:0.15f animations:^{
        self.transform = CGAffineTransformIdentity;
        self.layer.shadowOpacity = 1.0f;
        self.backgroundColor = [UIColor whiteColor];
    }];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    CGFloat w = rect.size.width;
    CGFloat h = rect.size.height;
    CGFloat inset = 8.0f;

    UIColor *lineColor = [UIColor colorWithRed:255.0f/255.0f green:212.0f/255.0f blue:212.0f/255.0f alpha:1.0f];
    [lineColor setStroke];

    CGFloat lengths[] = {4.0f, 4.0f};
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineDash(ctx, 0, lengths, 2);
    CGContextSetLineWidth(ctx, 1.0f);

    CGPoint center = CGPointMake(w / 2, h / 2);

    CGContextMoveToPoint(ctx, inset, center.y);
    CGContextAddLineToPoint(ctx, w - inset, center.y);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, center.x, inset);
    CGContextAddLineToPoint(ctx, center.x, h - inset);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, inset, inset);
    CGContextAddLineToPoint(ctx, w - inset, h - inset);
    CGContextStrokePath(ctx);

    CGContextMoveToPoint(ctx, w - inset, inset);
    CGContextAddLineToPoint(ctx, inset, h - inset);
    CGContextStrokePath(ctx);
}

@end

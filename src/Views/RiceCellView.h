#import <UIKit/UIKit.h>

@interface RiceCellView : UIView

@property (copy, nonatomic) void (^onTouchDown)(void);
@property (assign, nonatomic, getter=isSelected) BOOL selected;

- (void)setCharacter:(NSString *)character;

@end

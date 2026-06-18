#import "AppNavigationController.h"

@interface AppNavigationController ()

@end

@implementation AppNavigationController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationBarHidden = YES;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

@end

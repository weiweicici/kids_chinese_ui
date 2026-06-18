#import "AppDelegate.h"
#import "AppNavigationController.h"
#import "MainScreenViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    MainScreenViewController *mainScreen = [[MainScreenViewController alloc] init];
    AppNavigationController *navController = [[AppNavigationController alloc] initWithRootViewController:mainScreen];
    
    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end

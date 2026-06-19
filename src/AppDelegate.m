#import "AppDelegate.h"
#import "AppNavigationController.h"
#import "HomeScreenViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    HomeScreenViewController *homeScreen = [[HomeScreenViewController alloc] init];
    AppNavigationController *navController = [[AppNavigationController alloc] initWithRootViewController:homeScreen];
    
    self.window.rootViewController = navController;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end

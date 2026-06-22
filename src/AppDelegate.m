#import "AppDelegate.h"
#import "AppNavigationController.h"
#import "HomeScreenViewController.h"
#import "LoginViewController.h"
#import "SupabaseClient.h"

static NSString *const kSupabaseURL = @"https://mwsapokofskjwaynnvas.supabase.co";
static NSString *const kSupabaseAnonKey = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13c2Fwb2tvZnNrandheW5udmFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwMDE4OTUsImV4cCI6MjA5NzU3Nzg5NX0.Cw6hXnPkw_hyC6BOxVRVqe2dWL7k8jcMAtHvmKkfesE";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    // Configure Supabase client
    [[SupabaseClient sharedClient] updateBaseURL:kSupabaseURL anonKey:kSupabaseAnonKey];

    // Check for existing token
    NSString *token = [[SupabaseClient sharedClient] getToken];
    if (token) {
        [self verifyTokenAndMount];
    } else {
        [self mountLogin];
    }

    return YES;
}

- (void)mountLogin {
    LoginViewController *loginVC = [[LoginViewController alloc] init];
    AppNavigationController *nav = [[AppNavigationController alloc] initWithRootViewController:loginVC];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
}

- (void)mountHome {
    HomeScreenViewController *home = [[HomeScreenViewController alloc] init];
    AppNavigationController *nav = [[AppNavigationController alloc] initWithRootViewController:home];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
}

- (void)verifyTokenAndMount {
    // Show home screen immediately (skeleton), then verify in background
    [self mountHome];

    // Background verify — if token expired, kick to login on next launch
    [[SupabaseClient sharedClient] GET:@"/rest/v1/profiles?select=id,role,is_approved"
                            completion:^(NSDictionary *resp, NSError *err) {
        if (err) {
            // Token likely expired — clear it; login page on next app start
            [[SupabaseClient sharedClient] clearToken];
            return;
        }
        NSArray *profiles = resp[@"data"];
        if (![profiles isKindOfClass:[NSArray class]] || profiles.count == 0) {
            [[SupabaseClient sharedClient] clearToken];
            return;
        }
        NSDictionary *profile = profiles.firstObject;
        NSString *role = profile[@"role"];
        if (role) {
            [[SupabaseClient sharedClient] saveRole:role];
        }
        NSNumber *approved = profile[@"is_approved"];
        if (![approved boolValue]) {
            [[SupabaseClient sharedClient] clearToken];
        }
    }];
}

@end

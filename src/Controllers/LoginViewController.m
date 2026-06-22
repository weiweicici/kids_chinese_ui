#import "LoginViewController.h"
#import "SupabaseClient.h"
#import "HomeScreenViewController.h"
#import "AppNavigationController.h"
#import "SquishyButton.h"

static NSString *const kSupabaseURL = @"https://mwsapokofskjwaynnvas.supabase.co";
static NSString *const kSupabaseAnonKey = @"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13c2Fwb2tvZnNrandheW5udmFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIwMDE4OTUsImV4cCI6MjA5NzU3Nzg5NX0.Cw6hXnPkw_hyC6BOxVRVqe2dWL7k8jcMAtHvmKkfesE";

@interface LoginViewController () <UITextFieldDelegate>

@property (assign, nonatomic) BOOL isRegisterMode;
@property (strong, nonatomic) UISegmentedControl *modeSeg;
@property (strong, nonatomic) UITextField *emailField;
@property (strong, nonatomic) UITextField *passwordField;
@property (strong, nonatomic) UITextField *usernameField;
@property (strong, nonatomic) SquishyButton *submitBtn;
@property (strong, nonatomic) UILabel *statusLabel;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;

@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.canvasView.backgroundColor = [self backgroundColor];
    self.isRegisterMode = NO;

    [self configureSupabase];
    [self buildUI];
}

- (void)configureSupabase {
    if (![[SupabaseClient sharedClient] isAvailable]) {
        [[SupabaseClient sharedClient] updateBaseURL:kSupabaseURL anonKey:kSupabaseAnonKey];
    }
}

- (void)buildUI {
    CGFloat cx = 384.0f;
    CGFloat topY = 120.0f;

    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, topY, 768.0f, 50.0f)];
    titleLabel.text = @"谷老师中文乐园";
    titleLabel.font = [UIFont boldSystemFontOfSize:36.0f];
    titleLabel.textColor = [self primaryColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.canvasView addSubview:titleLabel];

    // Card
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(134.0f, topY + 80.0f, 500.0f, 520.0f)];
    card.backgroundColor = [self surfaceContainerColor];
    card.layer.cornerRadius = 28.0f;
    card.layer.shadowColor = [self primaryColor].CGColor;
    card.layer.shadowOpacity = 0.06f;
    card.layer.shadowRadius = 10.0f;
    card.layer.shadowOffset = CGSizeMake(0, 6.0f);
    card.clipsToBounds = YES;
    [self.canvasView addSubview:card];

    CGFloat cy = 40.0f;

    // Segmented control
    self.modeSeg = [[UISegmentedControl alloc] initWithItems:@[@"登录", @"注册"]];
    self.modeSeg.frame = CGRectMake(80.0f, cy, 340.0f, 40.0f);
    self.modeSeg.selectedSegmentIndex = 0;
    self.modeSeg.tintColor = [self primaryColor];
    [self.modeSeg addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    [card addSubview:self.modeSeg];
    cy += 60.0f;

    // Username field (register only)
    self.usernameField = [[UITextField alloc] initWithFrame:CGRectMake(60.0f, cy, 380.0f, 48.0f)];
    self.usernameField.placeholder = @"用户名";
    self.usernameField.borderStyle = UITextBorderStyleRoundedRect;
    self.usernameField.delegate = self;
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.returnKeyType = UIReturnKeyNext;
    self.usernameField.hidden = YES;
    self.usernameField.alpha = 0.0f;
    [card addSubview:self.usernameField];
    // cy not advanced yet — shown/hidden by mode

    // Email field
    CGFloat emailY = cy;
    self.emailField = [[UITextField alloc] initWithFrame:CGRectMake(60.0f, emailY, 380.0f, 48.0f)];
    self.emailField.placeholder = @"邮箱";
    self.emailField.borderStyle = UITextBorderStyleRoundedRect;
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailField.delegate = self;
    self.emailField.returnKeyType = UIReturnKeyNext;
    [card addSubview:self.emailField];
    cy += 68.0f;

    // Password field
    self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(60.0f, cy, 380.0f, 48.0f)];
    self.passwordField.placeholder = @"密码";
    self.passwordField.borderStyle = UITextBorderStyleRoundedRect;
    self.passwordField.secureTextEntry = YES;
    self.passwordField.delegate = self;
    self.passwordField.returnKeyType = UIReturnKeyGo;
    [card addSubview:self.passwordField];
    cy += 68.0f;

    // Submit button
    self.submitBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(100.0f, cy, 300.0f, 56.0f)
                                          backgroundColor:[self primaryColor]
                                              shadowColor:[self colorFromHex:@"#004d3f"]
                                             cornerRadius:16.0f];
    [self.submitBtn setTitle:@"登录" forState:UIControlStateNormal];
    [self.submitBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.submitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20.0f];
    [self.submitBtn addTarget:self action:@selector(submitTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.submitBtn];
    cy += 76.0f;

    // Status label
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, cy, 420.0f, 50.0f)];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont systemFontOfSize:15.0f];
    self.statusLabel.textColor = [self onSurfaceVariantColor];
    self.statusLabel.numberOfLines = 2;
    [card addSubview:self.statusLabel];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(cx, topY + 370.0f);
    self.spinner.hidesWhenStopped = YES;
    [self.canvasView addSubview:self.spinner];
}

#pragma mark - Actions

- (void)modeChanged:(UISegmentedControl *)seg {
    self.isRegisterMode = (seg.selectedSegmentIndex == 1);
    [self.submitBtn setTitle:self.isRegisterMode ? @"注册" : @"登录" forState:UIControlStateNormal];
    self.statusLabel.text = @"";

    CGFloat cy = 40.0f + 60.0f; // after segmented control
    if (self.isRegisterMode) {
        self.usernameField.frame = CGRectMake(60.0f, cy, 380.0f, 48.0f);
        self.usernameField.hidden = NO;
        self.usernameField.alpha = 1.0f;
        cy += 68.0f;
    } else {
        self.usernameField.hidden = YES;
        self.usernameField.alpha = 0.0f;
    }
    self.emailField.frame = CGRectMake(60.0f, cy, 380.0f, 48.0f);
    cy += 68.0f;

    self.passwordField.frame = CGRectMake(60.0f, cy, 380.0f, 48.0f);
    cy += 68.0f;

    self.submitBtn.frame = CGRectMake(100.0f, cy, 300.0f, 56.0f);
    cy += 76.0f;

    self.statusLabel.frame = CGRectMake(40.0f, cy, 420.0f, 50.0f);
}

- (void)submitTapped {
    [self.view endEditing:YES];
    [self.spinner startAnimating];
    self.submitBtn.enabled = NO;

    NSString *email = [self.emailField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSString *password = self.passwordField.text;

    if (email.length == 0 || password.length == 0) {
        [self showStatus:@"请填写邮箱和密码" isError:YES];
        return;
    }

    if (self.isRegisterMode) {
        [self handleRegisterWithEmail:email password:password];
    } else {
        [self handleLoginWithEmail:email password:password];
    }
}

- (void)showStatus:(NSString *)msg isError:(BOOL)isError {
    [self.spinner stopAnimating];
    self.submitBtn.enabled = YES;
    self.statusLabel.text = msg;
    self.statusLabel.textColor = isError ? [UIColor redColor] : [self primaryColor];
}

#pragma mark - Register

- (void)handleRegisterWithEmail:(NSString *)email password:(NSString *)password {
    NSString *username = [self.usernameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (username.length == 0) {
        [self showStatus:@"请填写用户名" isError:YES];
        return;
    }

    // Pass username as user_metadata — Supabase trigger handle_new_user()
    // reads raw_user_meta_data->>'username' to auto-create profile + registration_requests
    [[SupabaseClient sharedClient] signUpWithEmail:email password:password username:username completion:^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showStatus:[NSString stringWithFormat:@"注册失败: %@",
                                  error.localizedDescription ?: @"未知错误"] isError:YES];
                return;
            }

            NSString *accessToken = response[@"access_token"];
            if (!accessToken) {
                // No access_token = email confirmation required
                [self showStatus:@"注册失败: Supabase 需关闭邮箱验证，请联系管理员在 Authentication → Providers → Email 中关闭 Confirm sign up" isError:YES];
                return;
            }

            // Save token so the user can log in (after teacher approves)
            [[SupabaseClient sharedClient] saveToken:accessToken];

            // Profile + registration_requests created automatically by database trigger.
            // No REST API calls needed.
            [self showStatus:@"注册成功！请等待老师审批后登录" isError:NO];
        });
    }];
}

#pragma mark - Login

- (void)handleLoginWithEmail:(NSString *)email password:(NSString *)password {
    [[SupabaseClient sharedClient] signInWithEmail:email password:password completion:^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showStatus:[NSString stringWithFormat:@"登录失败: %@",
                                  error.localizedDescription ?: @"邮箱或密码错误"] isError:YES];
                return;
            }
            NSString *accessToken = response[@"access_token"];
            if (!accessToken) {
                [self showStatus:@"登录失败: 无法获取令牌" isError:YES];
                return;
            }
            [[SupabaseClient sharedClient] saveToken:accessToken];
            [self fetchProfileAndProceedWithToken:accessToken];
        });
    }];
}

- (void)fetchProfileAndProceedWithToken:(NSString *)token {
    [[SupabaseClient sharedClient] useTemporaryToken:token];
    NSString *path = @"/rest/v1/profiles?select=*";
    NSLog(@"LoginVC: fetching profile with token prefix: %@...", [token substringToIndex:MIN(20, token.length)]);
    [[SupabaseClient sharedClient] GET:path completion:^(NSDictionary *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err) {
                // Can't verify profile — proceed anyway to HomeScreen
                NSLog(@"LoginVC: profile GET error — %@", err.localizedDescription);
                [self proceedToHome];
                return;
            }
            NSArray *profiles = resp[@"data"];
            NSLog(@"LoginVC: profiles count = %ld, response = %@", (long)profiles.count, resp);
            if (![profiles isKindOfClass:[NSArray class]] || profiles.count == 0) {
                // No profile found — registration incomplete or not yet created
                // (trigger may not be set up, or user hasn't been approved yet)
                [self showPendingApprovalAlert];
                return;
            }
            NSDictionary *profile = profiles.firstObject;
            NSString *role = profile[@"role"];
            NSNumber *approved = profile[@"is_approved"];
            NSLog(@"LoginVC: profile role=%@ approved=%@", role, approved);
            if (role) {
                [[SupabaseClient sharedClient] saveRole:role];
                NSLog(@"LoginVC: saved role '%@' to keychain", role);
            }
            if (![approved boolValue]) {
                [self showPendingApprovalAlert];
                return;
            }
            [self proceedToHome];
        });
    }];
}

- (void)showPendingApprovalAlert {
    [self.spinner stopAnimating];
    self.submitBtn.enabled = YES;
    [[SupabaseClient sharedClient] clearToken];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"账号待审批"
        message:@"您的账号尚未通过老师审批，请稍后再试" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)proceedToHome {
    [self.spinner stopAnimating];
    HomeScreenViewController *home = [[HomeScreenViewController alloc] init];
    AppNavigationController *nav = [[AppNavigationController alloc] initWithRootViewController:home];
    // Replace root VC
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    window.rootViewController = nav;
    [window makeKeyAndVisible];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.usernameField) {
        [self.emailField becomeFirstResponder];
    } else if (textField == self.emailField) {
        [self.passwordField becomeFirstResponder];
    } else if (textField == self.passwordField) {
        [self submitTapped];
    }
    return YES;
}

@end

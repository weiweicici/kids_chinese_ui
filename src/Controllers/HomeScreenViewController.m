#import "HomeScreenViewController.h"
#import "AppNavigationController.h"
#import "MainScreenViewController.h"
#import "PinyinMainViewController.h"
#import "AdminViewController.h"
#import "SupabaseClient.h"
#import "SquishyButton.h"

@interface HomeScreenViewController ()

@end

@implementation HomeScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Use the base class canvasView for unified responsive scaling
    self.canvasView.backgroundColor = [self backgroundColor];

    // 1. Title Banner Card
    UIView *titleCard = [[UIView alloc] initWithFrame:CGRectMake(124.0f, 100.0f, 520.0f, 130.0f)];
    titleCard.backgroundColor = [self surfaceContainerColor];
    titleCard.layer.cornerRadius = 24.0f;
    
    // Soft shadow for title
    titleCard.layer.shadowColor = [self primaryColor].CGColor;
    titleCard.layer.shadowOpacity = 0.08f;
    titleCard.layer.shadowRadius = 8.0f;
    titleCard.layer.shadowOffset = CGSizeMake(0, 4.0f);
    
    UILabel *mainTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 24.0f, 520.0f, 44.0f)];
    mainTitle.text = @"谷老师中文乐园";
    mainTitle.font = [UIFont boldSystemFontOfSize:32.0f];
    mainTitle.textColor = [self primaryColor];
    mainTitle.textAlignment = NSTextAlignmentCenter;
    [titleCard addSubview:mainTitle];
    
    UILabel *subTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 76.0f, 520.0f, 24.0f)];
    subTitle.text = @"—— 识字与拼音趣味学习 ——";
    subTitle.font = [self fontWithName:@"Plus Jakarta Sans" size:15.0f];
    subTitle.textColor = [self onSurfaceVariantColor];
    subTitle.textAlignment = NSTextAlignmentCenter;
    [titleCard addSubview:subTitle];
    
    [self.canvasView addSubview:titleCard];

    // 2. Character Recognition Card (识字乐园)
    SquishyButton *shiziBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(124.0f, 280.0f, 520.0f, 220.0f)
                                                   backgroundColor:[self surfaceContainerLowestColor]
                                                       shadowColor:[self primaryColor]
                                                      cornerRadius:28.0f];
    [shiziBtn addTarget:self action:@selector(shiziTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *shiziEmoji = [[UILabel alloc] initWithFrame:CGRectMake(0, 30.0f, 520.0f, 70.0f)];
    shiziEmoji.text = @"🐼";
    shiziEmoji.font = [UIFont systemFontOfSize:64.0f];
    shiziEmoji.textAlignment = NSTextAlignmentCenter;
    shiziEmoji.userInteractionEnabled = NO;
    [shiziBtn addSubview:shiziEmoji];
    
    UILabel *shiziTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 115.0f, 520.0f, 40.0f)];
    shiziTitle.text = @"识 字 乐 园";
    shiziTitle.font = [UIFont boldSystemFontOfSize:26.0f];
    shiziTitle.textColor = [self primaryColor];
    shiziTitle.textAlignment = NSTextAlignmentCenter;
    shiziTitle.userInteractionEnabled = NO;
    [shiziBtn addSubview:shiziTitle];
    
    UILabel *shiziDesc = [[UILabel alloc] initWithFrame:CGRectMake(0, 165.0f, 520.0f, 25.0f)];
    shiziDesc.text = @"认读汉字、笔画演示、拼字/跳字趣味游戏";
    shiziDesc.font = [self fontWithName:@"Plus Jakarta Sans" size:15.0f];
    shiziDesc.textColor = [self onSurfaceVariantColor];
    shiziDesc.textAlignment = NSTextAlignmentCenter;
    shiziDesc.userInteractionEnabled = NO;
    [shiziBtn addSubview:shiziDesc];
    
    [self.canvasView addSubview:shiziBtn];

    // 3. Pinyin Card (拼音闯关)
    SquishyButton *pinyinBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(124.0f, 550.0f, 520.0f, 220.0f)
                                                    backgroundColor:[self surfaceContainerLowestColor]
                                                        shadowColor:[self secondaryContainerColor]
                                                       cornerRadius:28.0f];
    [pinyinBtn addTarget:self action:@selector(pinyinTapped) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *pinyinEmoji = [[UILabel alloc] initWithFrame:CGRectMake(0, 30.0f, 520.0f, 70.0f)];
    pinyinEmoji.text = @"🎈";
    pinyinEmoji.font = [UIFont systemFontOfSize:64.0f];
    pinyinEmoji.textAlignment = NSTextAlignmentCenter;
    pinyinEmoji.userInteractionEnabled = NO;
    [pinyinBtn addSubview:pinyinEmoji];
    
    UILabel *pinyinTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 115.0f, 520.0f, 40.0f)];
    pinyinTitle.text = @"拼 音 闯 关";
    pinyinTitle.font = [UIFont boldSystemFontOfSize:26.0f];
    pinyinTitle.textColor = [self secondaryContainerColor];
    pinyinTitle.textAlignment = NSTextAlignmentCenter;
    pinyinTitle.userInteractionEnabled = NO;
    [pinyinBtn addSubview:pinyinTitle];
    
    UILabel *pinyinDesc = [[UILabel alloc] initWithFrame:CGRectMake(0, 165.0f, 520.0f, 25.0f)];
    pinyinDesc.text = @"声调认读与键盘拼写输入挑战";
    pinyinDesc.font = [self fontWithName:@"Plus Jakarta Sans" size:15.0f];
    pinyinDesc.textColor = [self onSurfaceVariantColor];
    pinyinDesc.textAlignment = NSTextAlignmentCenter;
    pinyinDesc.userInteractionEnabled = NO;
    [pinyinBtn addSubview:pinyinDesc];
    
    [self.canvasView addSubview:pinyinBtn];

    // 4. Version Info
    UILabel *verLabel = [[UILabel alloc] initWithFrame:CGRectMake(124.0f, 880.0f, 520.0f, 30.0f)];
    verLabel.text = @"儿童中文学习乐园 v1.0";
    verLabel.font = [self fontWithName:@"Plus Jakarta Sans" size:14.0f];
    verLabel.textColor = [self onSurfaceVariantColor];
    verLabel.textAlignment = NSTextAlignmentCenter;
    [self.canvasView addSubview:verLabel];

    // 5. Admin button (only visible when role == admin)
    NSString *role = [[SupabaseClient sharedClient] getCachedRole];
    if ([role isEqualToString:@"admin"]) {
        SquishyButton *adminBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(640.0f, 30.0f, 100.0f, 40.0f)
                                                       backgroundColor:[self secondaryContainerColor]
                                                           shadowColor:[self colorFromHex:@"#d47d1a"]
                                                          cornerRadius:12.0f];
        [adminBtn setTitle:@"管理" forState:UIControlStateNormal];
        [adminBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        adminBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        [adminBtn addTarget:self action:@selector(adminTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.canvasView addSubview:adminBtn];
    }
}

- (void)shiziTapped {
    MainScreenViewController *vc = [[MainScreenViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)pinyinTapped {
    PinyinMainViewController *vc = [[PinyinMainViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)adminTapped {
    AdminViewController *vc = [[AdminViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

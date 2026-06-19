#import "HomeScreenViewController.h"
#import "AppNavigationController.h"
#import "MainScreenViewController.h"
#import "PinyinMainViewController.h"

@interface HomeScreenViewController ()

@end

@implementation HomeScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:246.0f/255.0f green:249.0f/255.0f blue:244.0f/255.0f alpha:1.0f];

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768, 1024)];
    container.backgroundColor = [UIColor clearColor];
    [self.view addSubview:container];

    // 识字 button
    UIButton *shiziBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    shiziBtn.frame = CGRectMake(184, 240, 400, 260);
    shiziBtn.backgroundColor = [UIColor colorWithRed:200.0f/255.0f green:230.0f/255.0f blue:200.0f/255.0f alpha:1.0f];
    shiziBtn.layer.cornerRadius = 24;
    [shiziBtn setTitle:@"📖 谷老师 识字" forState:UIControlStateNormal];
    [shiziBtn setTitleColor:[UIColor colorWithRed:30.0f/255.0f green:50.0f/255.0f blue:40.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
    shiziBtn.titleLabel.font = [UIFont fontWithName:@"Georgia" size:36];
    shiziBtn.titleLabel.numberOfLines = 0;
    shiziBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [shiziBtn addTarget:self action:@selector(shiziTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:shiziBtn];

    // Separator
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(284, 530, 200, 1)];
    sep.backgroundColor = [UIColor colorWithWhite:0.7 alpha:0.4];
    [container addSubview:sep];

    // Pinyin button
    UIButton *pinyinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    pinyinBtn.frame = CGRectMake(184, 560, 400, 260);
    pinyinBtn.backgroundColor = [UIColor colorWithRed:230.0f/255.0f green:220.0f/255.0f blue:250.0f/255.0f alpha:1.0f];
    pinyinBtn.layer.cornerRadius = 24;
    [pinyinBtn setTitle:@"🔤 谷老师 Pinyin" forState:UIControlStateNormal];
    [pinyinBtn setTitleColor:[UIColor colorWithRed:30.0f/255.0f green:50.0f/255.0f blue:40.0f/255.0f alpha:1.0f] forState:UIControlStateNormal];
    pinyinBtn.titleLabel.font = [UIFont fontWithName:@"Georgia" size:36];
    pinyinBtn.titleLabel.numberOfLines = 0;
    pinyinBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [pinyinBtn addTarget:self action:@selector(pinyinTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:pinyinBtn];

    // Version
    UILabel *verLabel = [[UILabel alloc] initWithFrame:CGRectMake(284, 880, 200, 30)];
    verLabel.text = @"v1.0";
    verLabel.textAlignment = NSTextAlignmentCenter;
    verLabel.font = [UIFont systemFontOfSize:14];
    verLabel.textColor = [UIColor lightGrayColor];
    [container addSubview:verLabel];
}

- (void)shiziTapped {
    MainScreenViewController *vc = [[MainScreenViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)pinyinTapped {
    PinyinMainViewController *vc = [[PinyinMainViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

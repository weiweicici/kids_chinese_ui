#import "AdminViewController.h"
#import "SupabaseClient.h"
#import "SquishyButton.h"
#import "AppNavigationController.h"
#import "HomeScreenViewController.h"

@interface AdminViewController () <UITableViewDelegate, UITableViewDataSource>

@property (strong, nonatomic) UISegmentedControl *segControl;
@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;
@property (strong, nonatomic) UILabel *emptyLabel;

// 审批 tab data
@property (strong, nonatomic) NSArray *pendingRequests;
@property (strong, nonatomic) NSDictionary *profilesMap;

// Current tab index
@property (assign, nonatomic) NSInteger currentTab;

@end

@implementation AdminViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.currentTab = 0;
    [self buildUI];
    [self loadTabData];
}

- (void)buildUI {
    self.canvasView.backgroundColor = [self backgroundColor];

    // Top bar
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 60.0f)];
    topBar.backgroundColor = [self primaryColor];
    [self.canvasView addSubview:topBar];

    // Back button
    SquishyButton *backBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(16.0f, 10.0f, 80.0f, 40.0f)
                                                  backgroundColor:[self primaryContainerColor]
                                                      shadowColor:[self colorFromHex:@"#004d3f"]
                                                     cornerRadius:12.0f];
    [backBtn setTitle:@"‹ 返回" forState:UIControlStateNormal];
    [backBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    [backBtn addTarget:self action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:backBtn];

    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 768.0f, 60.0f)];
    title.text = @"管理后台";
    title.font = [UIFont boldSystemFontOfSize:22.0f];
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    [topBar addSubview:title];

    // Refresh button
    SquishyButton *refreshBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(672.0f, 10.0f, 80.0f, 40.0f)
                                                     backgroundColor:[self primaryContainerColor]
                                                         shadowColor:[self colorFromHex:@"#004d3f"]
                                                        cornerRadius:12.0f];
    [refreshBtn setTitle:@"刷新" forState:UIControlStateNormal];
    [refreshBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    [refreshBtn addTarget:self action:@selector(loadTabData) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:refreshBtn];

    // Segmented control
    self.segControl = [[UISegmentedControl alloc] initWithItems:@[@"审批", @"进度", @"课程"]];
    self.segControl.frame = CGRectMake(184.0f, 80.0f, 400.0f, 40.0f);
    self.segControl.selectedSegmentIndex = 0;
    self.segControl.tintColor = [self primaryColor];
    [self.segControl addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    [self.canvasView addSubview:self.segControl];

    // Table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(40.0f, 140.0f, 688.0f, 840.0f)];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    [self.canvasView addSubview:self.tableView];

    // Spinner
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(384.0f, 512.0f);
    self.spinner.hidesWhenStopped = YES;
    [self.canvasView addSubview:self.spinner];

    // Empty label
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(40.0f, 400.0f, 688.0f, 60.0f)];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:18.0f];
    self.emptyLabel.textColor = [self onSurfaceVariantColor];
    self.emptyLabel.hidden = YES;
    [self.canvasView addSubview:self.emptyLabel];
}

#pragma mark - Actions

- (void)backTapped {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)tabChanged:(UISegmentedControl *)seg {
    self.currentTab = seg.selectedSegmentIndex;
    self.emptyLabel.hidden = YES;
    [self loadTabData];
}

- (void)loadTabData {
    [self.spinner startAnimating];
    self.pendingRequests = nil;
    self.profilesMap = nil;
    [self.tableView reloadData];

    if (self.currentTab == 0) {
        [self loadPendingApprovals];
    } else {
        [self.spinner stopAnimating];
        [self showPlaceholder];
    }
}

- (void)showPlaceholder {
    self.emptyLabel.hidden = NO;
    if (self.currentTab == 1) {
        self.emptyLabel.text = @"进度追踪功能开发中";
    } else if (self.currentTab == 2) {
        self.emptyLabel.text = @"课程管理功能开发中";
    }
}

#pragma mark - Approval Data

- (void)loadPendingApprovals {
    [[SupabaseClient sharedClient] GET:@"/rest/v1/registration_requests?status=eq.pending&order=created_at.asc"
                            completion:^(NSDictionary *resp, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self.spinner stopAnimating];
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = [NSString stringWithFormat:@"加载失败: %@", error.localizedDescription];
                return;
            }
            NSArray *data = resp[@"data"];
            if (![data isKindOfClass:[NSArray class]] || data.count == 0) {
                [self.spinner stopAnimating];
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = @"没有待审批的注册申请";
                return;
            }
            self.pendingRequests = data;
            [self fetchProfilesForPendingRequests];
        });
    }];
}

- (void)fetchProfilesForPendingRequests {
    NSMutableArray *userIds = [NSMutableArray array];
    for (NSDictionary *req in self.pendingRequests) {
        NSString *uid = req[@"user_id"];
        if (uid) [userIds addObject:uid];
    }

    if (userIds.count == 0) {
        [self.spinner stopAnimating];
        [self.tableView reloadData];
        return;
    }

    // Build comma-separated list for IN filter
    NSString *idList = [userIds componentsJoinedByString:@","];
    NSString *path = [NSString stringWithFormat:@"/rest/v1/profiles?id=in.(%@)", idList];

    [[SupabaseClient sharedClient] GET:path completion:^(NSDictionary *resp, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (error) {
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = [NSString stringWithFormat:@"加载用户资料失败: %@", error.localizedDescription];
                return;
            }
            NSArray *profiles = resp[@"data"];
            if ([profiles isKindOfClass:[NSArray class]]) {
                NSMutableDictionary *map = [NSMutableDictionary dictionary];
                for (NSDictionary *p in profiles) {
                    NSString *pid = p[@"id"];
                    if (pid) map[pid] = p;
                }
                self.profilesMap = map;
            }
            [self.tableView reloadData];
        });
    }];
}

#pragma mark - Approve / Reject

- (void)approveRequest:(NSString *)requestId userId:(NSString *)userId {
    [self.spinner startAnimating];

    // Update registration_requests status
    NSString *reqPath = [NSString stringWithFormat:@"/rest/v1/registration_requests?id=eq.%@", requestId];
    [[SupabaseClient sharedClient] PATCH:reqPath body:@{@"status": @"approved"}
                              completion:^(NSDictionary *resp, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                [self showAlert:@"审批失败" message:error.localizedDescription];
            });
            return;
        }
        // Update profile
        NSString *profPath = [NSString stringWithFormat:@"/rest/v1/profiles?id=eq.%@", userId];
        [[SupabaseClient sharedClient] PATCH:profPath body:@{@"is_approved": @YES, @"role": @"student"}
                                  completion:^(NSDictionary *resp2, NSError *error2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                if (error2) {
                    [self showAlert:@"审批失败" message:error2.localizedDescription];
                    return;
                }
                [self showAlert:@"审批成功" message:@"已批准该学生注册"];
                [self loadPendingApprovals];
            });
        }];
    }];
}

- (void)rejectRequest:(NSString *)requestId {
    NSString *path = [NSString stringWithFormat:@"/rest/v1/registration_requests?id=eq.%@", requestId];
    [[SupabaseClient sharedClient] PATCH:path body:@{@"status": @"rejected"}
                              completion:^(NSDictionary *resp, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showAlert:@"操作失败" message:error.localizedDescription];
                return;
            }
            [self showAlert:@"已拒绝" message:@"该注册申请已被拒绝"];
            [self loadPendingApprovals];
        });
    }];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (self.currentTab == 0) {
        return self.pendingRequests.count;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    return 80.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cellId = @"AdminCell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.backgroundColor = [self surfaceContainerLowestColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }

    // Remove old buttons
    for (UIView *v in cell.contentView.subviews) {
        if ([v isKindOfClass:[UIButton class]]) [v removeFromSuperview];
    }

    NSDictionary *req = self.pendingRequests[ip.row];
    NSString *userId = req[@"user_id"];
    NSDictionary *profile = self.profilesMap[userId];

    cell.textLabel.text = profile[@"display_name"] ?: profile[@"username"] ?: @"未知用户";
    cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    cell.textLabel.textColor = [self onSurfaceColor];

    NSString *dateStr = req[@"created_at"] ?: @"";
    if ([dateStr length] > 10) dateStr = [dateStr substringToIndex:10];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"注册于 %@", dateStr];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0f];
    cell.detailTextLabel.textColor = [self onSurfaceVariantColor];

    // Approve button
    UIButton *approveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    approveBtn.frame = CGRectMake(560.0f, 16.0f, 44.0f, 44.0f);
    approveBtn.backgroundColor = [UIColor colorWithRed:0.2f green:0.7f blue:0.3f alpha:1.0f];
    approveBtn.layer.cornerRadius = 22.0f;
    [approveBtn setTitle:@"✓" forState:UIControlStateNormal];
    [approveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    approveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22.0f];
    approveBtn.tag = ip.row;
    [approveBtn addTarget:self action:@selector(cellApproveTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:approveBtn];

    // Reject button
    UIButton *rejectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rejectBtn.frame = CGRectMake(620.0f, 16.0f, 44.0f, 44.0f);
    rejectBtn.backgroundColor = [UIColor colorWithRed:0.8f green:0.2f blue:0.2f alpha:1.0f];
    rejectBtn.layer.cornerRadius = 22.0f;
    [rejectBtn setTitle:@"✗" forState:UIControlStateNormal];
    [rejectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    rejectBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22.0f];
    rejectBtn.tag = ip.row;
    [rejectBtn addTarget:self action:@selector(cellRejectTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cell.contentView addSubview:rejectBtn];

    return cell;
}

- (void)cellApproveTapped:(UIButton *)sender {
    NSDictionary *req = self.pendingRequests[sender.tag];
    NSString *alertMsg = [NSString stringWithFormat:@"确定批准该学生的注册申请？"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认审批"
                                                                   message:alertMsg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"批准" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self approveRequest:req[@"id"] userId:req[@"user_id"]];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cellRejectTapped:(UIButton *)sender {
    NSDictionary *req = self.pendingRequests[sender.tag];
    NSString *alertMsg = [NSString stringWithFormat:@"确定拒绝该学生的注册申请？"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认拒绝"
                                                                   message:alertMsg
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"拒绝" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self rejectRequest:req[@"id"]];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

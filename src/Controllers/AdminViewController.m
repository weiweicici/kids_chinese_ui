#import "AdminViewController.h"
#import "SupabaseClient.h"
#import "SquishyButton.h"
#import "AppNavigationController.h"
#import "HomeScreenViewController.h"

@interface AdminViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>

@property (strong, nonatomic) UISegmentedControl *segControl;
@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;
@property (strong, nonatomic) UILabel *emptyLabel;
@property (assign, nonatomic) BOOL isAdmin;

// 审批 tab data
@property (strong, nonatomic) NSArray *pendingRequests;
@property (strong, nonatomic) NSDictionary *profilesMap;

// Current tab index
@property (assign, nonatomic) NSInteger currentTab;

// 进度 tab data
@property (strong, nonatomic) NSArray *progressRecords;
@property (strong, nonatomic) NSArray *filteredRecords; // For search filter/selection filter
@property (strong, nonatomic) NSString *searchQuery;

// Dropdown filter selections
@property (strong, nonatomic) NSArray *classesList;
@property (strong, nonatomic) NSString *selectedClass;      // e.g. @"一年级一班", or @"全部班级"
@property (strong, nonatomic) NSArray *studentsInSelectedClass;
@property (strong, nonatomic) NSString *selectedStudentId; // e.g. userId, or nil for @"全班同学"

// Left Side Dashboard widgets for Progress tab
@property (strong, nonatomic) UIView *leftDashboardView;
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) UILabel *topStudentsLabel;
@property (strong, nonatomic) UILabel *topWordsLabel;

// Dynamic filter buttons
@property (strong, nonatomic) SquishyButton *classSelectBtn;
@property (strong, nonatomic) SquishyButton *studentSelectBtn;

@end

@implementation AdminViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *role = [[SupabaseClient sharedClient] getCachedRole];
    self.isAdmin = [role isEqualToString:@"admin"];
    self.currentTab = self.isAdmin ? 0 : 1;
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
    if (self.isAdmin) {
        self.segControl = [[UISegmentedControl alloc] initWithItems:@[@"审批", @"进度", @"课程"]];
    } else {
        self.segControl = [[UISegmentedControl alloc] initWithItems:@[@"进度"]];
    }
    self.segControl.frame = CGRectMake(184.0f, 80.0f, 400.0f, 40.0f);
    self.segControl.selectedSegmentIndex = self.isAdmin ? self.currentTab : 0;
    self.segControl.tintColor = [self primaryColor];
    [self.segControl addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    [self.canvasView addSubview:self.segControl];

    // Dropdown Selection Buttons (Progress tab only, default hidden)
    self.classSelectBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(328.0f, 135.0f, 190.0f, 44.0f)
                                               backgroundColor:[self surfaceContainerColor]
                                                   shadowColor:[self onSurfaceVariantColor]
                                                  cornerRadius:12.0f];
    [self.classSelectBtn setTitle:@"班级: 全部 ▼" forState:UIControlStateNormal];
    [self.classSelectBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    self.classSelectBtn.titleLabel.font = [UIFont systemFontOfSize:14.0f];
    [self.classSelectBtn addTarget:self action:@selector(classSelectTapped) forControlEvents:UIControlEventTouchUpInside];
    self.classSelectBtn.hidden = YES;
    [self.canvasView addSubview:self.classSelectBtn];

    self.studentSelectBtn = [[SquishyButton alloc] initWithFrame:CGRectMake(538.0f, 135.0f, 190.0f, 44.0f)
                                                  backgroundColor:[self surfaceContainerColor]
                                                      shadowColor:[self onSurfaceVariantColor]
                                                     cornerRadius:12.0f];
    [self.studentSelectBtn setTitle:@"学生: 全班 ▼" forState:UIControlStateNormal];
    [self.studentSelectBtn setTitleColor:[self onSurfaceColor] forState:UIControlStateNormal];
    self.studentSelectBtn.titleLabel.font = [UIFont systemFontOfSize:14.0f];
    [self.studentSelectBtn addTarget:self action:@selector(studentSelectTapped) forControlEvents:UIControlEventTouchUpInside];
    self.studentSelectBtn.hidden = YES;
    [self.canvasView addSubview:self.studentSelectBtn];

    // Left Dashboard Panel (Progress tab only, default hidden)
    self.leftDashboardView = [[UIView alloc] initWithFrame:CGRectMake(40.0f, 135.0f, 268.0f, 845.0f)];
    self.leftDashboardView.backgroundColor = [self surfaceContainerColor];
    self.leftDashboardView.layer.cornerRadius = 20.0f;
    self.leftDashboardView.layer.borderColor = [self colorFromHex:@"#cccccc"].CGColor;
    self.leftDashboardView.layer.borderWidth = 1.0f;
    self.leftDashboardView.hidden = YES;
    [self.canvasView addSubview:self.leftDashboardView];

    // Left Dashboard Subviews
    UILabel *boardTitle = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 16.0f, 236.0f, 30.0f)];
    boardTitle.text = @"📊 班级学情诊断";
    boardTitle.font = [UIFont boldSystemFontOfSize:18.0f];
    boardTitle.textColor = [self primaryColor];
    [self.leftDashboardView addSubview:boardTitle];

    // Top 5 Diligent Students
    UILabel *stHeader = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 60.0f, 236.0f, 24.0f)];
    stHeader.text = @"⏱️ 勤奋榜 (在线时长Top 5)";
    stHeader.font = [UIFont boldSystemFontOfSize:14.0f];
    stHeader.textColor = [self primaryColor];
    [self.leftDashboardView addSubview:stHeader];

    self.topStudentsLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 88.0f, 236.0f, 140.0f)];
    self.topStudentsLabel.numberOfLines = 0;
    self.topStudentsLabel.font = [UIFont systemFontOfSize:13.0f];
    self.topStudentsLabel.textColor = [self onSurfaceColor];
    self.topStudentsLabel.text = @"暂无统计数据";
    [self.leftDashboardView addSubview:self.topStudentsLabel];

    // Top 10 Difficult Words
    UILabel *wdHeader = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 245.0f, 236.0f, 24.0f)];
    wdHeader.text = @"📈 班级错字榜 (盲区Top 10)";
    wdHeader.font = [UIFont boldSystemFontOfSize:14.0f];
    wdHeader.textColor = [self colorFromHex:@"#ba1a1a"]; // Red warning
    [self.leftDashboardView addSubview:wdHeader];

    self.topWordsLabel = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, 275.0f, 236.0f, 550.0f)];
    self.topWordsLabel.numberOfLines = 0;
    self.topWordsLabel.font = [UIFont systemFontOfSize:13.0f];
    self.topWordsLabel.textColor = [self onSurfaceColor];
    self.topWordsLabel.text = @"暂无统计数据";
    [self.leftDashboardView addSubview:self.topWordsLabel];

    // Table view (Default frame, will be adjusted in loadTabData)
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
    self.progressRecords = nil;
    self.filteredRecords = nil;
    self.profilesMap = nil;
    self.searchQuery = nil;
    self.selectedClass = nil;
    self.selectedStudentId = nil;
    [self.tableView reloadData];

    // Layout adjustments for different tabs
    if (self.currentTab == 1) {
        self.tableView.frame = CGRectMake(328.0f, 190.0f, 400.0f, 790.0f);
        self.leftDashboardView.hidden = NO;
        self.classSelectBtn.hidden = NO;
        self.studentSelectBtn.hidden = NO;
    } else {
        self.tableView.frame = CGRectMake(40.0f, 140.0f, 688.0f, 840.0f);
        self.leftDashboardView.hidden = YES;
        self.classSelectBtn.hidden = YES;
        self.studentSelectBtn.hidden = YES;
    }

    // Teachers can only access progress tab
    if (!self.isAdmin) {
        [self loadStudentProgress];
        return;
    }

    if (self.currentTab == 0) {
        [self loadPendingApprovals];
    } else if (self.currentTab == 1) {
        [self loadStudentProgress];
    } else {
        [self.spinner stopAnimating];
        [self showPlaceholder];
    }
}

- (void)showPlaceholder {
    self.emptyLabel.hidden = NO;
    if (self.currentTab == 2) {
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

#pragma mark - Student Progress Data

- (void)loadStudentProgress {
    [[SupabaseClient sharedClient] GET:@"/rest/v1/user_progress?select=*&order=updated_at.desc"
                            completion:^(NSDictionary *resp, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self.spinner stopAnimating];
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = [NSString stringWithFormat:@"加载进度失败: %@", error.localizedDescription];
                return;
            }
            NSArray *data = resp[@"data"];
            if (![data isKindOfClass:[NSArray class]] || data.count == 0) {
                [self.spinner stopAnimating];
                self.emptyLabel.hidden = NO;
                self.emptyLabel.text = @"暂无学生进度数据";
                return;
            }
            self.progressRecords = data;
            [self fetchProfilesForProgressRecords];
        });
    }];
}

- (void)fetchProfilesForProgressRecords {
    NSMutableArray *userIds = [NSMutableArray array];
    for (NSDictionary *rec in self.progressRecords) {
        NSString *uid = rec[@"user_id"];
        if (uid && ![userIds containsObject:uid]) [userIds addObject:uid];
    }

    if (userIds.count == 0) {
        [self.spinner stopAnimating];
        [self.tableView reloadData];
        return;
    }

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
                NSMutableDictionary *map = [NSMutableDictionary dictionaryWithDictionary:self.profilesMap ?: @{}];
                for (NSDictionary *p in profiles) {
                    NSString *pid = p[@"id"];
                    if (pid) map[pid] = p;
                }
                self.profilesMap = map;
            }
            [self updateStatisticsAndFilter];
        });
    }];
}

- (void)updateStatisticsAndFilter {
    // 1. Resolve Class List and Current Selected Class
    NSString *currentUserId = [[SupabaseClient sharedClient] currentUserIdFromToken];
    NSDictionary *currentUserProfile = self.profilesMap[currentUserId];
    NSString *myClass = currentUserProfile[@"class_name"] ?: @"一年级一班";
    
    NSMutableSet *classSet = [NSMutableSet set];
    for (NSDictionary *p in self.profilesMap.allValues) {
        NSString *cls = p[@"class_name"];
        if (cls && cls.length > 0) {
            [classSet addObject:cls];
        }
    }
    
    NSMutableArray *classes = [NSMutableArray arrayWithArray:[classSet allObjects]];
    [classes sortUsingSelector:@selector(localizedCompare:)];
    if (self.isAdmin) {
        [classes insertObject:@"全部班级" atIndex:0];
    }
    self.classesList = classes;
    
    if (!self.selectedClass) {
        self.selectedClass = self.isAdmin ? @"全部班级" : myClass;
    }
    
    [self.classSelectBtn setTitle:[NSString stringWithFormat:@"班级: %@ ▼", self.selectedClass] forState:UIControlStateNormal];
    self.classSelectBtn.enabled = self.isAdmin; // Only admin can switch classes
    
    // 2. Resolve Students In Selected Class
    NSMutableArray *classStudents = [NSMutableArray array];
    for (NSDictionary *p in self.profilesMap.allValues) {
        NSString *role = p[@"role"];
        // Only include students
        if ([role isEqualToString:@"student"] || !role) {
            NSString *cls = p[@"class_name"];
            if ([self.selectedClass isEqualToString:@"全部班级"] || [cls isEqualToString:self.selectedClass]) {
                [classStudents addObject:p];
            }
        }
    }
    [classStudents sortUsingComparator:^NSComparisonResult(NSDictionary *p1, NSDictionary *p2) {
        NSString *n1 = p1[@"display_name"] ?: p1[@"username"] ?: @"";
        NSString *n2 = p2[@"display_name"] ?: p2[@"username"] ?: @"";
        return [n1 localizedCompare:n2];
    }];
    self.studentsInSelectedClass = classStudents;
    
    // Validate Selected Student
    if (self.selectedStudentId) {
        BOOL found = NO;
        for (NSDictionary *p in self.studentsInSelectedClass) {
            if ([p[@"id"] isEqualToString:self.selectedStudentId]) {
                found = YES;
                [self.studentSelectBtn setTitle:[NSString stringWithFormat:@"学生: %@ ▼", p[@"display_name"] ?: p[@"username"]] forState:UIControlStateNormal];
                break;
            }
        }
        if (!found) {
            self.selectedStudentId = nil;
            [self.studentSelectBtn setTitle:@"学生: 全班同学 ▼" forState:UIControlStateNormal];
        }
    } else {
        [self.studentSelectBtn setTitle:@"学生: 全班同学 ▼" forState:UIControlStateNormal];
    }
    
    // 3. Compute Top 5 Diligent & Top 10 Difficult Words (Within active class filter)
    NSMutableDictionary *studentDurations = [NSMutableDictionary dictionary];
    NSCountedSet *wordErrCounts = [[NSCountedSet alloc] init];
    
    // Build set of user_ids in active class
    NSMutableSet *activeUserIds = [NSMutableSet set];
    for (NSDictionary *p in self.studentsInSelectedClass) {
        if (p[@"id"]) [activeUserIds addObject:p[@"id"]];
    }
    
    for (NSDictionary *rec in self.progressRecords) {
        NSString *uid = rec[@"user_id"];
        if (![activeUserIds containsObject:uid]) {
            continue; // Skip progress outside selected class
        }
        
        NSString *feature = rec[@"feature"];
        NSArray *telemetry = rec[@"telemetry_data"];
        if (![telemetry isKindOfClass:[NSArray class]]) continue;
        
        if ([feature isEqualToString:@"system"]) {
            // Accumulate durations
            double durationSecs = 0;
            for (NSDictionary *event in telemetry) {
                if ([event[@"error_type"] isEqualToString:@"duration"]) {
                    durationSecs += [event[@"wrong_input"] doubleValue];
                }
            }
            if (durationSecs > 0) {
                double total = [studentDurations[uid] doubleValue];
                studentDurations[uid] = @(total + durationSecs);
            }
        } else {
            // Accumulate word errors
            for (NSDictionary *event in telemetry) {
                NSString *word = event[@"target_word"];
                if (word && word.length > 0) {
                    [wordErrCounts addObject:word];
                }
            }
        }
    }
    
    // Render Top 5 Diligent Students
    NSArray *sortedUsers = [studentDurations.allKeys sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [studentDurations[obj2] compare:studentDurations[obj1]]; // Descending
    }];
    NSMutableString *studentsText = [NSMutableString string];
    NSInteger stLimit = MIN(5, sortedUsers.count);
    if (stLimit == 0) {
        [studentsText appendString:@"暂无在线时长记录"];
    } else {
        for (NSInteger i = 0; i < stLimit; i++) {
            NSString *uid = sortedUsers[i];
            NSDictionary *profile = self.profilesMap[uid];
            NSString *name = profile[@"display_name"] ?: profile[@"username"] ?: @"未知学生";
            double mins = [studentDurations[uid] doubleValue] / 60.0;
            if (mins >= 60.0) {
                [studentsText appendFormat:@"%ld. %@ (%.1f小时)\n", (long)(i + 1), name, mins / 60.0];
            } else {
                [studentsText appendFormat:@"%ld. %@ (%.0f分钟)\n", (long)(i + 1), name, mins];
            }
        }
    }
    self.topStudentsLabel.text = studentsText;
    
    // Render Top 10 Difficult Words
    NSArray *sortedWords = [[wordErrCounts allObjects] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSUInteger count1 = [wordErrCounts countForObject:obj1];
        NSUInteger count2 = [wordErrCounts countForObject:obj2];
        return [@(count2) compare:@(count1)]; // Descending
    }];
    NSMutableString *wordsText = [NSMutableString string];
    NSInteger wdLimit = MIN(10, sortedWords.count);
    if (wdLimit == 0) {
        [wordsText appendString:@"全班暂无错字盲区"];
    } else {
        for (NSInteger i = 0; i < wdLimit; i++) {
            NSString *word = sortedWords[i];
            NSUInteger count = [wordErrCounts countForObject:word];
            [wordsText appendFormat:@"%ld. 【%@】 错误: %lu次\n", (long)(i + 1), word, (unsigned long)count];
        }
    }
    self.topWordsLabel.text = wordsText;
    
    // 4. Perform selection filter
    NSMutableArray *filtered = [NSMutableArray array];
    for (NSDictionary *rec in self.progressRecords) {
        NSString *uid = rec[@"user_id"];
        NSString *feature = rec[@"feature"];
        
        // Hide session logs from raw table list to keep it focused on learning achievements
        if ([feature isEqualToString:@"system"]) {
            continue;
        }
        
        if (self.selectedStudentId) {
            // View single student
            if ([uid isEqualToString:self.selectedStudentId]) {
                [filtered addObject:rec];
            }
        } else {
            // View class students
            if ([activeUserIds containsObject:uid]) {
                [filtered addObject:rec];
            }
        }
    }
    self.filteredRecords = filtered;
    [self.tableView reloadData];
}

#pragma mark - Dropdown Action Handlers

- (void)classSelectTapped {
    if (self.classesList.count == 0) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"切换班级"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSString *cls in self.classesList) {
        [alert addAction:[UIAlertAction actionWithTitle:cls style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.selectedClass = cls;
            self.selectedStudentId = nil; // Clear student selection
            [self updateStatisticsAndFilter];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // Handle iPad popover compatibility
    alert.popoverPresentationController.sourceView = self.classSelectBtn;
    alert.popoverPresentationController.sourceRect = self.classSelectBtn.bounds;
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)studentSelectTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"选择学生"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"全班同学" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.selectedStudentId = nil;
        [self updateStatisticsAndFilter];
    }]];
    
    for (NSDictionary *p in self.studentsInSelectedClass) {
        NSString *name = p[@"display_name"] ?: p[@"username"] ?: @"未知学生";
        NSString *uid = p[@"id"];
        [alert addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.selectedStudentId = uid;
            [self updateStatisticsAndFilter];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // Handle iPad popover compatibility
    alert.popoverPresentationController.sourceView = self.studentSelectBtn;
    alert.popoverPresentationController.sourceRect = self.studentSelectBtn.bounds;
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Custom Action Handlers
// (Placeholder methods required by headers)
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {}

#pragma mark - Approve / Reject

- (void)approveRequest:(NSString *)requestId userId:(NSString *)userId className:(NSString *)className {
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
        // Update profile with approved state and class_name
        NSString *profPath = [NSString stringWithFormat:@"/rest/v1/profiles?id=eq.%@", userId];
        NSDictionary *body = @{
            @"is_approved": @YES,
            @"role": @"student",
            @"class_name": className ?: @"一年级一班"
        };
        [[SupabaseClient sharedClient] PATCH:profPath body:body
                                  completion:^(NSDictionary *resp2, NSError *error2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                if (error2) {
                    [self showAlert:@"审批失败" message:error2.localizedDescription];
                    return;
                }
                [self showAlert:@"审批成功" message:[NSString stringWithFormat:@"已批准该学生并分配至: %@", className ?: @"一年级一班"]];
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
    } else if (self.currentTab == 1) {
        return self.filteredRecords.count;
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
    cell.accessoryType = UITableViewCellAccessoryNone;

    if (self.currentTab == 0) {
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
    } else if (self.currentTab == 1) {
        NSDictionary *rec = self.filteredRecords[ip.row];
        NSString *userId = rec[@"user_id"];
        NSDictionary *profile = self.profilesMap[userId];

        cell.textLabel.text = profile[@"display_name"] ?: profile[@"username"] ?: @"未知学生";
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        cell.textLabel.textColor = [self onSurfaceColor];

        NSString *feature = rec[@"feature"];
        NSInteger book = [rec[@"book_number"] integerValue];
        NSInteger lesson = [rec[@"lesson_number"] integerValue];

        NSString *featureName = feature;
        if ([feature isEqualToString:@"main"]) featureName = @"认字主页";
        else if ([feature isEqualToString:@"game1"]) featureName = @"拼字(易)";
        else if ([feature isEqualToString:@"game1_easy"]) featureName = @"拼字(易)";
        else if ([feature isEqualToString:@"game1_hard"]) featureName = @"拼字(难)";
        else if ([feature isEqualToString:@"game2"]) featureName = @"跳字";
        else if ([feature isEqualToString:@"game3_easy"]) featureName = @"找字(易)";
        else if ([feature isEqualToString:@"game3_hard"]) featureName = @"找字(难)";
        else if ([feature isEqualToString:@"pinyin_easy"]) featureName = @"拼音(易)";
        else if ([feature isEqualToString:@"pinyin_hard"]) featureName = @"拼音(难)";
        else if ([feature isEqualToString:@"fullspell_easy"]) featureName = @"填音(易)";
        else if ([feature isEqualToString:@"fullspell_hard"]) featureName = @"填音(难)";
        else if ([feature isEqualToString:@"system"]) featureName = @"系统会话";

        NSArray *telemetry = rec[@"telemetry_data"];
        
        NSString *updatedAt = rec[@"updated_at"] ?: @"";
        if (updatedAt.length > 16) {
            updatedAt = [updatedAt substringWithRange:NSMakeRange(5, 11)];
            updatedAt = [updatedAt stringByReplacingOccurrencesOfString:@"T" withString:@" "];
        }

        if ([feature isEqualToString:@"system"]) {
            // 解析系统登录和在线时长事件
            NSString *lastLoginTime = @"暂无记录";
            NSString *lastDuration = @"-";
            if ([telemetry isKindOfClass:[NSArray class]]) {
                // 从后往前找最近的 login 和 duration
                for (NSInteger i = (long)telemetry.count - 1; i >= 0; i--) {
                    NSDictionary *event = telemetry[i];
                    NSString *errType = event[@"error_type"];
                    if ([errType isEqualToString:@"login"] && [lastLoginTime isEqualToString:@"暂无记录"]) {
                        long ts = [event[@"timestamp"] longValue];
                        NSDate *date = [NSDate dateWithTimeIntervalSince1970:ts];
                        NSDateFormatter *df = [[NSDateFormatter alloc] init];
                        [df setDateFormat:@"MM-dd HH:mm"];
                        lastLoginTime = [df stringFromDate:date];
                    }
                    if ([errType isEqualToString:@"duration"] && [lastDuration isEqualToString:@"-"]) {
                        lastDuration = [NSString stringWithFormat:@"%@秒", event[@"wrong_input"]];
                    }
                }
            }
            cell.detailTextLabel.text = [NSString stringWithFormat:@"系统会话 · 最近登录: %@ · 最近在线: %@",
                                         lastLoginTime, lastDuration];
        } else {
            NSInteger errCount = 0;
            if ([telemetry isKindOfClass:[NSArray class]]) {
                errCount = telemetry.count;
            }
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · 第%ld册 第%ld课 · 错题: %ld · %@",
                                         featureName, (long)book, (long)lesson, (long)errCount, updatedAt];
        }
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14.0f];
        cell.detailTextLabel.textColor = [self onSurfaceVariantColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (void)cellApproveTapped:(UIButton *)sender {
    NSDictionary *req = self.pendingRequests[sender.tag];
    NSString *requestId = req[@"id"];
    NSString *userId = req[@"user_id"];
    
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"批准注册 - 选择班级"
                                                                   message:@"请选择将该学生分配到哪个班级："
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    // Extract actual classes (skip "全部班级" placeholder)
    NSMutableArray *realClasses = [NSMutableArray array];
    for (NSString *cls in self.classesList) {
        if (![cls isEqualToString:@"全部班级"]) {
            [realClasses addObject:cls];
        }
    }
    
    // If no custom classes exist yet, provide default option
    if (realClasses.count == 0) {
        [realClasses addObject:@"一年级一班"];
    }
    
    for (NSString *cls in realClasses) {
        [sheet addAction:[UIAlertAction actionWithTitle:cls style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [self approveRequest:requestId userId:userId className:cls];
        }]];
    }
    
    // Add option to create a new class name
    [sheet addAction:[UIAlertAction actionWithTitle:@"[ 新开一个班级... ]" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        UIAlertController *inputAlert = [UIAlertController alertControllerWithTitle:@"创建新班级"
                                                                            message:@"请输入新班级的名字（如：一年级三班）"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [inputAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"新班级名字";
        }];
        [inputAlert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [inputAlert addAction:[UIAlertAction actionWithTitle:@"确认创建并分配" style:UIAlertActionStyleDefault handler:^(UIAlertAction *subAction) {
            UITextField *field = inputAlert.textFields.firstObject;
            NSString *newClass = [field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (newClass.length == 0) {
                newClass = @"一年级一班";
            }
            [self approveRequest:requestId userId:userId className:newClass];
        }]];
        [self presentViewController:inputAlert animated:YES completion:nil];
    }]];
    
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // Safeguard iPad popover presentation anchors
    sheet.popoverPresentationController.sourceView = sender;
    sheet.popoverPresentationController.sourceRect = sender.bounds;
    
    [self presentViewController:sheet animated:YES completion:nil];
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

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (self.currentTab != 1) return;

    NSDictionary *rec = self.filteredRecords[ip.row];
    NSArray *telemetry = rec[@"telemetry_data"];
    if (![telemetry isKindOfClass:[NSArray class]] || telemetry.count == 0) {
        [self showAlert:@"无相关记录" message:@"该学生目前没有相关的记录！"];
        return;
    }

    NSString *userId = rec[@"user_id"];
    NSDictionary *profile = self.profilesMap[userId];
    NSString *studentName = profile[@"display_name"] ?: profile[@"username"] ?: @"该学生";
    NSString *feature = rec[@"feature"];

    if ([feature isEqualToString:@"system"]) {
        NSMutableString *details = [NSMutableString string];
        [details appendString:@"最近 10 次系统登录与在线时长：\n\n"];
        
        NSInteger count = 0;
        for (NSInteger i = (long)telemetry.count - 1; i >= 0 && count < 10; i--) {
            NSDictionary *event = telemetry[i];
            NSString *errType = event[@"error_type"];
            long ts = [event[@"timestamp"] longValue];
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:ts];
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSString *timeStr = [df stringFromDate:date];
            
            if ([errType isEqualToString:@"login"]) {
                [details appendFormat:@"%ld. 【登录】 时间: %@\n", (long)(count + 1), timeStr];
                count++;
            } else if ([errType isEqualToString:@"duration"]) {
                [details appendFormat:@"%ld. 【在线】 时间: %@ 停留: %@秒\n", (long)(count + 1), timeStr, event[@"wrong_input"]];
                count++;
            }
        }
        if (telemetry.count > 10) {
            [details appendString:@"\n* （只显示最近 10 条）"];
        }
        [self showAlert:[NSString stringWithFormat:@"%@ 的在线时长详情", studentName] message:details];
    } else {
        NSMutableString *details = [NSMutableString string];
        [details appendFormat:@"最近 %ld 次错题记录：\n\n", (long)telemetry.count];

        NSInteger count = 0;
        for (NSInteger i = (long)telemetry.count - 1; i >= 0 && count < 10; i--, count++) {
            NSDictionary *event = telemetry[i];
            NSString *word = event[@"target_word"] ?: @"";
            NSString *wrongInput = event[@"wrong_input"] ?: @"";
            
            [details appendFormat:@"%ld. 目标字:【%@】 错填/点错:【%@】\n", (long)(count + 1), word, wrongInput];
        }

        if (telemetry.count > 10) {
            [details appendString:@"\n* （只显示最近 10 条）"];
        }

        [self showAlert:[NSString stringWithFormat:@"%@ 的错题详情", studentName] message:details];
    }
}

@end

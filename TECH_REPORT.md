# Kids Chinese UI — 技术报告

## 1. 项目概况

| 项目 | 值 |
|---|---|
| 目标设备 | iPad Mini 1 (armv7, 512MB RAM) |
| iOS 版本 | 9.3.5 (13G36) |
| 开发语言 | Objective-C (ARC) |
| 最低部署目标 | iOS 9.0 |
| 第三方库 | **无** — 全部纯 UIKit / CoreAnimation |
| 编译工具 | Xcode 13.4.1 (仅 armv7 工具链) |
| 部署方式 | `compile.py` → IPA → Sideloadly 侧载 |
| 内存占用 | ~13-15 MB resident |

> **核心约束**: 不能用 Swift, 不能用 iOS 10+ API, 不能用 CocoaPods/SPM。一切手写 NSURLSession。

---

## 2. 架构全景

```
main.m
  └─ AppDelegate.m
       └─ AppNavigationController.m (UINavigationController 子类, hidesNavigationBar=YES)
            ├─ HomeScreenViewController         ← rootVC
            │    ├─ "识字" → MainScreenViewController
            │    └─ "Pinyin" → PinyinMainViewController
            │
            ├─ MainScreenViewController         ← 识字主模块
            │    ├─ Tab1: 4×4 RiceCellView 网格 + 点击发声
            │    ├─ Tab2: FlashcardViewController (认读游戏)
            │    ├─ Tab3: Game1ViewController (拼字游戏)
            │    └─ Tab4: Game2ViewController (跳字游戏)
            │
            ├─ FlashcardViewController          ← 闪卡 + 认读游戏
            ├─ Game1ViewController              ← 拼字 + 纸屑
            ├─ Game2ViewController              ← 跳字 10 气泡
            ├─ Game3ViewController              ← 找字 4×4
            │
            └─ PinyinMainViewController         ← 拼音模块 (最复杂, ~1870 行)
                 ├─ 4×4 汉字网格 + 拼音切换
                 ├─ 拼音游戏(易/难)              ← 听音打字
                 ├─ 全文拼写(易/难)              ← 自由填音 + 检查
                 └─ 拼写游戏                     ← 全屏闪卡循环
```

### 2.1 架构模式: Monolithic View Controller + State Flags

整个 App (尤其是 PinyinMain 模块) 采用的架构模式是 **Monolithic View Controller with State Flags**，不是 MVVM、VIPER 或 Clean Architecture。这是刻意为之的选择:

| 约束 | 决策 |
|---|---|
| 目标 iOS 9 + armv7 | 不能用 Swift、Combine、SwiftUI |
| 512MB RAM | 引入 Router、Presenter、ViewModel 等抽象层会增加内存和代码复杂度 |
| 零第三方库 | 手写架构层意味着要么自研框架，要么保持简单 |
| 原始遗留代码 | 项目最初就是纯 UIKit VC，重构为 MVVM 是重写而非改造 |

#### 具体实现方式

PinyinMainViewController 是一个约 1870 行的单文件 VC，通过**布尔状态标志**在三个游戏模式间切换:

```objc
// 状态标志 — 同时只能有一个活跃
@property BOOL gameActive;       // YES = 拼音游戏(易/难) 或 全文拼写(易/难)
@property BOOL fullSpell;         // YES = 全文拼写模式 (gameActive 的子模式)
@property BOOL spellingActive;    // YES = 拼写游戏 (独立互斥模式)
```

每个用户交互入口点检查这些标志，分发到对应逻辑:

```objc
- (void)cellTapped:(UITapGestureRecognizer *)sender {
    if (self.gameActive) {
        [self gameCellTapped:idx cell:cell];  // 游戏模式
    } else {
        [self playCellAudio];                 // 浏览模式
    }
}

- (void)backBtnClicked {
    if (self.spellingActive)  [self exitSpellingGame];
    else if (self.gameActive) [self exitGame];
    else                      [self.navigationController popViewControllerAnimated:YES];
}
```

三个模式各自的逻辑通过**方法名前缀**组织:

| 前缀 | 模式 | 示例 |
|---|---|---|
| `(无前缀)` + `fullSpell` 检查 | 全文拼写 | `fullSpellEvaluate`, `fullSpellRestartTapped` |
| `spelling*` | 拼写游戏 | `spellingSubmit`, `spellingNextCard`, `spellingReset` |
| 其余游戏方法 | 拼音游戏 | `playCurrentTargetAudio`, `submitPinyin`, `setupGameOrder` |

三个模式共享同一套视图层级 (gridCells / charLabels / pinyinLabels / underlineViews)，拼写游戏例外——它隐藏整个网格并用自定义全屏白卡片替换。

#### 这种模式的优缺点

**优点**:
- 零抽象层开销，内存占用极低 (13-15 MB)
- 状态全部集中，调试时只需看一个文件
- 方法之间可以自由共享私有变量 (无需 protocol/delegate)

**缺点**:
- 状态组合爆炸: 理论上同时可能出现的组合有 2³ = 8 种，当前用守卫提前 return 避免非法组合
- 代码长度: ~1870 行单文件不利于多人协作
- 新增模式需要增加新的状态标志和守卫逻辑

#### 与其他模块的关系

每个游戏 (Game1/Game2/Game3/Flashcard) 都是独立的 UIViewController，通过 `UINavigationController push` 进入，返回时通过 `popViewControllerAnimated`。没有 Router、没有 Coordinator。VC 之间不共享状态 (除了 singleton: TextbookManager / AudioManager)。

### 2.2 关键架构决策

- **所有 VC 继承 `BaseViewController`**: 提供 768×1024 设计画布 `canvasView`、自动缩放适配物理屏幕、颜色主题、字体回退。
- **不分 MVC 目录**: 原始项目结构, 文件和类名混放, 兼容 iOS 9 / MRC-free。
- **所有子视图添加到 `canvasView`** (不是 `self.view`), 由 `viewWillLayoutSubviews` 统一缩放。
- **AppNavigationController** 隐藏系统导航栏, 每个 VC 自己画 top bar。

---

## 3. 数据层 (`TextbookManager`)

### 3.1 数据源: plist 优先

```
ChineseWordmp3/
├── chapter.plist          ← 三册结构: [[session名], [session名], [session名]]
├── session_1-1.plist       ← 60个, 每课一个
├── session_1-2.plist
│   ...
├── review_*.plist          ← 15个复习课
├── 1-1-1.mp3               ← 逐字音频
├── 1-1.mp3                 ← 课文朗读
├── 1-1a.mp3                ← 跟读音频
├── 1_ch1.gif ~ 3_ch160.gif ← 笔画动画 (前10课)
```

**`session_{b}-{l}.plist` 格式**:
```xml
<dict>
  <key>words</key>
  <array>
    <dict>
      <key>labelText</key>  <string>大</string>
      <key>animation</key>  <string>1_ch1</string>  <!-- 可选 -->
      <key>sound</key>      <string>0_0</string>
    </dict>
    ...
  </array>
</dict>
```

**`chapter.plist` 格式**:
```xml
<array>
  <array>   <!-- 第一册: 25 个 session 名 -->
    <string>session_1-1</string>
    <string>session_1-2</string>
    ...
  </array>
  <array>   <!-- 第二册 -->
    <string>session_2-1</string>
    ...
  </array>
  <array>   <!-- 第三册 -->
    ...
  </array>
</array>
```

### 3.2 数据加载流程 (`TextbookManager.m`)

```
loadAllTextbooks
├─ 1. 遍历 book1.txt ~ book3.txt
│     提取每个字的 CSV 拼音 → 构建 pinyinLookup[char] = [pinyinWithTone, pinyinWithoutTone]
│
├─ 2. 读取 chapter.plist
│     遍历 session 名
│     ├─ 加载 ChineseWordmp3/{session}.plist → sessionDict
│     ├─ 遍历 words 数组
│     │    ├─ labelText + sound + animation
│     │    ├─ 从 pinyinLookup 按 character 匹配拼音
│     │    ├─ PinyinToneToMarks() C 函数: "han4" → "hàn"
│     │    └─ 生成 WordModel 对象
│     └─ 组装 LessonModel
│
├─ 3. 按 lessonNumber 排序
└─ 4. 存入 booksData[@(bookNumber)] = [LessonModel, ...]
```

### 3.3 关键警告

> **`Textbooks/book*.txt` (CSV) 仅作为拼音字典使用。字符顺序以 plist 为准。**
> CSV 由 AI 生成, 字符顺序与真实 plist 资料不匹配。已用户验证三册全部正确。

### 3.4 拼音声调转换

`PinyinToneToMarks()` (C 函数, `TextbookManager.m:8-56`):
- 输入: `"han4"` → 输出: `"hàn"`
- 规则: a/e 优先, ou→o, 否则最后一个元音
- 支持 ü (v)

---

## 4. Canvas UI 系统 (`BaseViewController`)

### 4.1 设计画布

所有 VC 使用 768×1024 固定坐标设计画布 `canvasView`:

```objc
self.canvasView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 768, 1024)];
```

`viewWillLayoutSubviews` 自动等比缩放适配物理屏幕:

```objc
CGFloat scale = MIN(screenWidth/768, screenHeight/1024);
self.canvasView.transform = CGAffineTransformMakeScale(scale, scale);
```

### 4.2 颜色主题 (Jade Sprout)

| 名称 | Hex | 用途 |
|---|---|---|
| `primaryColor` | `#006b58` | 深绿，强调色 |
| `primaryContainerColor` | `#66c2aa` | 浅绿，按钮背景 |
| `backgroundColor` | `#f4fbf8` | 页面背景 |
| `onSurfaceColor` | `#161d1b` | 文字色 |
| `onSurfaceVariantColor` | `#3e4945` | 次要文字/阴影 |
| `surfaceContainerColor` | `#e8efec` | 浅灰，容器背景 |
| `surfaceContainerLowestColor` | `#ffffff` | 白色 |
| `secondaryContainerColor` | `#fc9d41` | 橙色奖杯按钮 |

### 4.3 字体

`fontWithName:size:` 方法实现字体回退:
- "Noto Serif" → "Georgia"
- "Plus Jakarta Sans" → systemFont
- 其他 → systemFont

### 4.4 内存警告处理

`didReceiveMemoryWarning` 中**不再**置空 `canvasView` 或 `self.view`。因为这些 VC 的 `viewDidLoad` 是一次性设置, iOS 9 在收到内存警告后如果视图被卸载, 重新显示时不会自动重建子视图, 会导致白屏。

---

## 5. 导航流程

```
App 启动
  │
  └─ HomeScreenViewController
       ├── [识字] → MainScreenViewController (包含 Tab1~4)
       └── [Pinyin] → PinyinMainViewController
```

- **AppNavigationController**: 隐藏系统导航栏, 每个 VC 自己绘制 top bar。
- `backBtnClicked`: 检查 `gameActive` / `spellingActive`, 先退出游戏再 pop。
- **无 TabBarController**: "Tab" 通过底部一排按钮模拟 (MainScreen 的 4 个 tab, PinyinMain 的 5 个游戏入口)。

---

## 6. 各游戏模块详解

### 6.1 MainScreenViewController (识字主界面)

- **Tab1 (Browse)**: 4×4 RiceCellView 米字格网格, 点击汉字发声, 底部有"跟读"/"朗读"按钮播放整课音频。
- **Tab2 (闪卡/认读)**: 全屏 FlashcardViewController, 自动播放音频+笔画GIF+自动翻页, 难度选择。
- **Tab3 (拼字)**: Game1ViewController, 520×520 米字格+88×88卡片拖拽填空, 简易/困难模式。
- **Tab4 (跳字)**: Game2ViewController, 10 个掉落气泡 2-hit per word。
- **Bottom bar**: 4 个 tab 按钮 + 目录/菜单按钮。

`reloadLessonData`: 所有 VC 的统一数据刷新入口, 切换课后调用。

### 6.2 FlashcardViewController (闪卡/认读)

- 单张卡片显示汉字+拼音+pinyinWithTone
- 自动播放流程: 音频 → 笔画 GIF → 自动翻页
- 难度选择(★☆☆☆☆/★★★★★)
- 完成次数存 NSUserDefaults
- `viewDidDisappear:` 清理 recorder/recordedPlayer

### 6.3 Game1ViewController (拼字)

- 4×4 米字格 slots + 16 张可拖拽卡片
- 易: 顺序, 自动检查
- 难: 乱序, 手动检查
- 完成: CAEmitterLayer 纸屑 + nizhenbang.caf
- 难度选择器: UILabel + UITapGestureRecognizer (iOS 9 上 UIButton + clipsToBounds bug)

### 6.4 Game2ViewController (跳字)

- 10 个气泡从顶部掉落
- 每个字需要点击 2 次 (2-hit)
- 错误点击跟踪
- 仅可见气泡可作为目标

### 6.5 Game3ViewController (找字)

- 4×4 CharacterCell 网格 (inline drawRect)
- 顺序/随机模式
- 自动播放

---

## 7. PinyinMainViewController (核心模块详解)

这是最复杂的 VC (~1870 行), 采用 **Monolithic View Controller + State Flags** 模式 (详见 2.1), 包含 3 种游戏模式, 共享 4×4 汉字网格。

### 7.1 共享状态

```objc
// 网格
@property NSMutableArray *words;           // 16 个 WordModel
@property NSMutableArray *gridCells;       // 16 个 UIView 容器
@property NSMutableArray *charLabels;      // 16 个 UILabel (汉字)
@property NSMutableArray *pinyinLabels;    // 16 个 UILabel (拼音/用户输入)
@property NSMutableArray *underlineViews;  // 16 个 UIView (拼音下划线)

// 模式标记
@property BOOL gameActive;                  // 任何游戏进行中
@property BOOL gameModeEasy;                // 易/难
@property BOOL fullSpell;                   // YES = 全文拼写, NO = 拼音游戏
@property BOOL spellingActive;              // YES = 拼写游戏 (独立互斥)

// 游戏数据
@property NSMutableArray *remainingIndices; // 未完成的字索引
@property NSMutableArray *currentOrder;     // 音频播放顺序 (Fisher-Yates shuffle)
@property NSMutableArray *gridOrder;        // 汉字网格显示顺序 (难模式乱序)
@property NSMutableDictionary *charResults; // @(idx) → {result, input}
@property NSMutableDictionary *userInputs;  // @(idx) → 用户输入拼音
@property NSInteger correctCount;
@property NSInteger totalAttempts;
@property NSInteger gameStep;

// UI 元素
@property UIView *gameDimView;              // 白色半透明遮罩 (仅拼音游戏)
@property UIView *popupCard;                // 输入弹出卡 (拼音游戏 + FullSpell)
@property UIView *spellingCard;             // 拼写游戏卡片
```

### 7.2 网格布局

```
每个 cell: 192×198 pt, 从 y=110 开始, 4 列
├── charLabels[i]:       120pt bold, 居中
│   无拼音时: frame (0, 0, 192, 198)
│   有拼音时: frame (0, 16, 192, 182)
├── pinyinLabels[i]:     y=1, h=30, 28pt bold, hidden 默认
└── underlineViews[i]:   y=33, 1.5pt, hidden 默认
```

### 7.3 模式一: 拼音游戏(易/难)

**流程**:
1. `remainingIndices` 从 NSUserDefaults 恢复 (新游戏 = 0..15)
2. `setupGameOrder`: 对 `remainingIndices` 做 Fisher-Yates shuffle → `currentOrder`
3. `playCurrentTargetAudio`: 播 `currentOrder[gameStep]` 的音频
4. 用户点击网格字:
   - 点对(== currentTargetIdx 或之前答错的): 弹出输入卡片
   - 点错: `cuola.caf` + 红色闪烁 + 重播目标音频
5. 提交拼音:
   - 正确: 绿底 + nizhenbang.caf + `gameStep++`
   - 错误: 红底 + jixujiayou.caf
   - 2s 后 `closePopupAndContinue` → 播下一个音频
6. `remainingIndices` 全部完成 → `finishGame` → 纸屑 + 自动退出

**易 vs 难**: 仅 `gridOrder` 不同。易 = `[0,1,2,...,15]`, 难 = shuffled。

### 7.4 模式二: 全文拼写 (FullSpell)

**流程**:
1. 无音频, 无 `gameDimView`
2. 用户自由点击任意未完成字 → 弹出输入卡
3. 提交: 保存到 `userInputs`, 显示在 `pinyinLabels[i]`
4. 16 字全部填完 或 点「✅ 检查」→ `fullSpellEvaluate`
5. 检查: 逐字对比 `userInputs` vs `pinyinWithoutTone`
   - 正确: "撕日历" shrink-fade 动画, 字消失 + 下划线隐藏
   - 错误: 清空输入, 留格子, 用户可再次点击修改
6. 重复修正直到 `remainingIndices.count == 0`

**NSUserDefaults**: `fullspell_progress_b{book}_l{lesson}_{easy|hard}`

### 7.5 模式三: 拼写游戏 (SpellingGame)

**特点**:
- 独立模式 (`spellingActive`), 与 `gameActive` 互斥
- 全屏新窗口效果: 隐藏 topNavBar / footerView / gridCells, 只显示自定义 spellingTopBar
- 白卡片 700×540, 汉字 200pt bold
- 输入拼音 → Return 提交
- 正确: 绿底 + nizhenbang.caf + 1s → 滑动切换到下一字 (slide-out-bottom / slide-in-top)
- 错误: 红底 + jixujiayou.caf + 1s → 停留在当前字直到答对
- 16 字循环, 不计数, 不保存 NSUserDefaults
- 顶部栏: 📖拼写游戏 | 📚目录 | 🔄重置 | ▶️开始 | ◀️返回

**架构说明**: 拼写游戏与 PinyinMain 其他模式共享同一个 VC, 但通过 `spellingActive` 标志实现完全隔离。进入时隐藏所有正常 UI 元素并创建独立的 spellingTopBar / spellingCard / spellingInput。退出时恢复原 UI。这种"全屏接管"模式避免了新增 VC、navigation stack 管理、或复杂的 present/dismiss 流程。

### 7.6 输入卡片 (Popup)

所有游戏共享同一 popupCard:

```
620×520, y=80, white alpha 0.92, cornerRadius 24
├── [确认] [返回] 按钮 (y=16)
├── resultBar (y=75, h=85, 初始透明, 正确绿/错误红)
├── UITextField (y=90, 28pt, ASCII only, ü 允许)
├── 下划线 (y=150)
└── 汉字 (y=230, 150pt bold)
```

键盘: `UIKeyboardTypeASCIICapable` + `shouldChangeCharactersInRange` 过滤非 ASCII 字符 (仅允许 ü)。

### 7.7 NSUserDefaults 进度保存

```objc
Key 格式: "{prefix}_progress_b{book}_l{lesson}_{easy|hard}"
prefix = "pinyin"  (拼音游戏)
       = "fullspell" (全文拼写)

保存内容:
{
  correct: NSInteger,
  totalAttempts: NSInteger,
  remaining: NSArray<NSNumber>,   // 未完成索引
  results: NSDictionary<NSString, NSDictionary>,  // key 为 stringValue of NSNumber
  userInputs: NSDictionary        // 仅 fullSpell
}
```

> **注意**: `charResults` 的 key 是 `@(idx)` (NSNumber), 但 NSUserDefaults plist 只支持 NSString key。`saveGameProgress` 中做了 `[key stringValue]` 转换。

---

## 8. 音频系统 (`AudioManager`)

### 8.1 API

```objc
+ (instancetype)sharedManager;
- (void)playSoundNamed:(NSString *)soundName;
- (void)playSoundNamed:(NSString *)soundName completion:(void(^)(void))completion;
- (void)stopCurrentSound;
- (BOOL)isPlaying;
```

### 8.2 崩溃防护

- `retiredPlayers` NSMutableArray: 播放完的 AVAudioPlayer 延迟 1s 释放, 防止 dealloc 时在后台线程 crash (iOS 9 音频 bug)。
- 文件加载在 `dispatch_async` 上, `isLoading` 标记支持取消。
- `init` 时预激活 `AVAudioSession`。

### 8.3 资源路径查找

按优先级:
1. `[NSBundle mainBundle] pathForResource:ofType:inDirectory:@"ChineseWordmp3"`
2. Bundle root
3. 相对路径 "ChineseWordmp3/{filename}"

### 8.4 音效文件

| 文件 | 用途 |
|---|---|
| `cuola.caf` | 错啦 — 点错反馈 |
| `nizhenbang.caf` | 你真棒 — 答对/完成 |
| `jixujiayou.caf` | 继续加油 — 答错鼓励 |
| `jixujiayoua.caf` | (备用) |
| `{b}-{l}-{w}.mp3` | 逐字发音 (1-1-1.mp3 ~ 3-20-16.mp3) |
| `{b}-{l}.mp3` | 课文朗读 (1-1.mp3 ~ 3-20.mp3) |
| `{b}-{l}a.mp3` | 跟读音频 (1-1a.mp3 ~ 3-20a.mp3) |

---

## 9. View 组件

### 9.1 SquishyButton

自定义按钮: 圆角 + 阴影 + 按下缩放动画。

```objc
SquishyButton *btn = [[SquishyButton alloc] initWithFrame:frame
                                           backgroundColor:color
                                               shadowColor:shadowColor
                                              cornerRadius:radius];
[btn setTitle:@"文字" forState:UIControlStateNormal];
```

### 9.2 RiceCellView

米字格虚线单元格, 用于 MainScreen 网格 + Game1。

---

## 10. 构建与部署

```bash
python3 compile.py                    # → build_output/ChineseApp.ipa
python3 deploy.py                     # 安装 + 查看日志
python3 deploy.py --logs              # 仅查看日志
```

- `compile.py`: 调用 Xcode 13.4.1 的 clang (armv7), 链接, 打包 IPA。
- `deploy.py`: 用 `ios-deploy` 安装, 但 `0xe8008015` provisioning 错误 — 改用 Sideloadly。
- `Info.plist` 包含 `UIDeviceFamily 1` (iPhone) 以兼容 Sideloadly 的 DeviceFamily 检查。

---

## 11. 后端集成要点 (给架构师)

### 11.1 当前本地持久化

所有进度存在 NSUserDefaults, key 格式统一。需要改为远程数据库:

| 当前 | 目标 |
|---|---|
| NSUserDefaults | Supabase PostgreSQL |
| 本地 key 含 book/lesson | 服务端 user_progress 表 |
| 无用户概念 | Supabase Auth 用户 |
| 无管理员 | profiles.role + is_approved |

### 11.2 需要新增的文件

| 文件 | 用途 |
|---|---|
| `src/Core/SupabaseClient.m/h` | NSURLSession 封装, JWT 管理 (Keychain) |
| `src/Controllers/LoginViewController.m/h` | 登录/注册 |
| `src/Controllers/AdminViewController.m/h` | 审批 + 课程管理 |

### 11.3 需要修改的文件

| 文件 | 改动 |
|---|---|
| `AppDelegate.m` | 启动检查 JWT, 无 token 显示 LoginVC |
| `MainScreenViewController.m` | viewDidAppear 拉进度, 切换课保存 |
| `FlashcardViewController.m` | 退出/完成保存 word_index |
| `Game1ViewController.m` | viewDidAppear 拉 game1 进度 |
| `Game2ViewController.m` | 同上 |

### 11.4 建议的数据库 Schema

```sql
-- 用户 (关联 auth.users)
profiles (
  id uuid PK REFERENCES auth.users.id,
  username text,
  display_name text,
  role text CHECK (role IN ('student', 'admin')),
  is_approved boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
)

-- 进度
user_progress (
  id uuid PK,
  user_id uuid FK REFERENCES auth.users.id,
  feature text CHECK (feature IN ('main','game1','game2','game3')),
  book_number int,
  lesson_number int,
  word_index int,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (user_id, feature)  -- 每个用户每个 feature 一条
)

-- 注册审批
registration_requests (
  id uuid PK,
  user_id uuid FK REFERENCES auth.users.id,
  status text CHECK (status IN ('pending','approved','rejected')),
  approved_by uuid FK REFERENCES profiles.id,
  created_at timestamptz DEFAULT now()
)
```

### 11.5 审批流程

1. 学生注册 → 创建 registration_requests (pending)
2. 管理员登录 → 见审批列表 → approve/reject
3. 学生再次登录 → 检查 is_approved → 未通过则阻止

### 11.6 关键兼容性约束

- 只能用 `NSURLSession` (不能用 Alamofire / URLSession iOS 10+ 特性)
- JWT 存 Keychain (iOS 9 用 `kSecClassGenericPassword`)
- 管理后台在 App 内实现, 不是网页
- UI 布局代码不要动 (用户反复调整过)
- iPad Mini 1 内存 512MB, 网络请求避免大 JSON/图片

---

## 12. iOS 9 特有问题与坑

| 问题 | 解决方案 |
|---|---|
| `UIButtonTypeCustom` + `transform` + `clipsToBounds` 无法接收 touch | 改用 `UILabel` + `UITapGestureRecognizer` |
| AVAudioPlayer dealloc crash | `retiredPlayers` 延迟 1s 释放 |
| NSUserDefaults key 必须为 NSString | `[NSNumber stringValue]` 转换 |
| `viewDidUnload` 不可靠 | 不在 `didReceiveMemoryWarning` 中置空 view |
| Xcode 13.4.1 不支持 arm64e | 仅编译 armv7 |
| Sideloadly DeviceFamilyNotSupported | Info.plist 加 UIDeviceFamily 1 (iPhone) |

---

## 13. 文件清单

```
src/
├── main.m
├── AppDelegate.m/h
├── Controllers/
│   ├── BaseViewController.m/h          ← canvasView + 颜色/字体
│   ├── HomeScreenViewController.m/h    ← 首页 (识字 / Pinyin)
│   ├── MainScreenViewController.m/h    ← 识字主界面 (4 tab)
│   ├── PinyinMainViewController.m/h    ← 拼音模块 (3 游戏, ~1870 行)
│   ├── FlashcardViewController.m/h     ← 闪卡 + 认读游戏
│   ├── Game1ViewController.m/h         ← 拼字游戏
│   ├── Game2ViewController.m/h         ← 跳字游戏
│   └── Game3ViewController.m/h         ← 找字游戏
├── Core/
│   ├── AppNavigationController.m/h     ← 隐藏导航栏
│   ├── AudioManager.m/h               ← 音频播放 + 崩溃防护
│   └── GifPlayerView.m/h              ← GIF 帧播放
├── Models/
│   ├── TextbookManager.m/h             ← plist 解析 + 拼音转换
│   ├── LessonModel.m/h                 ← 课模型
│   └── WordModel.m/h                   ← 字模型
└── Views/
    ├── SquishyButton.m/h               ← 圆角阴影按钮
    └── RiceCellView.m/h                ← 米字格虚线单元格
```

---

*生成日期: 2026-06-20*
*目标: 供 iOS 全栈架构师理解现有 App 架构, 规划后端集成方案*

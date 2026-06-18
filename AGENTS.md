# Kids Chinese UI — 项目状态与技术文档

## ⚠️ 关键警告 — 任何 Agent 必须读取
**plist 文件是唯一正确的数据源。CSV 文件由 AI 生成，字符顺序与真实资料不匹配。**
- 不要删除或修改 `ChineseWordmp3/session_*.plist`、`ChineseWordmp3/review_*.plist`、`ChineseWordmp3/chapter.plist`
- 不要删除 `Textbooks/book*.txt`（用于拼音查询）
- 不要试图用 CSV 替代 plist 作为主数据源
- 不要删除 `annotate.html` 或 `serve.py`（保留供将来可能的辅助标注）
- 所有声音 / GIF / 字符偏移问题已通过 plist 方案彻底解决，用户已验证三册全部正确
- 如需修改数据加载逻辑，必须在 `TextbookManager.m` 中保留 plist 优先策略

## 项目概述
iPad Mini 1 (iOS 9.3.5, armv7, 512MB RAM) 上的儿童中文学习 App。
Xcode 13.4.1 (旧版，仅工具链) 编译，Sideloadly 侧载。

## 构建与部署
```bash
python3 compile.py                    # 构建 IPA（build_output/ChineseApp.ipa）
python3 deploy.py                     # 安装 + 查看日志（需先 USB 连接设备）
python3 deploy.py --logs              # 仅查看日志
```
- IPA 用 Sideloadly 安装到 iPad（Xcode 不能直接部署到 armv7 设备）。
- `ios-deploy` 因 `0xe8008015`（provisioning profile）报错，改用 Sideloadly。

## Git 命令（Xcode 未选中的情况下）
```bash
/Library/Developer/CommandLineTools/usr/bin/git status
/Library/Developer/CommandLineTools/usr/bin/git add -A
/Library/Developer/CommandLineTools/usr/bin/git commit -m "..."
/Library/Developer/CommandLineTools/usr/bin/git push
```

## 文件说明
| 路径 | 用途 |
|------|------|
| `Textbooks/book{1,2,3}.txt` | CSV 源数据（仅用于拼音查询） |
| `ChineseWordmp3/` | 音频 MP3 + GIF + plist 文件目录 |
| `ChineseWordmp3/chapter.plist` | **三册结构定义**（每册 25 个 session） |
| `ChineseWordmp3/session_{b}-{l}.plist` | **每课数据**（字符、音频索引、GIF 引用），共 60 个 |
| `ChineseWordmp3/review_*.plist` | 复习课数据 |
| `ChineseWordmp3/{book}_ch{idx}.gif` | 笔画 GIF（1_ch1.gif ~ 3_ch160.gif） |
| `ChineseWordmp3/{book}-{lesson}-{wordIdx}.mp3` | 逐字音频（1-1-1.mp3 ~ 3-20-16.mp3） |
| `ChineseWordmp3/{book}-{lesson}.mp3` | 课文朗读（1-1.mp3） |
| `ChineseWordmp3/{book}-{lesson}a.mp3` | 跟读音频（1-1a.mp3） |
| `src/Models/TextbookManager.m` | **plist 解析主入口**（读取 chapter.plist + session_*.plist） |
| `src/Models/WordModel.m` | `strokeGifName`（支持 plist 覆盖）+ `audioFileName` |
| `src/Models/LessonModel.m` | `readAloudAudioFileName` + `readAlongAudioFileName` |
| `src/Core/AudioManager.m` | 音频播放 + `retiredPlayers` 防崩溃 |
| `src/Core/GifPlayerView.m` | GIF 播放（UIImage 帧解析） |
| `src/Controllers/FlashcardViewController.m` | 闪卡页 + 认读游戏模式（自动播放 + 难度选择） |
| `src/Controllers/Game1ViewController.m` | 拼字游戏（米字格网格 + 简易/困难模式 + 纸屑庆祝） |
| `src/Views/RiceCellView.h/m` | 米字格虚线单元格视图（主屏幕 + Game1 共用） |
| `compile.py` | 构建脚本（clang armv7） |
| `deploy.py` | 部署 + 日志脚本 |
| `serve.py` | HTTP 服务器（保留备用） |
| `annotate.html` | 拖拽匹配工具（保留备用） |
| `AGENTS.md` | 本文档 |

## 当前状态

### ✅ 已完成
1. **plist 方案修复** — `TextbookManager.m` 从 CSV 解析改为 plist（`chapter.plist` + `session_*.plist`）解析。
   - 声音、GIF、字符顺序全部三册对齐 ✅（用户验证）
   - 保留 CSV 仅用于拼音查询
   - `WordModel.h/m` 新增 `strokeGifNameOverride` 属性，支持 plist animation 字段直接指定 GIF
2. CSV 重命名 + `TextbookManager.m` 路径修正
3. 修正 5 处拼音错误（book2: 方 shi1→fang1, 着 ji2→zhe5; book3: 房 shi2→fang2, 您 lin2→nin2, 混 huen4→hun4）
4. IPA 构建流程（compile.py + deploy.py）
5. Git 推送至 `github.com/weiweicici/kids_chinese_ui`
6. 崩溃修复 v2：`retiredPlayers` NSMutableArray + 1 秒延迟清理
7. `FlashcardViewController.m` 中 `viewDidDisappear:` 清理 recorder/recordedPlayer
8. **Info.plist**: 添加 `UIDeviceFamily 1` (iPhone) 解决 Sideloadly `DeviceFamilyNotSupported` 错误
9. **主屏幕重设计** — 网格改为 `RiceCellView`（米字格虚线 #FFD4D4，选中放大+绿色背景 0.5s 淡出），移除了海绵宝宝图片，移除 0.6s 自动跳转闪卡，Tab4 改为启动 FlashcardViewController 游戏模式
10. **Flashcard 游戏模式（认读游戏）**: 自动播放（音频→笔画 GIF→自动翻页）、🔈手动播放/🖌️重播笔画按钮、难度选择 ★☆☆☆☆/★★★★★、完成次数存入 NSUserDefaults
11. **Game1（拼字游戏）重写**: 520x520 米字格网格、88x88 卡片、简易模式（顺序+自动检查+cuola.caf反馈）/困难模式（乱序+检查顺序按钮）、完成时彩色纸屑飘落（CAEmitterLayer）+ 播放 nizhenbang.caf + 次数存入 NSUserDefaults
12. **AudioManager.m** 改进: `init` 时预激活 `AVAudioSession`、文件加载改为 `dispatch_async`、`isLoading` 标记支持取消
13. **120 个课文 MP3 重处理**: 所有 lesson MP3（1-1.mp3 ~ 3-20.mp3, 1-1a.mp3 ~ 3-20a.mp3）使用 ffmpeg silenceremove 去除前导静音 + adelay 重加 500ms，保证朗读开头无延迟
14. **游戏音效**: 删除 AI 生成的 `correct.mp3`/`wrong.mp3`，改为使用原 App 自带的 CAF 文件 (`cuola.caf` 错啦, `nizhenbang.caf` 你真棒)
15. **难度选择器颜色修复**: `[UIColor lightGrayColor]`（#aaa，不可见）→ `[self onSurfaceVariantColor]`（#3e4945，深灰绿），Game1 + Flashcard 统一修复
16. **Game1 `starTapped:` 修复**: 不再调用 `buildGameUI` 销毁全部视图（导致 star 按钮无法响应），改为只重建卡片区域（`rebuildCards`）+ 切换检查按钮可见性 + 更新星级
17. **难度选择器改用 UILabel + UITapGestureRecognizer**: 解决 iOS 9 上 UIButtonTypeCustom 在 transform + clipsToBounds 下无法接收 touch 事件的 bug。两个游戏（Game1 + Flashcard）统一替换，同时 Game1 难度选择器改为在 buildGameUI 中最后创建确保 z-order 最顶层，Flashcard footerView 显式设置 clipsToBounds = NO

### ❌ 已知问题

#### 1. crash fix v2 尚未验证
- `retiredPlayers` + 1s 延迟清理方案理论上比 `dispatch_async` 更健壮
- 用户尚未在实际使用中验证是否还会崩溃

#### 2. `ios-deploy` 安装失败
- `0xe8015: provisioning profile not found`
- 当前方案：Sideloadly 侧载 + `deploy.py --logs` 看日志

## 架构关键决策
- **数据来源：plist** — `session_*.plist` 保存正确字符顺序，`chapter.plist` 保存课程结构
- **拼音**：从 CSV 按字符匹配获取，CSV 仅作为拼音字典
- **GIF 映射**：plist `animation` 字段提供直接文件名覆盖 (`strokeGifNameOverride`)
- **GIF 回退**：当 animation 为空时使用默认 `gifIndex = (lesson-1)*16 + wordIndex`
- 前 10 课有笔画 GIF（`hasStrokeGif = lessonNumber <= 10`），后 10 课无
- 每课 16 字，每册 20 课 → 160 GIFs + 320 MP3s + 20 lesson MP3s + 20 follow-along MP3s
- 不分 MVC 目录（原始项目结构，兼容 iOS 9 / MRC-free）

## 未来规划 — 后端 + 用户系统（Supabase）

### 概述
- **后端**: Supabase（PostgreSQL + Auth + REST API）
- **App 网络层**: `NSURLSession` + `NSJSONSerialization`（原生，兼容 iOS 7+）
- **鉴权**: Supabase Auth（邮箱/密码注册），JWT token 存 Keychain
- **管理后台**: 在 iPad App 内实现（非网页）
- **进度追踪**: 主界面 + 3 个小游戏各自独立记录上次学到的位置

### 数据库表设计

**profiles**（关联 `auth.users`）
| 列 | 类型 | 说明 |
|---|---|---|
| id | uuid PK | 关联 `auth.users.id` |
| username | text | 用户名 |
| display_name | text | 显示名称 |
| role | text | `'student'` 或 `'admin'` |
| is_approved | boolean | 是否已通过审批 |
| created_at | timestamptz | |

**user_progress**
| 列 | 类型 | 说明 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | `auth.users.id` |
| feature | text | `'main'` / `'game1'` / `'game2'` / `'game3'` |
| book_number | int | 册数 |
| lesson_number | int | 课数 |
| word_index | int? | 闪卡专用（当前看到第几个字） |
| updated_at | timestamptz | |

**registration_requests**（审批队列）
| 列 | 类型 | 说明 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | 关联请求注册的用户 |
| status | text | `'pending'` / `'approved'` / `'rejected'` |
| approved_by | uuid FK? | 审批人 |
| created_at | timestamptz | |

### API 端点（App 直接调用 Supabase REST API）

| 端点 | 用途 |
|---|---|
| `POST /auth/v1/signup` | 注册 |
| `POST /auth/v1/token?grant_type=password` | 登录 |
| `GET /rest/v1/profiles?select=*` + JWT | 取当前用户信息 |
| `PATCH /rest/v1/profiles?id=eq.{id}` | 管理员审批（设 role+is_approved） |
| `GET /rest/v1/registration_requests?status=eq.pending` | 管理员拉取待审批列表 |
| `POST /rest/v1/user_progress` | 保存进度（upsert） |
| `GET /rest/v1/user_progress?user_id=eq.{id}` | 读取进度 |

### 审批流程
1. 学生注册（邮箱+密码+用户名）→ 自动创建 `registration_requests`（pending）
2. 管理员登录 App → 看到管理入口（仅 `role='admin'` 显示）→ 审批列表 → 通过/拒绝
3. 学生再次登录 → 检查 `is_approved` → 未通过则显示"账号待审批"提示页

### App 端改动清单

**新增文件：**
| 文件 | 用途 |
|---|---|
| `src/Core/SupabaseClient.m/h` | 封装 NSURLSession 调用 Supabase REST API + JWT 管理（Keychain） |
| `src/Controllers/LoginViewController.m/h` | 登录/注册页 |
| `src/Controllers/AdminViewController.m/h` | 管理后台（审批列表） |

**修改文件：**
| 文件 | 改动 |
|---|---|
| `AppDelegate.m` | 启动时检查 JWT token；无 token 显示 LoginVC，有 token 正常进 MainScreen |
| `MainScreenViewController.m` | `viewDidAppear:` 拉取 `feature='main'` 进度定位；切换课后调用 API 保存 |
| `FlashcardViewController.m` | 退出/完成时保存 `word_index` |
| `Game1ViewController.m` | `viewDidAppear:` 拉 `feature='game1'` 进度；退出时保存 |
| `Game2ViewController.m` | 同上 |

### 实施步骤
1. Supabase 建项目 → 建表 → 设 RLS 策略
2. 写 `SupabaseClient.m/h`（封装注册、登录、CRUD）
3. 写 `LoginViewController.m/h`
4. 改 `AppDelegate.m` 启动流程
5. 写 `AdminViewController.m/h`
6. 改 MainScreen/Flashcard/Game1/Game2 加进度读写
7. 编译测试 → 部署

## 关键约束
- **不要碰 UI 布局代码**（用户花大量时间调整过）
- 目标设备：iPad Mini 1, iOS 9.3.5 (13G36), armv7, 512MB RAM
- 内存约 13-15 MB，远低于 80 MB 限制
- Xcode-13.4.1.app 位于 `/Applications/Xcode-13.4.1.app`
- `idevicesyslog --syslog-relay` 已确认可用

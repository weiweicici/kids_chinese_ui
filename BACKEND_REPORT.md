# 后端集成报告 — Kids Chinese UI

## 概述

为 iPad Mini 1 (iOS 9.3.5, armv7, 512MB RAM) 的儿童中文学习 App 添加 Supabase 后端支持。
零第三方库依赖，纯 NSURLSession + Keychain 原生实现。

---

## 1. 数据库设计 (Supabase/PostgreSQL)

### 三张表

**profiles** — 用户资料（关联 `auth.users`）
| 列 | 类型 | 说明 |
|---|---|---|
| id | uuid PK | 关联 `auth.users.id` |
| username | text UNIQUE | 用户名 |
| display_name | text | 显示名称 |
| role | text | `'student'` 或 `'admin'` |
| is_approved | boolean | 是否已通过审批 |
| created_at | timestamptz | |

**user_progress** — 学习进度
| 列 | 类型 | 说明 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | 关联 `auth.users.id` |
| feature | text | `'main'` / `'flashcard'` / `'game1'` / `'game2'` |
| book_number | int | 册数 |
| lesson_number | int | 课数 |
| word_index | int? | 闪卡专用（当前看到第几个字） |
| updated_at | timestamptz | |
| UNIQUE(user_id, feature) | | 每人每种功能一条记录 |

**registration_requests** — 审批队列
| 列 | 类型 | 说明 |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | 关联请求注册的用户 |
| status | text | `'pending'` / `'approved'` / `'rejected'` |
| approved_by | uuid FK? | 审批人 |
| created_at | timestamptz | |

### RLS 策略

- `is_admin()` 函数：查询当前用户的 `profiles.role == 'admin'`
- **profiles**: 用户只能 INSERT 自己的记录（注册时），SELECT 自己是或管理员，只有管理员可以 UPDATE
- **user_progress**: 用户完全管理自己的进度（user_id = auth.uid()）
- **registration_requests**: 用户只能 INSERT 自己的申请，仅管理员可以管理

---

## 2. 网络层 — SupabaseClient (src/Core/SupabaseClient.m/h)

### 架构

```
┌──────────────┐
│  ViewController │──→ [SupabaseClient.sharedClient]
└──────────────┘         │
                         ├── isAvailable (graceful degradation)
                         ├── NSURLSession (ephemeral, serial callback queue)
                         ├── Keychain (kSecClassGenericPassword)
                         └── REST / Auth / Download methods
```

### 关键设计决策

| 决策 | 理由 |
|---|---|
| `ephemeralSessionConfiguration` | 零 cookie/cache，512MB 设备上无内存浪费 |
| 串行 NSOperationQueue | 网络回调从不在主线程解析 JSON，不阻塞 UI |
| `kSecAttrAccessibleAfterFirstUnlock` | 后台 sync 任务也可读 Keychain |
| `timeoutIntervalForRequest = 15s` | 弱网环境下不长期挂起 |
| `isAvailable` 标记 | 无网络/未配置时所有方法返回空，app 仍可用 |

### 方法清单

| 方法 | 用途 |
|---|---|
| `updateBaseURL:anonKey:` | 初始化/重配客户端 |
| `saveToken:` / `getToken` / `clearToken` | JWT Keychain 存取 |
| `saveRole:` / `getCachedRole` | 角色缓存（同步，不依赖网络） |
| `GET:completion:` | REST GET（自动加 pagination `?limit=20`） |
| `POST:body:completion:` | REST POST |
| `PATCH:body:completion:` | REST PATCH |
| `signUpWithEmail:password:completion:` | Supabase Auth 注册（用 anon key，不用 Bearer） |
| `signInWithEmail:password:completion:` | Supabase Auth 登录 |
| `downloadFile:toPath:completion:` | NSURLSessionDownloadTask 流式下载文件 |
| `currentUserIdFromToken` | 本地解码 JWT payload 提取 `sub`（零网络开销） |
| `saveProgressWithFeature:...completion:` | Upsert 进度到 user_progress（`Prefer: resolution=merge-duplicates`） |

### 下载机制的特殊实现

用 `NSURLSessionDownloadDelegate` 的 `downloadTask:didFinishDownloadingToURL:` 回调 + `NSMutableDictionary` 存储 taskInfo（含 completion block 和 destPath）实现原子移动。`didCompleteWithError:` 处理网络错误时的 cleanup。

### Auth 的特殊处理

Auth 端点（`/auth/v1/signup`、`/auth/v1/token`）用 anon key 做 Authorization（不是 Bearer token），因为此时还没有 JWT。`authRequestWithPath:body:completion:` 是独立路径，不经过通用的 `requestForPath:`（后者会自动加 Bearer token）。

---

## 3. 登录/注册 — LoginViewController (src/Controllers/LoginViewController.m/h)

### 界面布局（768×1024 canvas）

```
┌──────────────────────────────────────┐
│           谷老师中文乐园               │
│  ┌────────────────────────────────┐  │
│  │   [ 登录 | 注册 ]              │  │
│  │   ┌─────────────────────┐      │  │
│  │   │  邮箱               │      │  │
│  │   └─────────────────────┘      │  │
│  │   ┌─────────────────────┐      │  │
│  │   │  密码               │      │  │
│  │   └─────────────────────┘      │  │
│  │   [用户名 — 仅注册时显示]      │  │
│  │   ┌─────────────────────┐      │  │
│  │   │   登录 / 注册        │      │  │
│  │   └─────────────────────┘      │  │
│  │   状态信息                      │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### 注册流程

```
用户填写邮箱+密码+用户名 → [POST /auth/v1/signup] → 拿到 userId
  → [POST /rest/v1/profiles] 创建 {id, username, role:'student', is_approved:false}
  → [POST /rest/v1/registration_requests] 创建 {user_id, status:'pending'}
  → 显示 "注册成功！请等待老师审批后登录"
```

### 登录流程

```
用户填写邮箱+密码 → [POST /auth/v1/token?grant_type=password]
  → 拿到 access_token → saveToken:
  → [GET /rest/v1/profiles?id=eq.authenticated]
  → 检查 is_approved
      → true: saveRole → proceedToHome（替换 rootViewController）
      → false: 清除 token → "账号待审批" 弹窗
```

### 审批后的登录

当老师通过 AdminViewController 审批后：
- `profiles.is_approved = true`
- 学生再次登录 → fetchProfile → approved → 直接进入 HomeScreen

### 关键实现细节

- 用 `SquishyButton` 做提交按钮（风格统一）
- UISegmentedControl 切换登录/注册模式时，用户名 field 动画显示/隐藏
- `UIActivityIndicatorView` 加载状态
- 所有网络回调 `dispatch_async(dispatch_get_main_queue())` 更新 UI
- `proceedToHome` 直接替换 `window.rootViewController`（而不是 push），防止保留 LoginVC 在导航栈中

---

## 4. 启动流程 — AppDelegate (src/AppDelegate.m)

```
application:didFinishLaunchingWithOptions:
  │
  ├── [[SupabaseClient sharedClient] updateBaseURL:anonKey:]
  │
  ├── [getToken] != nil?
  │     ├── YES → mountHome (立即显示 HomeScreen)
  │     │          → 后台 GET /profiles 验证 token
  │     │             ├── 成功: saveRole, 检查 is_approved
  │     │             └── 失败/未批准: clearToken（下次启动显示登录页）
  │     └── NO  → mountLogin (显示 LoginViewController)
  │
  └── return YES
```

### 启动优化

- **骨架屏策略**: 有 token 时立刻显示 HomeScreen，后台异步验证。用户不等待。
- **角色缓存**: `getCachedRole` 从 Keychain 同步读取，HomeScreen 的 admin 按钮即刻显示。
- **失败回退**: 验证失败时 clearToken，下次 app 冷启动走登录页。

---

## 5. 管理员后台 — AdminViewController (src/Controllers/AdminViewController.m/h)

### 布局

```
┌──────────────────────────────────────┐
│  ‹ 返回    管理后台      刷新      │
│      [ 审批 | 进度 | 课程 ]           │
│  ┌──────────────────────────────┐    │
│  │                              │    │
│  │  UITableView (单表复用)       │    │
│  │                              │    │
│  │  李小明的注册申请  2026-06-20 │    │
│  │                     [✓] [✗] │    │
│  │                              │    │
│  │  张三的注册申请    2026-06-19 │    │
│  │                     [✓] [✗] │    │
│  └──────────────────────────────┘    │
└──────────────────────────────────────┘
```

### 审批流程

```
Admin 打开 app → 登录 → HomeScreen 右上角 "管理" 按钮（仅 role=admin 可见）
  → AdminViewController（审批 tab 默认选中）
  → [GET /rest/v1/registration_requests?status=eq.pending]
  → [GET /rest/v1/profiles?id=in.(userid1,userid2,...)] 批量查用户名
  → 列表显示 + 批准/拒绝按钮

点击 ✓ 批准:
  → 确认弹窗 → [PATCH registration_requests status=approved]
               → [PATCH profiles is_approved=true, role=student]
               → 刷新列表

点击 ✗ 拒绝:
  → 确认弹窗 → [PATCH registration_requests status=rejected] → 刷新列表
```

### 关键实现

- **单 UITableView + segmentedControl**: 三个 tab 共享同一 tableView，数据源根据 `currentTab` 切换。进度/课程 tab 显示占位 "开发中"。
- **批量 profile 查询**: 收集所有 user_ids → `id=in.(a,b,c)` 一次查询 → 构建 NSDictionary 映射。
- **按钮 tag 映射行号**: approveBtn/rejectBtn 的 tag = indexPath.row，通过 `self.pendingRequests[sender.tag]` 获取对应数据。
- **滚动自适应**: 688×840 的 tableView 足够容纳大量待审批项。

---

## 6. 进度同步 — 四视图控制器

### 同步方式

每个 VC 在关键时机调用 `[[SupabaseClient sharedClient] saveProgressWithFeature:...]`，这个方法：
1. 调用 `currentUserIdFromToken` 本地解析 JWT（零网络）
2. 构造 upsert body（包含 user_id, feature, book, lesson, word_index, updated_at）
3. 发送 POST 到 `/rest/v1/user_progress`，携带 `Prefer: resolution=merge-duplicates` 头

### 各 VC 触发时机

| VC | Feature | 触发时机 | 附带数据 |
|---|---|---|---|
| MainScreen | `main` | `pickerLessonSelected:` 切换课程后 | book, lesson |
| Flashcard | `flashcard` | `backBtnClicked` / `gameComplete` | book, lesson, wordIndex |
| Game1 | `game1` | `gameComplete` | book, lesson |
| Game2 | `game2` | `gameComplete` | book, lesson |

### 离线兼容

所有 Supabase 调用使用 `#if __has_include("SupabaseClient.h")` 条件编译。当文件不存在时（no-backend 分支），代码静默跳过，NSUserDefaults 本地存盘路径不变。

---

## 7. 分支管理

| 分支 | 内容 | 编译 |
|---|---|---|
| `main` | 完整后端集成 + 所有功能 | `python3 compile.py` |
| `no-backend` | 纯离线版，无 Supabase 代码 | `python3 compile.py` |

两个分支共享所有 UI、游戏逻辑、数据加载代码。差异仅在于：
- 新增 6 个文件（SupabaseClient.h/m, LoginViewController.h/m, AdminViewController.h/m）
- 修改 6 个文件（AppDelegate.m, compile.py, MainScreen/Flashcard/Game1/Game2）
- 删除时只需 `git checkout no-backend`

---

## 8. SQL 文件

| 文件 | 用途 |
|---|---|
| `supabase_schema.sql` | 建三张表（profiles, user_progress, registration_requests）+ RLS 启用 |
| `supabase_rls.sql` | is_admin() 函数 + 所有 RLS 策略 |

---

## 9. 编译说明

```bash
# main 分支（带后端）
git checkout main
python3 compile.py

# no-backend 分支（纯离线）
git checkout no-backend
python3 compile.py

# 侧载
# 用 Sideloadly 安装 build_output/ChineseApp.ipa
# 日志查看：python3 deploy.py --logs
```

`compile.py` 在 main 分支上额外链接 `-framework Security`（Keychain 支持）。no-backend 分支不需要。

---

## 10. 部署前必做配置

1. Supabase 项目 → Authentication → Providers → Email → **关闭 "Confirm sign up"**
2. SQL Editor 运行 `supabase_schema.sql`
3. SQL Editor 运行 `supabase_rls.sql`
4. 管理员自己注册后 → Table Editor → `profiles` 表 → 设 `role='admin'`, `is_approved=true`

---

## 11. 完整数据流

```
                    ┌─────────────────────┐
                    │   app 启动           │
                    │   AppDelegate        │
                    └──────┬──────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
        [有 JWT token]            [无 JWT token]
              │                         │
              ▼                         ▼
        HomeScreen              LoginViewController
              │                         │
        ┌─────┴─────┐             注册 / 登录
        ▼           ▼                 │
    学生入口    管理员入口             ▼
    (识字/拼音)  "管理"按钮      Supabase Auth
        │           │                 │
        ▼           ▼            拿到 JWT
    学习/游戏  AdminViewController    │
        │           │                ▼
        ▼           ▼          GET /profiles
    本地存盘    审批列表              │
    NSUserDefaults  │           ┌────┴────┐
        │           │           ▼         ▼
        ▼           ▼      is_approved  未批准
    ↓ 额外同步到    批准/拒绝   │
    Supabase        │         HomeScreen 弹窗
    user_progress   ▼         (或管理员
                PATCH profiles   进管理后台)
                + requests
```

---

## 12. 安全考量

- JWT 只存 Keychain（`kSecAttrAccessibleAfterFirstUnlock`），永不存 NSUserDefaults
- 所有 REST 调用通过 HTTPS
- RLS 确保用户只能读写自己的数据
- Auth 端点用 anon key（非 service_role key），无超级权限
- 401 响应自动清除 token，下次启动 → 登录页
- `Prefer: resolution=merge-duplicates` 防止并发冲突

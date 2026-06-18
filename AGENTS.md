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
| `src/Controllers/FlashcardViewController.m` | 闪卡页（播放发音 + GIF） |
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

## 关键约束
- **不要碰 UI 布局代码**（用户花大量时间调整过）
- 目标设备：iPad Mini 1, iOS 9.3.5 (13G36), armv7, 512MB RAM
- 内存约 13-15 MB，远低于 80 MB 限制
- Xcode-13.4.1.app 位于 `/Applications/Xcode-13.4.1.app`
- `idevicesyslog --syslog-relay` 已确认可用

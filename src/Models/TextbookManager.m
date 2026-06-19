#import "TextbookManager.h"

@interface TextbookManager ()
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSArray<LessonModel *> *> *booksData;
@end

// Convert "han4" → "hàn", "zhe5" → "zhe"
static NSString *PinyinToneToMarks(NSString *src) {
    if (src.length < 2) return src;
    NSString *lastChar = [src substringFromIndex:src.length - 1];
    NSInteger tone = [lastChar integerValue];
    if (tone < 1 || tone > 5) return src;
    NSString *body = [src substringToIndex:src.length - 1];
    if (body.length == 0) return src;
    if (tone == 5) return body;

    static NSDictionary *marks = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        marks = @{
            @"a": @[@"ā", @"á", @"ǎ", @"à"],
            @"e": @[@"ē", @"é", @"ě", @"è"],
            @"i": @[@"ī", @"í", @"ǐ", @"ì"],
            @"o": @[@"ō", @"ó", @"ǒ", @"ò"],
            @"u": @[@"ū", @"ú", @"ǔ", @"ù"],
            @"ü": @[@"ǖ", @"ǘ", @"ǚ", @"ǜ"],
        };
    });

    // Rule 1: a / e wins
    NSInteger vowelIdx = -1;
    NSString *vowelChar = nil;
    NSRange r = [body rangeOfString:@"a"];
    if (r.location != NSNotFound) { vowelIdx = r.location; vowelChar = @"a"; }
    if (vowelIdx == -1) {
        r = [body rangeOfString:@"e"];
        if (r.location != NSNotFound) { vowelIdx = r.location; vowelChar = @"e"; }
    }
    // Rule 2: ou → o
    if (vowelIdx == -1) {
        r = [body rangeOfString:@"ou"];
        if (r.location != NSNotFound) { vowelIdx = r.location; vowelChar = @"o"; }
    }
    // Rule 3: last vowel
    if (vowelIdx == -1) {
        NSArray *vowels = @[@"a", @"e", @"i", @"o", @"u", @"ü"];
        for (NSString *v in vowels) {
            r = [body rangeOfString:v options:NSBackwardsSearch];
            if (r.location != NSNotFound) { vowelIdx = r.location; vowelChar = v; }
        }
    }
    if (vowelIdx == -1) return src;

    NSString *marked = marks[vowelChar][tone - 1];
    return [body stringByReplacingCharactersInRange:NSMakeRange(vowelIdx, 1) withString:marked];
}

@implementation TextbookManager

+ (instancetype)sharedManager {
    static TextbookManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance loadAllTextbooks];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _booksData = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)loadAllTextbooks {
    // Build pinyin lookup from CSV (char → pinyinWithTone)
    NSMutableDictionary *pinyinLookup = [NSMutableDictionary dictionary];
    for (NSInteger b = 1; b <= 3; b++) {
        NSString *csvPath = [self resolvePath:[NSString stringWithFormat:@"Textbooks/book%ld.txt", (long)b]];
        if (csvPath) {
            NSString *content = [NSString stringWithContentsOfFile:csvPath encoding:NSUTF8StringEncoding error:nil];
            if (content) {
                NSArray *lines = [content componentsSeparatedByString:@"\n"];
                for (NSString *line in lines) {
                    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (trimmed.length == 0) continue;
                    NSArray *parts = [trimmed componentsSeparatedByString:@","];
                    if (parts.count < 6) continue;
                    if ([parts[0] isEqualToString:@"册"]) continue;
                    NSString *ch = parts[3];
                    NSString *py = parts[4];
                    NSString *pyPlain = parts[5];
                    if (!pinyinLookup[ch]) {
                        pinyinLookup[ch] = @[py, pyPlain];
                    }
                }
            }
        }
    }

    // Load chapter.plist to get session order per book
    NSString *chapterPath = [self resolvePath:@"ChineseWordmp3/chapter.plist"];
    if (!chapterPath) {
        NSLog(@"Error: chapter.plist not found");
        return;
    }
    NSArray *chapterData = [NSArray arrayWithContentsOfFile:chapterPath];
    if (!chapterData || chapterData.count < 3) {
        NSLog(@"Error: invalid chapter.plist");
        return;
    }

    for (NSInteger bookIdx = 0; bookIdx < 3; bookIdx++) {
        NSInteger bookNumber = bookIdx + 1;
        NSArray *sessionNames = chapterData[bookIdx];
        NSMutableArray<LessonModel *> *lessonModels = [NSMutableArray array];

        for (NSString *sessionName in sessionNames) {
            // Only process session_* (not review_*)
            if (![sessionName hasPrefix:@"session_"]) continue;

            NSArray *parts = [sessionName componentsSeparatedByString:@"-"];
            if (parts.count < 2) continue;
            NSString *plistPath = [self resolvePath:[NSString stringWithFormat:@"ChineseWordmp3/%@.plist", sessionName]];
            if (!plistPath) {
                NSLog(@"Warning: plist not found: %@", sessionName);
                continue;
            }

            NSDictionary *sessionDict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
            if (!sessionDict) {
                NSLog(@"Warning: cannot read plist: %@", sessionName);
                continue;
            }

            NSInteger lessonNumber = [parts[1] integerValue];
            NSArray *wordsData = sessionDict[@"words"];
            if (!wordsData || wordsData.count == 0) continue;

            NSMutableArray<WordModel *> *wordModels = [NSMutableArray array];
            for (NSInteger i = 0; i < wordsData.count; i++) {
                NSDictionary *wd = wordsData[i];
                NSString *character = wd[@"labelText"];
                NSString *animation = wd[@"animation"];
                NSString *sound = wd[@"sound"]; // e.g., "0_0"

                WordModel *word = [[WordModel alloc] init];
                word.bookNumber = bookNumber;
                word.lessonNumber = lessonNumber;
                word.wordIndex = i + 1; // 1-based
                word.character = character;

                // Set pinyin from CSV lookup; convert tone numbers to Unicode marks
                NSArray *pyData = pinyinLookup[character];
                if (pyData) {
                    word.pinyinWithTone = PinyinToneToMarks(pyData[0]);
                    word.pinyinWithoutTone = pyData[1];
                } else {
                    word.pinyinWithTone = @"";
                    word.pinyinWithoutTone = @"";
                }

                // Set GIF override if animation is provided
                if (animation && animation.length > 0) {
                    word.strokeGifNameOverride = [NSString stringWithFormat:@"%@.gif", animation];
                }

                [wordModels addObject:word];
            }

            LessonModel *lesson = [[LessonModel alloc] init];
            lesson.bookNumber = bookNumber;
            lesson.lessonNumber = lessonNumber;
            lesson.words = wordModels;

            [lessonModels addObject:lesson];
        }

        // Sort lessons by lessonNumber
        [lessonModels sortUsingComparator:^NSComparisonResult(LessonModel *a, LessonModel *b) {
            return [@(a.lessonNumber) compare:@(b.lessonNumber)];
        }];

        self.booksData[@(bookNumber)] = lessonModels;
    }
}

- (NSString *)resolvePath:(NSString *)relativePath {
    NSFileManager *fm = [NSFileManager defaultManager];
    // 1. Split relative path into directory + filename
    NSString *dir = [relativePath stringByDeletingLastPathComponent];
    NSString *file = [relativePath lastPathComponent];
    NSString *ext = [file pathExtension];
    NSString *name = [file stringByDeletingPathExtension];

    // 2. Try bundle subdirectory
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:ext inDirectory:dir];
    if (path && [fm fileExistsAtPath:path]) return path;

    // 3. Try bundle root
    path = [[NSBundle mainBundle] pathForResource:name ofType:ext];
    if (path && [fm fileExistsAtPath:path]) return path;

    // 4. Try absolute workspace path
    path = [NSString stringWithFormat:@"/Users/macmini/Downloads/kids_chinese_ui/%@", relativePath];
    if ([fm fileExistsAtPath:path]) return path;

    // 5. Try relative to cwd
    if ([fm fileExistsAtPath:relativePath]) return relativePath;

    return nil;
}

- (NSArray<LessonModel *> *)lessonsForBook:(NSInteger)bookNumber {
    return self.booksData[@(bookNumber)] ?: @[];
}

- (LessonModel *)lessonForBook:(NSInteger)bookNumber lesson:(NSInteger)lessonNumber {
    NSArray<LessonModel *> *lessons = [self lessonsForBook:bookNumber];
    for (LessonModel *lesson in lessons) {
        if (lesson.lessonNumber == lessonNumber) {
            return lesson;
        }
    }
    return nil;
}

- (WordModel *)wordForBook:(NSInteger)bookNumber lesson:(NSInteger)lessonNumber wordIndex:(NSInteger)wordIndex {
    LessonModel *lesson = [self lessonForBook:bookNumber lesson:lessonNumber];
    if (lesson && wordIndex >= 1 && wordIndex <= lesson.words.count) {
        return lesson.words[wordIndex - 1];
    }
    return nil;
}

@end

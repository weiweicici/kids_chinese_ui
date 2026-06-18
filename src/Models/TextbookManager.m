#import "TextbookManager.h"

@interface TextbookManager ()
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSArray<LessonModel *> *> *booksData;
@end

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
    for (NSInteger b = 1; b <= 3; b++) {
        NSString *path = [self pathForBook:b];
        if (!path) {
            NSLog(@"Warning: Could not find textbook data path for book %ld", (long)b);
            continue;
        }
        
        NSError *error = nil;
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
        if (error || !content) {
            NSLog(@"Error reading textbook file: %@", error);
            continue;
        }
        
        // Parse CSV content
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        NSMutableDictionary<NSNumber *, NSMutableArray<WordModel *> *> *lessonsWords = [NSMutableDictionary dictionary];
        
        for (NSString *line in lines) {
            NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmedLine.length == 0) {
                continue;
            }
            
            // Split by comma
            NSArray *components = [trimmedLine componentsSeparatedByString:@","];
            if (components.count < 6) {
                continue;
            }
            
            // Check if header line
            if ([components[0] isEqualToString:@"册"]) {
                continue;
            }
            
            NSInteger book = [components[0] integerValue];
            NSInteger lesson = [components[1] integerValue];
            NSInteger wordIdx = [components[2] integerValue];
            NSString *character = components[3];
            NSString *pinyinWithTone = components[4];
            NSString *pinyinWithoutTone = components[5];
            
            WordModel *word = [[WordModel alloc] init];
            word.bookNumber = book;
            word.lessonNumber = lesson;
            word.wordIndex = wordIdx;
            word.character = character;
            word.pinyinWithTone = pinyinWithTone;
            word.pinyinWithoutTone = pinyinWithoutTone;
            
            NSNumber *lessonKey = @(lesson);
            if (!lessonsWords[lessonKey]) {
                lessonsWords[lessonKey] = [NSMutableArray array];
            }
            [lessonsWords[lessonKey] addObject:word];
        }
        
        // Convert lessonsWords to LessonModel array sorted by lesson number
        NSMutableArray<LessonModel *> *lessonModels = [NSMutableArray array];
        NSArray *sortedLessonKeys = [[lessonsWords allKeys] sortedArrayUsingSelector:@selector(compare:)];
        
        for (NSNumber *lessonKey in sortedLessonKeys) {
            NSArray<WordModel *> *words = lessonsWords[lessonKey];
            
            // Sort words by wordIndex to guarantee 1-16 ordering
            NSArray<WordModel *> *sortedWords = [words sortedArrayUsingComparator:^NSComparisonResult(WordModel *w1, WordModel *w2) {
                return [@(w1.wordIndex) compare:@(w2.wordIndex)];
            }];
            
            LessonModel *lesson = [[LessonModel alloc] init];
            lesson.bookNumber = b;
            lesson.lessonNumber = [lessonKey integerValue];
            lesson.words = sortedWords;
            
            [lessonModels addObject:lesson];
        }
        
        self.booksData[@(b)] = lessonModels;
    }
}

- (NSString *)pathForBook:(NSInteger)bookNumber {
    NSString *fileName = nil;
    if (bookNumber == 1) {
        fileName = @"deepseek_csv_20260615_9c9e07";
    } else if (bookNumber == 2) {
        fileName = @"deepseek_csv_20260615_84e570";
    } else if (bookNumber == 3) {
        fileName = @"deepseek_csv_20260615_984b86";
    }
    
    // 1. Try NSBundle
    NSString *path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"txt"];
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // Try bundle Textbooks directory
    path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"txt" inDirectory:@"Textbooks"];
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // 2. Try absolute workspace path
    path = [NSString stringWithFormat:@"/Users/macmini/Downloads/kids_chinese_ui/Textbooks/%@.txt", fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
    // 3. Try relative path
    path = [NSString stringWithFormat:@"Textbooks/%@.txt", fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    
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

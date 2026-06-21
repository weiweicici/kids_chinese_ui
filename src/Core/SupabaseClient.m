#import "SupabaseClient.h"
#import <Security/Security.h>

static NSString *const kKeychainService = @"com.kidschinese.supabase";
static NSString *const kTokenAccount = @"auth_token";
static NSString *const kRoleAccount = @"cached_role";
static NSTimeInterval const kRequestTimeout = 15.0;

@interface SupabaseClient () <NSURLSessionDownloadDelegate>

@property (strong, nonatomic) NSString *baseURL;
@property (strong, nonatomic) NSString *anonKey;
@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSOperationQueue *callbackQueue;
@property (assign, nonatomic) BOOL available;
@property (strong, nonatomic) NSMutableDictionary *downloadTasks; // taskID -> {block, destPath}

@end

@implementation SupabaseClient

+ (instancetype)sharedClient {
    static SupabaseClient *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _available = NO;
        _downloadTasks = [NSMutableDictionary dictionary];

        // Serial callback queue — all network responses processed here,
        // never on the main thread.
        _callbackQueue = [[NSOperationQueue alloc] init];
        _callbackQueue.maxConcurrentOperationCount = 1;
        _callbackQueue.name = @"com.kidschinese.supabase.callback";
    }
    return self;
}

- (void)updateBaseURL:(NSString *)baseURL anonKey:(NSString *)anonKey {
    self.baseURL = baseURL;
    self.anonKey = anonKey;

    // Tear down old session before creating new one
    if (self.session) {
        [self.session invalidateAndCancel];
        self.session = nil;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.timeoutIntervalForRequest = kRequestTimeout;
    config.timeoutIntervalForResource = 60.0;
    config.HTTPShouldUsePipelining = YES;
    // No cookies, no cache, no credential storage — we own every byte
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
    config.URLCache = nil;
    config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    self.session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:self
                                            delegateQueue:self.callbackQueue];
    self.available = (baseURL.length > 0 && anonKey.length > 0);
}

#pragma mark - Graceful Degradation

- (BOOL)isAvailable {
    return self.available && self.session != nil;
}

#pragma mark - Keychain

- (void)saveKeychainValue:(NSString *)value forAccount:(NSString *)account {
    if (!value || !account) return;
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];

    // Try update first
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: account,
    };
    NSDictionary *update = @{
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
    };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                    (__bridge CFDictionaryRef)update);
    if (status == errSecItemNotFound) {
        NSDictionary *newItem = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: kKeychainService,
            (__bridge id)kSecAttrAccount: account,
            (__bridge id)kSecValueData: data,
            (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlock,
        };
        SecItemAdd((__bridge CFDictionaryRef)newItem, NULL);
    }
}

- (NSString *)keychainValueForAccount:(NSString *)account {
    if (!account) return nil;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (void)deleteKeychainValueForAccount:(NSString *)account {
    if (!account) return;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kKeychainService,
        (__bridge id)kSecAttrAccount: account,
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

- (void)saveToken:(NSString *)jwt {
    [self saveKeychainValue:jwt forAccount:kTokenAccount];
}

- (NSString *)getToken {
    return [self keychainValueForAccount:kTokenAccount];
}

- (void)clearToken {
    [self deleteKeychainValueForAccount:kTokenAccount];
    [self deleteKeychainValueForAccount:kRoleAccount];
}

- (void)saveRole:(NSString *)role {
    [self saveKeychainValue:role forAccount:kRoleAccount];
}

- (NSString *)getCachedRole {
    return [self keychainValueForAccount:kRoleAccount];
}

#pragma mark - Request Builder

- (NSMutableURLRequest *)requestForPath:(NSString *)path {
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    // Auth header
    NSString *token = [self getToken];
    if (token) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", token]
   forHTTPHeaderField:@"Authorization"];
    } else if (self.anonKey) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.anonKey]
   forHTTPHeaderField:@"Authorization"];
        [req setValue:self.anonKey forHTTPHeaderField:@"apikey"];
    }

    // Defensive pagination — always limit to 20 rows unless explicitly overridden
    if ([path containsString:@"/rest/v1/"] && ![path containsString:@"limit="]) {
        if ([path rangeOfString:@"?"].location == NSNotFound) {
            req.URL = [NSURL URLWithString:[urlString stringByAppendingString:@"?limit=20"]];
        } else {
            req.URL = [NSURL URLWithString:[urlString stringByAppendingString:@"&limit=20"]];
        }
    }

    return req;
}

#pragma mark - REST Methods

- (void)GET:(NSString *)path completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!self.isAvailable) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"SupabaseClient not available"}]);
        return;
    }
    NSMutableURLRequest *req = [self requestForPath:path];
    req.HTTPMethod = @"GET";

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data,
          NSURLResponse *response, NSError *error) {
        [self handleResponse:data response:response error:error completion:completion];
    }] resume];
}

- (void)POST:(NSString *)path body:(NSDictionary *)body
                                completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!self.isAvailable) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"SupabaseClient not available"}]);
        return;
    }
    NSMutableURLRequest *req = [self requestForPath:path];
    req.HTTPMethod = @"POST";
    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data,
          NSURLResponse *response, NSError *error) {
        [self handleResponse:data response:response error:error completion:completion];
    }] resume];
}

- (void)PATCH:(NSString *)path body:(NSDictionary *)body
                                completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!self.isAvailable) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"SupabaseClient not available"}]);
        return;
    }
    NSMutableURLRequest *req = [self requestForPath:path];
    req.HTTPMethod = @"PATCH";
    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data,
          NSURLResponse *response, NSError *error) {
        [self handleResponse:data response:response error:error completion:completion];
    }] resume];
}

#pragma mark - Response Handling

- (void)handleResponse:(NSData *)data response:(NSURLResponse *)response
                  error:(NSError *)error completion:(void (^)(NSDictionary *, NSError *))completion {
    // Network error
    if (error) {
        if (completion) completion(nil, error);
        return;
    }

    // HTTP status check
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResponse.statusCode;

    // 401 — token expired, clear it
    if (statusCode == 401) {
        [self clearToken];
        if (completion) completion(nil, [NSError errorWithDomain:@"SupabaseClient" code:401
            userInfo:@{NSLocalizedDescriptionKey: @"Unauthorized — token expired or invalid"}]);

        return;
    }

    // No content (204) or empty response
    if (data.length == 0) {
        if (completion) completion(@{}, nil);
        return;
    }

    // Parse JSON
    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data
                                             options:NSJSONReadingMutableContainers
                                               error:&jsonError];
    if (jsonError) {
        if (completion) completion(nil, jsonError);
        return;
    }

    // Supabase REST returns array for list endpoints, single object for get-by-id,
    // or error object
    if ([json isKindOfClass:[NSArray class]]) {
        if (completion) completion(@{@"data": json}, nil);
    } else if ([json isKindOfClass:[NSDictionary class]]) {
        if (completion) completion(json, nil);
    } else {
        if (completion) completion(@{@"data": json}, nil);
    }
}

#pragma mark - Auth

- (void)authRequestWithPath:(NSString *)path body:(NSDictionary *)body
                 completion:(void (^)(NSDictionary *, NSError *))completion {
    if (!self.available) {
        if (completion) completion(nil, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"SupabaseClient not available"}]);
        return;
    }
    NSString *urlString = [NSString stringWithFormat:@"%@%@", self.baseURL, path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    // Auth endpoints use anon key, not Bearer token
    if (self.anonKey) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.anonKey]
   forHTTPHeaderField:@"Authorization"];
        [req setValue:self.anonKey forHTTPHeaderField:@"apikey"];
    }
    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data,
          NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if (httpResponse.statusCode >= 400) {
            NSString *errMsg = [NSString stringWithFormat:@"Auth failed: %ld",
                                (long)httpResponse.statusCode];
            NSError *authErr = [NSError errorWithDomain:@"SupabaseAuth" code:httpResponse.statusCode
                                              userInfo:@{NSLocalizedDescriptionKey: errMsg}];
            if (completion) completion(nil, authErr);
            return;
        }
        if (data.length == 0) {
            if (completion) completion(@{}, nil);
            return;
        }
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            if (completion) completion(nil, jsonError);
        } else if ([json isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(json, nil);
        } else {
            if (completion) completion(@{@"data": json}, nil);
        }
    }] resume];
}

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password
             completion:(void (^)(NSDictionary *, NSError *))completion {
    NSDictionary *body = @{@"email": email ?: @"", @"password": password ?: @""};
    [self authRequestWithPath:@"/auth/v1/signup" body:body completion:completion];
}

- (void)signInWithEmail:(NSString *)email password:(NSString *)password
             completion:(void (^)(NSDictionary *, NSError *))completion {
    NSDictionary *body = @{@"email": email ?: @"", @"password": password ?: @""};
    [self authRequestWithPath:@"/auth/v1/token?grant_type=password" body:body completion:completion];
}

#pragma mark - File Download (NSURLSessionDownloadDelegate)

- (void)downloadFile:(NSString *)remoteURL toPath:(NSString *)destPath
          completion:(void (^)(BOOL, NSError *))completion {
    if (!self.isAvailable) {
        if (completion) completion(NO, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"SupabaseClient not available"}]);
        return;
    }
    if (!remoteURL || !destPath) {
        if (completion) completion(NO, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters"}]);
        return;
    }

    NSURL *url = [NSURL URLWithString:remoteURL];
    if (!url) {
        if (completion) completion(NO, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}]);
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    // Auth for storage access
    NSString *token = [self getToken];
    if (token) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", token]
   forHTTPHeaderField:@"Authorization"];
    }

    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:req];
    NSDictionary *taskInfo = @{
        @"completion": [completion copy],
        @"destPath": destPath ?: @""
    };
    @synchronized(self) {
        self.downloadTasks[@(task.taskIdentifier)] = taskInfo;
    }
    [task resume];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                              didFinishDownloadingToURL:(NSURL *)location {
    NSDictionary *taskInfo = nil;
    @synchronized(self) {
        taskInfo = self.downloadTasks[@(downloadTask.taskIdentifier)];
        [self.downloadTasks removeObjectForKey:@(downloadTask.taskIdentifier)];
    }

    void (^completion)(BOOL, NSError *) = taskInfo[@"completion"];
    NSString *destPath = taskInfo[@"destPath"];

    if (!location || destPath.length == 0) {
        if (completion) completion(NO, [NSError errorWithDomain:@"SupabaseClient" code:-1
            userInfo:@{NSLocalizedDescriptionKey: @"Download failed or invalid path"}]);
        return;
    }

    NSString *dir = [destPath stringByDeletingLastPathComponent];
    if (dir) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
    }
    NSError *moveError = nil;
    BOOL moved = [[NSFileManager defaultManager] moveItemAtURL:location
                                                         toURL:[NSURL fileURLWithPath:destPath]
                                                         error:&moveError];
    if (completion) completion(moved, moveError);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                  didCompleteWithError:(NSError *)error {
    if (error) {
        NSDictionary *taskInfo = nil;
        @synchronized(self) {
            taskInfo = self.downloadTasks[@(task.taskIdentifier)];
            [self.downloadTasks removeObjectForKey:@(task.taskIdentifier)];
        }
        void (^completion)(BOOL, NSError *) = taskInfo[@"completion"];
        if (completion) completion(NO, error);
    }
}

#pragma mark - User ID & Progress

- (NSString *)currentUserIdFromToken {
    NSString *jwt = [self getToken];
    if (!jwt) return nil;

    NSArray *parts = [jwt componentsSeparatedByString:@"."];
    if (parts.count < 2) return nil;

    // Base64url-decode the payload (second part)
    NSString *payload = parts[1];
    payload = [payload stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    payload = [payload stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    // Pad to multiple of 4
    NSUInteger paddedLen = payload.length + (4 - (payload.length % 4)) % 4;
    if (paddedLen > payload.length) {
        payload = [payload stringByPaddingToLength:paddedLen withString:@"=" startingAtIndex:0];
    }

    NSData *data = [[NSData alloc] initWithBase64EncodedString:payload options:0];
    if (!data) return nil;

    NSError *err = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    if (!json || err) return nil;

    return json[@"sub"];
}

- (void)saveProgressWithFeature:(NSString *)feature bookNumber:(NSInteger)book
                   lessonNumber:(NSInteger)lesson wordIndex:(NSInteger)wordIndex
                     completion:(void (^)(NSError *))completion {
    if (!self.isAvailable) {
        if (completion) completion(nil); // silent skip when offline
        return;
    }

    NSString *userId = [self currentUserIdFromToken];
    if (!userId) {
        if (completion) completion(nil);
        return;
    }

    NSString *urlString = [NSString stringWithFormat:@"%@/rest/v1/user_progress", self.baseURL];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"resolution=merge-duplicates" forHTTPHeaderField:@"Prefer"];

    NSString *token = [self getToken];
    if (token) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    } else if (self.anonKey) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", self.anonKey] forHTTPHeaderField:@"Authorization"];
        [req setValue:self.anonKey forHTTPHeaderField:@"apikey"];
    }

    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    body[@"user_id"] = userId;
    body[@"feature"] = feature;
    body[@"book_number"] = @(book);
    body[@"lesson_number"] = @(lesson);
    if (wordIndex >= 0) body[@"word_index"] = @(wordIndex);
    body[@"updated_at"] = [[self class] iso8601String];

    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data,
          NSURLResponse *response, NSError *error) {
        if (completion) completion(error);
    }] resume];
}

+ (NSString *)iso8601String {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    fmt.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    return [fmt stringFromDate:[NSDate date]];
}

#pragma mark - Cleanup

- (void)dealloc {
    [self.session invalidateAndCancel];
}

@end

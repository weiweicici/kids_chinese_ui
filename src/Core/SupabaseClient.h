#import <Foundation/Foundation.h>

@interface SupabaseClient : NSObject

+ (instancetype)sharedClient;

// Graceful degradation: NO if network is unreachable or setup failed.
// All API calls check this first and return early if NO.
@property (readonly, nonatomic) BOOL isAvailable;

// Base URL for Supabase REST API, e.g. "https://xxxxx.supabase.co"
- (void)updateBaseURL:(NSString *)baseURL anonKey:(NSString *)anonKey;

// Token management
- (void)saveToken:(NSString *)jwt;
- (NSString *)getToken;
- (void)clearToken;
// Override the auth token for the next REST call only.
// Used by LoginVC to pass signIn token directly without storage.
- (void)useTemporaryToken:(NSString *)jwt;

// Role cache (Keychain, alongside token)
- (void)saveRole:(NSString *)role;
- (NSString *)getCachedRole;

// REST methods — callbacks fire on a serial background queue.
// Dispatch to main queue yourself if updating UI.
- (void)GET:(NSString *)path completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)POST:(NSString *)path body:(NSDictionary *)body completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)PATCH:(NSString *)path body:(NSDictionary *)body completion:(void (^)(NSDictionary *response, NSError *error))completion;

// Download file from Supabase Storage URL to local path.
// Uses NSURLSessionDownloadTask — streams directly to tmp/, zero RAM growth.
// On success, file is at destPath (atomic move from tmp/).
- (void)downloadFile:(NSString *)remoteURL toPath:(NSString *)destPath completion:(void (^)(BOOL success, NSError *error))completion;

// Auth methods — use anon key for Authorization, not Bearer token.
// Response includes access_token to be stored via saveToken:.
- (void)signUpWithEmail:(NSString *)email password:(NSString *)password
             completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)signUpWithEmail:(NSString *)email password:(NSString *)password
               username:(NSString *)username
             completion:(void (^)(NSDictionary *response, NSError *error))completion;
- (void)signInWithEmail:(NSString *)email password:(NSString *)password
             completion:(void (^)(NSDictionary *response, NSError *error))completion;

// Decode user ID ("sub") from stored JWT. Returns nil if no token or decode fails.
- (NSString *)currentUserIdFromToken;

// Save/update user_progress (upsert via merge-duplicates on unique user_id+feature).
// Pass wordIndex = -1 if not applicable.
- (void)saveProgressWithFeature:(NSString *)feature bookNumber:(NSInteger)book
                   lessonNumber:(NSInteger)lesson wordIndex:(NSInteger)wordIndex
                     completion:(void (^)(NSError *error))completion;

- (void)saveProgressWithFeature:(NSString *)feature bookNumber:(NSInteger)book
                   lessonNumber:(NSInteger)lesson wordIndex:(NSInteger)wordIndex
                  telemetryData:(NSArray *)telemetryData
                     completion:(void (^)(NSError *error))completion;

@end

#import "APIService.h"
#import "TLSHTTPClient.h"

static NSString *const kBaseURL = @"https://api.mangadex.org";

@interface APIService () <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation APIService

+ (instancetype)sharedService {
    static APIService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[APIService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 30.0;
        config.timeoutIntervalForResource = 60.0;
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return self;
}

#pragma mark - Custom Proxy / Server URL

- (NSString *)customServerURL {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"comico_custom_server_url"] ?: @"";
}

- (void)saveCustomServerURL:(NSString *)url {
    NSString *trimmed = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0) {
        if ([trimmed hasSuffix:@"/"]) {
            trimmed = [trimmed substringToIndex:trimmed.length - 1];
        }
        [[NSUserDefaults standardUserDefaults] setObject:trimmed forKey:@"comico_custom_server_url"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"comico_custom_server_url"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)effectiveBaseURL {
    NSString *custom = [self customServerURL];
    if (custom.length > 0) {
        return custom;
    }
    return kBaseURL;
}

- (NSString *)proxiedImageURL:(NSString *)originalURL {
    if (!originalURL || originalURL.length == 0) return originalURL;
    NSString *custom = [self customServerURL];
    if (custom.length > 0 && [originalURL hasPrefix:@"https://"]) {
        NSString *encoded = [originalURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        return [NSString stringWithFormat:@"%@/image?url=%@", custom, encoded];
    }
    return originalURL;
}

#pragma mark - NSURLSessionDelegate & TaskDelegate (Bypass de certificados SSL en iOS 9)

- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

#pragma mark - Public API

- (void)fetchComicsForCategory:(ComicCategory)category
                          page:(NSInteger)page
                    completion:(void(^)(NSArray<Comic *> *comics, NSError *error))completion {
    NSInteger limit = 20;
    NSInteger offset = page * limit;
    
    NSString *langParam = @"";
    switch (category) {
        case ComicCategoryWestern:
            langParam = @"&originalLanguage%5B%5D=en";
            break;
        case ComicCategoryManhwa:
            langParam = @"&originalLanguage%5B%5D=ko";
            break;
        case ComicCategoryManga:
            langParam = @"&originalLanguage%5B%5D=ja";
            break;
        case ComicCategoryManhua:
            langParam = @"&originalLanguage%5B%5D=zh";
            break;
        case ComicCategoryAll:
        default:
            langParam = @"";
            break;
    }
    
    // Usamos corchetes percent-encoded (%5B y %5D) para compatibilidad total con el parser de URLs de iOS 9
    NSString *urlStr = [NSString stringWithFormat:@"%@/manga?limit=%ld&offset=%ld&order%%5BfollowedCount%%5D=desc&includes%%5B%%5D=cover_art&includes%%5B%%5D=author&contentRating%%5B%%5D=safe&contentRating%%5B%%5D=suggestive%@", [self effectiveBaseURL], (long)limit, (long)offset, langParam];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    [self performDataTaskWithURL:url completion:^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSArray *data = json[@"data"];
        NSMutableArray<Comic *> *comics = [NSMutableArray array];
        if ([data isKindOfClass:[NSArray class]]) {
            for (NSDictionary *item in data) {
                Comic *c = [Comic comicFromMangaDexJSON:item];
                if (c) {
                    [comics addObject:c];
                }
            }
        }
        completion(comics, nil);
    }];
}

- (void)searchComicsWithQuery:(NSString *)query
                         page:(NSInteger)page
                   completion:(void(^)(NSArray<Comic *> *comics, NSError *error))completion {
    NSInteger limit = 20;
    NSInteger offset = page * limit;
    
    NSString *encodedQuery = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:@"%@/manga?title=%@&limit=%ld&offset=%ld&order%%5Brelevance%%5D=desc&includes%%5B%%5D=cover_art&includes%%5B%%5D=author&contentRating%%5B%%5D=safe&contentRating%%5B%%5D=suggestive", [self effectiveBaseURL], encodedQuery, (long)limit, (long)offset];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    [self performDataTaskWithURL:url completion:^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSArray *data = json[@"data"];
        NSMutableArray<Comic *> *comics = [NSMutableArray array];
        if ([data isKindOfClass:[NSArray class]]) {
            for (NSDictionary *item in data) {
                Comic *c = [Comic comicFromMangaDexJSON:item];
                if (c) {
                    [comics addObject:c];
                }
            }
        }
        completion(comics, nil);
    }];
}

- (void)fetchChaptersForComicId:(NSString *)comicId
                           page:(NSInteger)page
                     completion:(void(^)(NSArray<Chapter *> *chapters, NSError *error))completion {
    NSInteger limit = 100;
    NSInteger offset = page * limit;
    
    // Al estilo MangaBox: includeEmptyPages=0 para filtrar capítulos vacíos
    NSString *urlStr = [NSString stringWithFormat:@"%@/manga/%@/feed?limit=%ld&offset=%ld&translatedLanguage%%5B%%5D=es&translatedLanguage%%5B%%5D=es-la&translatedLanguage%%5B%%5D=en&order%%5Bchapter%%5D=asc&includeEmptyPages=0", [self effectiveBaseURL], comicId, (long)limit, (long)offset];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    [self performDataTaskWithURL:url completion:^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSArray *data = json[@"data"];
        NSMutableArray<Chapter *> *chapters = [NSMutableArray array];
        if ([data isKindOfClass:[NSArray class]]) {
            for (NSDictionary *item in data) {
                Chapter *ch = [Chapter chapterFromMangaDexJSON:item];
                if (ch) {
                    [chapters addObject:ch];
                }
            }
        }
        completion(chapters, nil);
    }];
}

- (void)fetchPagesForChapterId:(NSString *)chapterId
                    completion:(void(^)(NSArray<NSString *> *pageURLs, NSError *error))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/at-home/server/%@", [self effectiveBaseURL], chapterId];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    [self performDataTaskWithURL:url completion:^(NSDictionary *json, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSString *baseUrl = json[@"baseUrl"];
        NSDictionary *chapter = json[@"chapter"];
        if (!baseUrl || ![chapter isKindOfClass:[NSDictionary class]]) {
            NSError *err = [NSError errorWithDomain:@"com.comico" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Formato de respuesta inválido de páginas"}];
            completion(nil, err);
            return;
        }
        
        NSString *hash = chapter[@"hash"];
        if (!hash || hash.length == 0) {
            NSError *err = [NSError errorWithDomain:@"com.comico" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Capítulo sin hash de imágenes"}];
            completion(nil, err);
            return;
        }
        
        NSArray *dataSaver = chapter[@"dataSaver"];
        NSArray *data = chapter[@"data"];
        
        NSMutableArray<NSString *> *urls = [NSMutableArray array];
        
        // Lógica idéntica a MangaBox (0x4e7f6): preferir data-saver comprimido para ahorrar RAM en iOS 9
        if ([dataSaver isKindOfClass:[NSArray class]] && dataSaver.count > 0) {
            for (NSString *fn in dataSaver) {
                NSString *pUrl = [NSString stringWithFormat:@"%@/data-saver/%@/%@", baseUrl, hash, fn];
                [urls addObject:[self proxiedImageURL:pUrl]];
            }
        } else if ([data isKindOfClass:[NSArray class]] && data.count > 0) {
            for (NSString *fn in data) {
                NSString *pUrl = [NSString stringWithFormat:@"%@/data/%@/%@", baseUrl, hash, fn];
                [urls addObject:[self proxiedImageURL:pUrl]];
            }
        }
        
        if (urls.count == 0) {
            NSError *err = [NSError errorWithDomain:@"com.comico" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"Capítulo sin páginas disponibles"}];
            completion(nil, err);
            return;
        }
        
        completion(urls, nil);
    }];
}

- (void)performDataTaskWithURL:(NSURL *)url completion:(void(^)(NSDictionary *json, NSError *error))completion {
    if (!url) {
        NSError *err = [NSError errorWithDomain:@"com.comico" code:-100 userInfo:@{NSLocalizedDescriptionKey: @"URL inválida"}];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, err);
        });
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Comico/1.0 (iOS 9.0; iPad; +https://github.com/ElDeluxo/comico)" forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [[TLSHTTPClient sharedClient] performRequest:req completion:^(NSData *data, NSHTTPURLResponse *httpRes, NSError *netError) {
        if (netError) {
            completion(nil, netError);
            return;
        }
        
        if (httpRes && (httpRes.statusCode < 200 || httpRes.statusCode >= 300)) {
            NSError *err = [NSError errorWithDomain:@"com.comico" code:httpRes.statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error HTTP %ld al conectar con MangaDex", (long)httpRes.statusCode]}];
            completion(nil, err);
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
            completion(nil, jsonError ?: [NSError errorWithDomain:@"com.comico" code:-101 userInfo:@{NSLocalizedDescriptionKey: @"Error al procesar JSON"}]);
            return;
        }
        
        completion(json, nil);
    }];
}

@end

#import "APIService.h"

static NSString *const kBaseURL = @"https://api.mangadex.org";

@interface APIService ()
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
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (void)fetchPopularComicsPage:(NSInteger)page
                    completion:(void(^)(NSArray<Comic *> *comics, NSError *error))completion {
    NSInteger limit = 20;
    NSInteger offset = page * limit;
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/manga?limit=%ld&offset=%ld&order[followedCount]=desc&includes[]=cover_art&includes[]=author&contentRating[]=safe&contentRating[]=suggestive", kBaseURL, (long)limit, (long)offset];
    
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
    NSString *urlStr = [NSString stringWithFormat:@"%@/manga?title=%@&limit=%ld&offset=%ld&order[relevance]=desc&includes[]=cover_art&includes[]=author&contentRating[]=safe&contentRating[]=suggestive", kBaseURL, encodedQuery, (long)limit, (long)offset];
    
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
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/manga/%@/feed?limit=%ld&offset=%ld&translatedLanguage[]=es&translatedLanguage[]=en&order[chapter]=asc", kBaseURL, comicId, (long)limit, (long)offset];
    
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
    NSString *urlStr = [NSString stringWithFormat:@"%@/at-home/server/%@", kBaseURL, chapterId];
    
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
        // Prioritize dataSaver on legacy devices to conserve memory and bandwidth
        NSArray *filenames = chapter[@"dataSaver"] ?: chapter[@"data"];
        NSString *qualityFolder = (chapter[@"dataSaver"] != nil) ? @"data-saver" : @"data";
        
        if (!hash || ![filenames isKindOfClass:[NSArray class]]) {
            NSError *err = [NSError errorWithDomain:@"com.comico" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Capítulo sin páginas disponibles"}];
            completion(nil, err);
            return;
        }
        
        NSMutableArray<NSString *> *urls = [NSMutableArray array];
        for (NSString *fn in filenames) {
            NSString *pUrl = [NSString stringWithFormat:@"%@/%@/%@/%@", baseUrl, qualityFolder, hash, fn];
            [urls addObject:pUrl];
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
    [req setValue:@"Comico-iOS9/1.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *netError) {
        if (netError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, netError);
            });
            return;
        }
        
        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, jsonError ?: [NSError errorWithDomain:@"com.comico" code:-101 userInfo:@{NSLocalizedDescriptionKey: @"Error al procesar JSON"}]);
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(json, nil);
        });
    }];
    [task resume];
}

@end

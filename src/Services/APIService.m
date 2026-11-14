#import "APIService.h"
#import "TLSHTTPClient.h"
#import "DebugViewController.h"

static NSString *const kBaseURL = @"https://api.mangadex.org";

@interface APIService () <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@property(nonatomic, strong) NSURLSession *session;
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
    NSURLSessionConfiguration *config =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    config.timeoutIntervalForResource = 60.0;
    _session = [NSURLSession sessionWithConfiguration:config
                                             delegate:self
                                        delegateQueue:nil];
  }
  return self;
}

#pragma mark - Custom Proxy / Server URL

- (NSString *)customServerURL {
  return [[NSUserDefaults standardUserDefaults]
             stringForKey:@"comico_custom_server_url"]
             ?: @"";
}

- (void)saveCustomServerURL:(NSString *)url {
  NSString *trimmed = [url
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  if (trimmed.length > 0) {
    if ([trimmed hasSuffix:@"/"]) {
      trimmed = [trimmed substringToIndex:trimmed.length - 1];
    }
    [[NSUserDefaults standardUserDefaults]
        setObject:trimmed
           forKey:@"comico_custom_server_url"];
  } else {
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey:@"comico_custom_server_url"];
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
  if (!originalURL || originalURL.length == 0)
    return originalURL;
  NSString *custom = [self customServerURL];
  if (custom.length > 0 && [originalURL hasPrefix:@"https://"]) {
    NSString *encoded =
        [originalURL stringByAddingPercentEncodingWithAllowedCharacters:
                         [NSCharacterSet URLQueryAllowedCharacterSet]];
    return [NSString stringWithFormat:@"%@/image?url=%@", custom, encoded];
  }
  return originalURL;
}

#pragma mark - NSURLSessionDelegate & TaskDelegate (Bypass de certificados SSL en iOS 9)

- (void)URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:
          (void (^)(NSURLSessionAuthChallengeDisposition disposition,
                    NSURLCredential *credential))completionHandler {
  if ([challenge.protectionSpace.authenticationMethod
          isEqualToString:NSURLAuthenticationMethodServerTrust]) {
    completionHandler(
        NSURLSessionAuthChallengeUseCredential,
        [NSURLCredential
            credentialForTrust:challenge.protectionSpace.serverTrust]);
  } else {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
  }
}

- (void)URLSession:(NSURLSession *)session
                   task:(NSURLSessionTask *)task
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:
          (void (^)(NSURLSessionAuthChallengeDisposition disposition,
                    NSURLCredential *credential))completionHandler {
  if ([challenge.protectionSpace.authenticationMethod
          isEqualToString:NSURLAuthenticationMethodServerTrust]) {
    completionHandler(
        NSURLSessionAuthChallengeUseCredential,
        [NSURLCredential
            credentialForTrust:challenge.protectionSpace.serverTrust]);
  } else {
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
  }
}

#pragma mark - Public API

- (void)fetchComicsForCategory:(ComicCategory)category
                          page:(NSInteger)page
                    completion:(void (^)(NSArray<Comic *> *comics,
                                         NSError *error))completion {
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

  // Usamos corchetes percent-encoded (%5B y %5D) para compatibilidad total con
  // el parser de URLs de iOS 9
  NSString *urlStr = [NSString
      stringWithFormat:
          @"%@/"
          @"manga?limit=%ld&offset=%ld&order%%5BfollowedCount%%5D=desc&"
          @"includes%%5B%%5D=cover_art&includes%%5B%%5D=author&contentRating%%"
          @"5B%%5D=safe&contentRating%%5B%%5D=suggestive%@",
          [self effectiveBaseURL], (long)limit, (long)offset, langParam];

  NSURL *url = [NSURL URLWithString:urlStr];
  [self performDataTaskWithURL:url
                    completion:^(NSDictionary *json, NSError *error) {
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
                   completion:(void (^)(NSArray<Comic *> *comics,
                                        NSError *error))completion {
  NSInteger limit = 20;
  NSInteger offset = page * limit;

  NSString *encodedQuery =
      [query stringByAddingPercentEncodingWithAllowedCharacters:
                 [NSCharacterSet URLQueryAllowedCharacterSet]];
  NSString *urlStr = [NSString
      stringWithFormat:
          @"%@/"
          @"manga?title=%@&limit=%ld&offset=%ld&order%%5Brelevance%%5D=desc&"
          @"includes%%5B%%5D=cover_art&includes%%5B%%5D=author&contentRating%%"
          @"5B%%5D=safe&contentRating%%5B%%5D=suggestive",
          [self effectiveBaseURL], encodedQuery, (long)limit, (long)offset];

  NSURL *url = [NSURL URLWithString:urlStr];
  [self performDataTaskWithURL:url
                    completion:^(NSDictionary *json, NSError *error) {
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
    // 1. Cómics Occidentales de Internet Archive
    if ([comicId hasPrefix:@"ia_"]) {
        NSString *ident = [comicId substringFromIndex:3];
        NSString *urlStr = [NSString stringWithFormat:@"https://archive.org/metadata/%@", ident];
        NSURL *url = [NSURL URLWithString:urlStr];
        [self performDataTaskWithURL:url completion:^(NSDictionary *json, NSError *error) {
            if (error || !json) {
                completion(@[], error);
                return;
            }
            
            NSArray *files = json[@"files"];
            NSMutableArray<NSDictionary *> *jp2Files = [NSMutableArray array];
            NSMutableArray<NSString *> *pdfFiles = [NSMutableArray array];
            
            if ([files isKindOfClass:[NSArray class]]) {
                for (NSDictionary *f in files) {
                    NSString *fn = f[@"name"];
                    if (![fn isKindOfClass:[NSString class]]) continue;
                    
                    if ([fn hasSuffix:@"_jp2.zip"]) {
                        [jp2Files addObject:f];
                    } else if ([fn hasSuffix:@".pdf"] && ![fn hasSuffix:@"_text.pdf"]) {
                        [pdfFiles addObject:fn];
                    }
                }
            }
            
            NSMutableArray<Chapter *> *chapters = [NSMutableArray array];
            
            if (jp2Files.count > 1) {
                // Caso A: Múltiples tomos/números con archivos procesados independientes (ej: Batman 001..050)
                [jp2Files sortUsingComparator:^NSComparisonResult(NSDictionary *d1, NSDictionary *d2) {
                    NSString *n1 = [d1 isKindOfClass:[NSDictionary class]] ? d1[@"name"] : nil;
                    NSString *n2 = [d2 isKindOfClass:[NSDictionary class]] ? d2[@"name"] : nil;
                    if (![n1 isKindOfClass:[NSString class]]) return NSOrderedAscending;
                    if (![n2 isKindOfClass:[NSString class]]) return NSOrderedDescending;
                    return [n1 compare:n2];
                }];
                
                for (NSInteger i = 0; i < jp2Files.count; i++) {
                    NSDictionary *f = jp2Files[i];
                    NSString *fn = f[@"name"];
                    NSString *baseName = [fn stringByReplacingOccurrencesOfString:@"_jp2.zip" withString:@""];
                    NSInteger count = [f[@"filecount"] integerValue];
                    if (count <= 0) count = 35;
                    
                    Chapter *ch = [[Chapter alloc] init];
                    ch.chapterId = [NSString stringWithFormat:@"ia__%@__sub__%@__%ld", ident, [baseName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], (long)count];
                    ch.chapterNumber = [NSString stringWithFormat:@"%ld", (long)(i + 1)];
                    ch.title = baseName;
                    ch.language = @"en";
                    ch.pagesCount = count;
                    [chapters addObject:ch];
                }
            } else if (pdfFiles.count > 1) {
                // Caso B: Múltiples PDFs sin _jp2.zip individuales
                [pdfFiles sortUsingComparator:^NSComparisonResult(id s1, id s2) {
                    if (![s1 isKindOfClass:[NSString class]]) return NSOrderedAscending;
                    if (![s2 isKindOfClass:[NSString class]]) return NSOrderedDescending;
                    return [(NSString *)s1 compare:(NSString *)s2];
                }];
                for (NSInteger i = 0; i < pdfFiles.count; i++) {
                    NSString *pdf = pdfFiles[i];
                    NSString *baseName = [pdf stringByReplacingOccurrencesOfString:@".pdf" withString:@""];
                    Chapter *ch = [[Chapter alloc] init];
                    ch.chapterId = [NSString stringWithFormat:@"ia__%@__sub__%@__35", ident, [baseName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
                    ch.chapterNumber = [NSString stringWithFormat:@"%ld", (long)(i + 1)];
                    ch.title = baseName;
                    ch.language = @"en";
                    ch.pagesCount = 35;
                    [chapters addObject:ch];
                }
            } else {
                // Caso C: Libro o cómic individual (ej: Watchmen completo, The Killing Joke)
                NSInteger totalPages = 0;
                if (jp2Files.count == 1) {
                    totalPages = [jp2Files[0][@"filecount"] integerValue];
                }
                if (totalPages <= 0) {
                    totalPages = [json[@"metadata"][@"imagecount"] integerValue];
                }
                if (totalPages <= 0) {
                    totalPages = 36;
                }
                
                id rawMetaTitle = json[@"metadata"][@"title"];
                NSString *metaTitle = @"Novela Gráfica Completa";
                if ([rawMetaTitle isKindOfClass:[NSString class]]) {
                    metaTitle = rawMetaTitle;
                } else if ([rawMetaTitle isKindOfClass:[NSArray class]] && [rawMetaTitle count] > 0) {
                    metaTitle = [NSString stringWithFormat:@"%@", [rawMetaTitle firstObject]];
                }
                
                if (totalPages <= 64) {
                    Chapter *ch = [[Chapter alloc] init];
                    ch.chapterId = [NSString stringWithFormat:@"ia__%@__range__0__%ld", ident, (long)totalPages];
                    ch.chapterNumber = @"1";
                    ch.title = metaTitle;
                    ch.language = @"en";
                    ch.pagesCount = totalPages;
                    [chapters addObject:ch];
                } else {
                    NSInteger chunkSize = 34;
                    NSInteger numChapters = (totalPages + chunkSize - 1) / chunkSize;
                    for (NSInteger i = 0; i < numChapters; i++) {
                        NSInteger start = i * chunkSize;
                        NSInteger count = MIN(chunkSize, totalPages - start);
                        Chapter *ch = [[Chapter alloc] init];
                        ch.chapterId = [NSString stringWithFormat:@"ia__%@__range__%ld__%ld", ident, (long)start, (long)count];
                        ch.chapterNumber = [NSString stringWithFormat:@"%ld", (long)(i + 1)];
                        ch.title = [NSString stringWithFormat:@"Issue #%ld (Páginas %ld-%ld)", (long)(i + 1), (long)(start + 1), (long)(start + count)];
                        ch.language = @"en";
                        ch.pagesCount = count;
                        [chapters addObject:ch];
                    }
                }
            }
            completion(chapters, nil);
        }];
        return;
    }
    
    // 2. Mangas de MangaDex
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
                    completion:(void (^)(NSArray<NSString *> *pageURLs,
                                         NSError *error))completion {
  if (!chapterId || ![chapterId isKindOfClass:[NSString class]]) {
    if (completion) completion(@[], nil);
    return;
  }

  // 1. Cómics Occidentales de Internet Archive
  if ([chapterId hasPrefix:@"ia__"]) {
    NSArray<NSString *> *parts = [chapterId componentsSeparatedByString:@"__"];
    if (parts.count >= 5 && [parts[2] isEqualToString:@"range"]) {
      NSString *ident = parts[1];
      NSInteger start = [parts[3] integerValue];
      NSInteger count = [parts[4] integerValue];
      NSMutableArray<NSString *> *urls = [NSMutableArray array];
      for (NSInteger p = 0; p < count; p++) {
        NSInteger actualPage = start + p;
        NSString *pUrl = [NSString stringWithFormat:@"https://archive.org/download/%@/page/n%ld.jpg", ident, (long)actualPage];
        [urls addObject:[self proxiedImageURL:pUrl]];
      }
      completion(urls, nil);
      return;
    } else if (parts.count >= 5 && [parts[2] isEqualToString:@"sub"]) {
      NSString *ident = parts[1];
      NSString *subPrefix = [parts[3] stringByRemovingPercentEncoding] ?: parts[3];
      NSInteger count = [parts[4] integerValue];
      if (count <= 0) count = 35;
      NSMutableArray<NSString *> *urls = [NSMutableArray array];
      for (NSInteger p = 0; p < count; p++) {
        NSString *encodedPrefix = [subPrefix stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
        NSString *pUrl = [NSString stringWithFormat:@"https://archive.org/download/%@/%@/page/n%ld.jpg", ident, encodedPrefix, (long)p];
        [urls addObject:[self proxiedImageURL:pUrl]];
      }
      completion(urls, nil);
      return;
    } else if (parts.count >= 2) {
      NSString *ident = parts[1];
      NSMutableArray<NSString *> *urls = [NSMutableArray array];
      for (NSInteger p = 0; p < 35; p++) {
        NSString *pUrl = [NSString stringWithFormat:@"https://archive.org/download/%@/page/n%ld.jpg", ident, (long)p];
        [urls addObject:[self proxiedImageURL:pUrl]];
      }
      completion(urls, nil);
      return;
    }
  }

  // 2. Mangas de MangaDex
  NSString *urlStr =
      [NSString stringWithFormat:@"%@/at-home/server/%@",
                                 [self effectiveBaseURL], chapterId];

  NSURL *url = [NSURL URLWithString:urlStr];
  [self performDataTaskWithURL:url
                    completion:^(NSDictionary *json, NSError *error) {
                      if (error) {
                        completion(nil, error);
                        return;
                      }

                      NSString *baseUrl = json[@"baseUrl"];
                      NSDictionary *chapter = json[@"chapter"];
                      if (!baseUrl ||
                          ![chapter isKindOfClass:[NSDictionary class]]) {
                        NSError *err =
                            [NSError errorWithDomain:@"com.comico"
                                                code:-1
                                            userInfo:@{
                                              NSLocalizedDescriptionKey :
                                                  @"Formato de respuesta "
                                                  @"inválido de páginas"
                                            }];
                        completion(nil, err);
                        return;
                      }

                      NSString *hash = chapter[@"hash"];
                      if (!hash || hash.length == 0) {
                        NSError *err = [NSError
                            errorWithDomain:@"com.comico"
                                       code:-2
                                   userInfo:@{
                                     NSLocalizedDescriptionKey :
                                         @"Capítulo sin hash de imágenes"
                                   }];
                        completion(nil, err);
                        return;
                      }

                      NSArray *dataSaver = chapter[@"dataSaver"];
                      NSArray *data = chapter[@"data"];

                      NSMutableArray<NSString *> *urls = [NSMutableArray array];

                      // Lógica idéntica a MangaBox (0x4e7f6): preferir
                      // data-saver comprimido para ahorrar RAM en iOS 9
                      if ([dataSaver isKindOfClass:[NSArray class]] &&
                          dataSaver.count > 0) {
                        for (NSString *fn in dataSaver) {
                          NSString *pUrl =
                              [NSString stringWithFormat:@"%@/data-saver/%@/%@",
                                                         baseUrl, hash, fn];
                          [urls addObject:[self proxiedImageURL:pUrl]];
                        }
                      } else if ([data isKindOfClass:[NSArray class]] &&
                                 data.count > 0) {
                        for (NSString *fn in data) {
                          NSString *pUrl =
                              [NSString stringWithFormat:@"%@/data/%@/%@",
                                                         baseUrl, hash, fn];
                          [urls addObject:[self proxiedImageURL:pUrl]];
                        }
                      }

                      if (urls.count == 0) {
                        NSError *err = [NSError
                            errorWithDomain:@"com.comico"
                                       code:-3
                                   userInfo:@{
                                     NSLocalizedDescriptionKey :
                                         @"Capítulo sin páginas disponibles"
                                   }];
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
        if (netError || !data || data.length == 0) {
            completion(nil, netError ?: [NSError errorWithDomain:@"com.comico" code:-102 userInfo:@{NSLocalizedDescriptionKey: @"Respuesta sin datos"}]);
            return;
        }
        
        if (httpRes && (httpRes.statusCode < 200 || httpRes.statusCode >= 300)) {
            NSError *err = [NSError errorWithDomain:@"com.comico" code:httpRes.statusCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Error HTTP %ld", (long)httpRes.statusCode]}];
            completion(nil, err);
            return;
        }
        
        @try {
            NSError *jsonError = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"com.comico" code:-101 userInfo:@{NSLocalizedDescriptionKey: @"Error al procesar JSON"}]);
                return;
            }
            completion(json, nil);
        } @catch (NSException *ex) {
            ComicoLog(@"❌ Excepción al procesar JSON: %@", ex.reason);
            completion(nil, [NSError errorWithDomain:@"com.comico" code:-103 userInfo:@{NSLocalizedDescriptionKey: ex.reason ?: @"Error JSON"}]);
        }
    }];
}

@end

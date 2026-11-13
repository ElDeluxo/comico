#import "ImageCache.h"
#import "APIService.h"
#import <CommonCrypto/CommonDigest.h>

@interface ImageCache () <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@property (nonatomic, strong) NSCache *memCache;
@property (nonatomic, copy) NSString *diskCachePath;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation ImageCache

+ (instancetype)sharedCache {
    static ImageCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ImageCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memCache = [[NSCache alloc] init];
        _memCache.countLimit = 60;
        _memCache.totalCostLimit = 20 * 1024 * 1024; // 20 MB RAM max
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCachePath = [[paths firstObject] stringByAppendingPathComponent:@"ComicoImages"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
        
        _ioQueue = dispatch_queue_create("com.comico.imagecache.io", DISPATCH_QUEUE_SERIAL);
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 25.0;
        config.timeoutIntervalForResource = 60.0;
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleMemoryWarning {
    [self.memCache removeAllObjects];
}

#pragma mark - NSURLSessionDelegate (Aceptar certificados SSL modernos en iOS 9)

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

- (NSString *)cacheKeyForURL:(NSString *)urlString {
    const char *str = [urlString UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);
    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", result[i]];
    }
    return hash;
}

- (NSString *)filePathForURL:(NSString *)urlString {
    NSString *key = [self cacheKeyForURL:urlString];
    return [self.diskCachePath stringByAppendingPathComponent:key];
}

- (UIImage *)imageForURL:(NSString *)urlString {
    if (!urlString || urlString.length == 0) return nil;
    
    UIImage *img = [self.memCache objectForKey:urlString];
    if (img) return img;
    
    NSString *path = [self filePathForURL:urlString];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data) {
        img = [UIImage imageWithData:data];
        if (img) {
            [self.memCache setObject:img forKey:urlString cost:data.length];
            return img;
        }
    }
    return nil;
}

- (void)setImage:(UIImage *)image forURL:(NSString *)urlString {
    if (!image || !urlString || urlString.length == 0) return;
    
    [self.memCache setObject:image forKey:urlString];
    
    dispatch_async(self.ioQueue, ^{
        NSString *path = [self filePathForURL:urlString];
        NSData *data = UIImageJPEGRepresentation(image, 0.85);
        [data writeToFile:path atomically:YES];
    });
}

- (void)loadImageForURL:(NSString *)urlString completion:(void(^)(UIImage *image))completion {
    if (!urlString || urlString.length == 0) {
        if (completion) completion(nil);
        return;
    }
    
    // 1. RAM Cache
    UIImage *cachedImg = [self.memCache objectForKey:urlString];
    if (cachedImg) {
        if (completion) completion(cachedImg);
        return;
    }
    
    // 2. Disk Cache
    dispatch_async(self.ioQueue, ^{
        NSString *path = [self filePathForURL:urlString];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            if (img) {
                [self.memCache setObject:img forKey:urlString cost:data.length];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(img);
                });
                return;
            }
        }
        
        // 3. Network Fetch con User-Agent
        NSString *targetURL = [[APIService sharedService] proxiedImageURL:urlString];
        NSURL *url = [NSURL URLWithString:targetURL];
        if (!url) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
            return;
        }
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        [req setValue:@"Comico/1.0 (iOS 9.0; iPad; +https://github.com/ElDeluxo/comico)" forHTTPHeaderField:@"User-Agent"];
        
        NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *res, NSError *err) {
            if (d && !err) {
                UIImage *downloaded = [UIImage imageWithData:d];
                if (downloaded) {
                    [self.memCache setObject:downloaded forKey:urlString cost:d.length];
                    [d writeToFile:path atomically:YES];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) completion(downloaded);
                    });
                    return;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
        }];
        [task resume];
    });
}

@end

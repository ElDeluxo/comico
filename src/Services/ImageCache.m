#import "ImageCache.h"
#import <CommonCrypto/CommonDigest.h>

@interface ImageCache ()
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
        _memCache.countLimit = 60; // Safe for 32-bit legacy devices
        _memCache.totalCostLimit = 20 * 1024 * 1024; // 20 MB max in RAM
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCachePath = [[paths firstObject] stringByAppendingPathComponent:@"ComicoImages"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
        
        _ioQueue = dispatch_queue_create("com.comico.imagecache.io", DISPATCH_QUEUE_SERIAL);
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 25.0;
        config.timeoutIntervalForResource = 60.0;
        _session = [NSURLSession sessionWithConfiguration:config];
        
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
    
    // Check RAM
    UIImage *img = [self.memCache objectForKey:urlString];
    if (img) return img;
    
    // Check Disk
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
    
    // 1. RAM Cache check
    UIImage *cachedImg = [self.memCache objectForKey:urlString];
    if (cachedImg) {
        if (completion) completion(cachedImg);
        return;
    }
    
    // 2. Disk Cache check
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
        
        // 3. Network Fetch
        NSURL *url = [NSURL URLWithString:urlString];
        if (!url) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil);
            });
            return;
        }
        
        NSURLSessionDataTask *task = [self.session dataTaskWithURL:url completionHandler:^(NSData *d, NSURLResponse *res, NSError *err) {
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

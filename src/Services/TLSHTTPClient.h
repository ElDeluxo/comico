#import <Foundation/Foundation.h>

@interface TLSHTTPClient : NSObject

+ (instancetype)sharedClient;

- (void)performRequest:(NSURLRequest *)request
            completion:(void(^)(NSData *data, NSHTTPURLResponse *response, NSError *error))completion;

- (void)fetchURL:(NSURL *)url
         headers:(NSDictionary<NSString *, NSString *> *)headers
      completion:(void(^)(NSData *data, NSHTTPURLResponse *response, NSError *error))completion;

@end

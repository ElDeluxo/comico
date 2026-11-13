#import <UIKit/UIKit.h>

@interface ImageCache : NSObject

+ (instancetype)sharedCache;

- (UIImage *)imageForURL:(NSString *)urlString;
- (void)setImage:(UIImage *)image forURL:(NSString *)urlString;
- (void)loadImageForURL:(NSString *)urlString completion:(void(^)(UIImage *image))completion;

@end

#import <Foundation/Foundation.h>
#import "Comic.h"
#import "Chapter.h"

@interface APIService : NSObject

+ (instancetype)sharedService;

- (void)fetchPopularComicsPage:(NSInteger)page
                    completion:(void(^)(NSArray<Comic *> *comics, NSError *error))completion;

- (void)searchComicsWithQuery:(NSString *)query
                         page:(NSInteger)page
                   completion:(void(^)(NSArray<Comic *> *comics, NSError *error))completion;

- (void)fetchChaptersForComicId:(NSString *)comicId
                           page:(NSInteger)page
                     completion:(void(^)(NSArray<Chapter *> *chapters, NSError *error))completion;

- (void)fetchPagesForChapterId:(NSString *)chapterId
                    completion:(void(^)(NSArray<NSString *> *pageURLs, NSError *error))completion;

@end


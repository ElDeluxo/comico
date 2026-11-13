#import <Foundation/Foundation.h>
#import "Comic.h"
#import "Chapter.h"

typedef NS_ENUM(NSInteger, ComicCategory) {
    ComicCategoryAll = 0,        // Todos los cómics y mangas
    ComicCategoryWestern = 1,    // Cómics occidentales, americanos e indie (en)
    ComicCategoryManhwa = 2,     // Webtoons y Manhwa coreanos (ko)
    ComicCategoryManga = 3,      // Manga japonés (ja)
    ComicCategoryManhua = 4      // Manhua chino (zh)
};

@interface APIService : NSObject

+ (instancetype)sharedService;

@property (nonatomic, copy) NSString *customServerURL;
- (NSString *)effectiveBaseURL;
- (void)saveCustomServerURL:(NSString *)url;
- (NSString *)proxiedImageURL:(NSString *)originalURL;

- (void)fetchComicsForCategory:(ComicCategory)category
                          page:(NSInteger)page
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

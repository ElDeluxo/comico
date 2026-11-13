#import <Foundation/Foundation.h>
#import "Comic.h"

@interface FavoritesManager : NSObject

+ (instancetype)sharedManager;

- (NSArray<Comic *> *)allFavorites;
- (BOOL)isFavorite:(NSString *)comicId;
- (void)addFavorite:(Comic *)comic;
- (void)removeFavorite:(NSString *)comicId;
- (void)toggleFavorite:(Comic *)comic;

@end

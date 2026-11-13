#import "FavoritesManager.h"

static NSString *const kFavoritesKey = @"comico_saved_favorites";

@implementation FavoritesManager

+ (instancetype)sharedManager {
    static FavoritesManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FavoritesManager alloc] init];
    });
    return instance;
}

- (NSArray<Comic *> *)allFavorites {
    NSArray *rawList = [[NSUserDefaults standardUserDefaults] arrayForKey:kFavoritesKey];
    if (!rawList) return @[];
    
    NSMutableArray<Comic *> *comics = [NSMutableArray array];
    for (NSDictionary *dict in rawList) {
        Comic *c = [Comic fromDictionary:dict];
        if (c) {
            [comics addObject:c];
        }
    }
    return comics;
}

- (BOOL)isFavorite:(NSString *)comicId {
    if (!comicId) return NO;
    NSArray *rawList = [[NSUserDefaults standardUserDefaults] arrayForKey:kFavoritesKey];
    for (NSDictionary *dict in rawList) {
        if ([dict[@"id"] isEqualToString:comicId]) {
            return YES;
        }
    }
    return NO;
}

- (void)addFavorite:(Comic *)comic {
    if (!comic || !comic.comicId) return;
    if ([self isFavorite:comic.comicId]) return;
    
    NSArray *rawList = [[NSUserDefaults standardUserDefaults] arrayForKey:kFavoritesKey] ?: @[];
    NSMutableArray *updated = [rawList mutableCopy];
    [updated insertObject:[comic toDictionary] atIndex:0];
    
    [[NSUserDefaults standardUserDefaults] setObject:updated forKey:kFavoritesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)removeFavorite:(NSString *)comicId {
    if (!comicId) return;
    NSArray *rawList = [[NSUserDefaults standardUserDefaults] arrayForKey:kFavoritesKey];
    if (!rawList) return;
    
    NSMutableArray *updated = [NSMutableArray array];
    for (NSDictionary *dict in rawList) {
        if (![dict[@"id"] isEqualToString:comicId]) {
            [updated addObject:dict];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:updated forKey:kFavoritesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)toggleFavorite:(Comic *)comic {
    if (!comic || !comic.comicId) return;
    if ([self isFavorite:comic.comicId]) {
        [self removeFavorite:comic.comicId];
    } else {
        [self addFavorite:comic];
    }
}

@end


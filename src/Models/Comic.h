#import <Foundation/Foundation.h>

@interface Comic : NSObject

@property (nonatomic, copy) NSString *comicId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *comicDescription;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, copy) NSString *coverURL;
@property (nonatomic, copy) NSString *originalLanguage;
@property (nonatomic, copy) NSString *originBadge;
@property (nonatomic, copy) NSArray<NSString *> *tags;

+ (instancetype)comicFromMangaDexJSON:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

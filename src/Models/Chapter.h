#import <Foundation/Foundation.h>

@interface Chapter : NSObject

@property (nonatomic, copy) NSString *chapterId;
@property (nonatomic, copy) NSString *chapterNumber;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, assign) NSInteger pagesCount;

+ (instancetype)chapterFromMangaDexJSON:(NSDictionary *)dict;

@end

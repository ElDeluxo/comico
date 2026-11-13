#import "Chapter.h"

@implementation Chapter

+ (instancetype)chapterFromMangaDexJSON:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    Chapter *ch = [[Chapter alloc] init];
    ch.chapterId = dict[@"id"];
    
    NSDictionary *attrs = dict[@"attributes"];
    if ([attrs isKindOfClass:[NSDictionary class]]) {
        id chNum = attrs[@"chapter"];
        if (chNum && chNum != [NSNull null]) {
            ch.chapterNumber = [NSString stringWithFormat:@"%@", chNum];
        } else {
            ch.chapterNumber = @"-";
        }
        
        id titleObj = attrs[@"title"];
        if (titleObj && titleObj != [NSNull null] && [titleObj isKindOfClass:[NSString class]] && [titleObj length] > 0) {
            ch.title = titleObj;
        } else {
            ch.title = [NSString stringWithFormat:@"Capítulo %@", ch.chapterNumber];
        }
        
        ch.language = attrs[@"translatedLanguage"] ?: @"es";
        ch.pagesCount = [attrs[@"pages"] integerValue];
    }
    
    return ch;
}

@end


#import "Chapter.h"

@implementation Chapter

+ (instancetype)chapterFromMangaDexJSON:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    NSDictionary *attrs = dict[@"attributes"];
    if (![attrs isKindOfClass:[NSDictionary class]]) return nil;
    
    // Ignorar capítulos externos (ej: MangaPlus/Bilibili que no tienen páginas en MangaDex)
    id extUrl = attrs[@"externalUrl"];
    if (extUrl && extUrl != [NSNull null] && [extUrl isKindOfClass:[NSString class]] && [extUrl length] > 0) {
        return nil;
    }
    
    id cId = dict[@"id"];
    if (![cId isKindOfClass:[NSString class]] || [cId length] == 0) return nil;
    
    Chapter *ch = [[Chapter alloc] init];
    ch.chapterId = cId;
    
    id chNum = attrs[@"chapter"];
    if (chNum && chNum != [NSNull null] && [chNum isKindOfClass:[NSString class]]) {
        ch.chapterNumber = chNum;
    } else if (chNum && chNum != [NSNull null]) {
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
    
    id langObj = attrs[@"translatedLanguage"];
    if (langObj && langObj != [NSNull null] && [langObj isKindOfClass:[NSString class]] && [langObj length] > 0) {
        ch.language = langObj;
    } else {
        ch.language = @"es";
    }
    
    id pagesVal = attrs[@"pages"];
    if (pagesVal && pagesVal != [NSNull null]) {
        ch.pagesCount = [pagesVal integerValue];
    } else {
        ch.pagesCount = 0;
    }
    
    return ch;
}

@end

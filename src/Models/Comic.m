#import "Comic.h"

@implementation Comic

+ (instancetype)comicFromInternetArchiveDoc:(NSDictionary *)doc {
    if (![doc isKindOfClass:[NSDictionary class]]) return nil;
    
    NSString *ident = doc[@"identifier"];
    if (!ident || ident.length == 0) return nil;
    
    Comic *c = [[Comic alloc] init];
    c.comicId = [NSString stringWithFormat:@"ia_%@", ident];
    c.title = doc[@"title"] ?: ident;
    
    id desc = doc[@"description"];
    if ([desc isKindOfClass:[NSString class]]) {
        c.comicDescription = desc;
    } else if ([desc isKindOfClass:[NSArray class]]) {
        c.comicDescription = [desc componentsJoinedByString:@" "];
    } else {
        c.comicDescription = @"Cómic Occidental de la biblioteca digital abierta.";
    }
    
    c.author = @"Cómic Occidental";
    c.status = @"Completado";
    c.originalLanguage = @"en";
    c.originBadge = @"Cómic Occidental";
    c.tags = @[@"Cómic", @"Occidental", @"Novela Gráfica"];
    c.coverURL = [NSString stringWithFormat:@"https://archive.org/services/img/%@", ident];
    return c;
}

+ (instancetype)comicFromMangaDexJSON:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    Comic *comic = [[Comic alloc] init];
    comic.comicId = dict[@"id"];
    
    NSDictionary *attributes = dict[@"attributes"];
    if ([attributes isKindOfClass:[NSDictionary class]]) {
        // Título principal
        NSDictionary *titleDict = attributes[@"title"];
        if ([titleDict isKindOfClass:[NSDictionary class]]) {
            comic.title = titleDict[@"es"] ?: titleDict[@"en"] ?: titleDict[@"ja-ro"] ?: [titleDict.allValues firstObject];
        }
        
        // Si no hay título en inglés/español, buscar en altTitles
        if (!comic.title || comic.title.length == 0 || [comic.title isEqualToString:@"Sin título"]) {
            NSArray *altTitles = attributes[@"altTitles"];
            if ([altTitles isKindOfClass:[NSArray class]]) {
                for (NSDictionary *altDict in altTitles) {
                    if ([altDict isKindOfClass:[NSDictionary class]]) {
                        NSString *alt = altDict[@"es"] ?: altDict[@"en"];
                        if (alt && alt.length > 0) {
                            comic.title = alt;
                            break;
                        }
                    }
                }
            }
        }
        
        if (!comic.title || comic.title.length == 0) {
            comic.title = @"Sin título";
        }
        
        // Idioma original y badge de procedencia
        NSString *origLang = attributes[@"originalLanguage"];
        comic.originalLanguage = origLang ?: @"";
        if ([origLang isEqualToString:@"en"]) {
            comic.originBadge = @"Cómic Occidental";
        } else if ([origLang isEqualToString:@"ko"]) {
            comic.originBadge = @"Manhwa Coreano";
        } else if ([origLang isEqualToString:@"zh"] || [origLang isEqualToString:@"zh-hk"]) {
            comic.originBadge = @"Manhua Chino";
        } else if ([origLang isEqualToString:@"ja"]) {
            comic.originBadge = @"Manga Japonés";
        } else if ([origLang isEqualToString:@"es"]) {
            comic.originBadge = @"Cómic Español";
        } else if ([origLang isEqualToString:@"fr"]) {
            comic.originBadge = @"BD Francesa";
        } else {
            comic.originBadge = @"Cómic Global";
        }
        
        // Descripción
        NSDictionary *descDict = attributes[@"description"];
        if ([descDict isKindOfClass:[NSDictionary class]]) {
            comic.comicDescription = descDict[@"es"] ?: descDict[@"en"] ?: [descDict.allValues firstObject];
        }
        if (!comic.comicDescription || comic.comicDescription.length == 0) {
            comic.comicDescription = @"Sin descripción disponible.";
        }
        
        // Estado
        NSString *statusStr = attributes[@"status"];
        if ([statusStr isEqualToString:@"ongoing"]) {
            comic.status = @"En emisión";
        } else if ([statusStr isEqualToString:@"completed"]) {
            comic.status = @"Completado";
        } else if ([statusStr isEqualToString:@"hiatus"]) {
            comic.status = @"En pausa";
        } else if ([statusStr isEqualToString:@"cancelled"]) {
            comic.status = @"Cancelado";
        } else {
            comic.status = statusStr ?: @"Desconocido";
        }
        
        // Tags / Géneros
        NSArray *tagsArr = attributes[@"tags"];
        NSMutableArray<NSString *> *tagNames = [NSMutableArray array];
        if ([tagsArr isKindOfClass:[NSArray class]]) {
            for (NSDictionary *tagItem in tagsArr) {
                if ([tagItem isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *tagAttrs = tagItem[@"attributes"];
                    if ([tagAttrs isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *nameDict = tagAttrs[@"name"];
                        if ([nameDict isKindOfClass:[NSDictionary class]]) {
                            NSString *name = nameDict[@"en"] ?: nameDict[@"es"];
                            if (name) {
                                [tagNames addObject:name];
                            }
                        }
                    }
                }
            }
        }
        comic.tags = tagNames;
    }
    
    // Relationships (portada y autor)
    NSArray *relationships = dict[@"relationships"];
    if ([relationships isKindOfClass:[NSArray class]]) {
        for (NSDictionary *rel in relationships) {
            if (![rel isKindOfClass:[NSDictionary class]]) continue;
            NSString *type = rel[@"type"];
            if ([type isEqualToString:@"cover_art"]) {
                NSDictionary *relAttrs = rel[@"attributes"];
                if ([relAttrs isKindOfClass:[NSDictionary class]]) {
                    NSString *fileName = relAttrs[@"fileName"];
                    if (fileName && comic.comicId) {
                        comic.coverURL = [NSString stringWithFormat:@"https://uploads.mangadex.org/covers/%@/%@.256.jpg", comic.comicId, fileName];
                    }
                }
            } else if ([type isEqualToString:@"author"]) {
                NSDictionary *relAttrs = rel[@"attributes"];
                if ([relAttrs isKindOfClass:[NSDictionary class]]) {
                    NSString *authorName = relAttrs[@"name"];
                    if (authorName) {
                        comic.author = authorName;
                    }
                }
            }
        }
    }
    
    if (!comic.author || comic.author.length == 0) {
        comic.author = @"Autor desconocido";
    }
    
    return comic;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (self.comicId) dict[@"id"] = self.comicId;
    if (self.title) dict[@"title"] = self.title;
    if (self.comicDescription) dict[@"description"] = self.comicDescription;
    if (self.author) dict[@"author"] = self.author;
    if (self.status) dict[@"status"] = self.status;
    if (self.coverURL) dict[@"coverURL"] = self.coverURL;
    if (self.originalLanguage) dict[@"originalLanguage"] = self.originalLanguage;
    if (self.originBadge) dict[@"originBadge"] = self.originBadge;
    if (self.tags) dict[@"tags"] = self.tags;
    return [dict copy];
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    Comic *c = [[Comic alloc] init];
    c.comicId = dict[@"id"];
    c.title = dict[@"title"];
    c.comicDescription = dict[@"description"];
    c.author = dict[@"author"];
    c.status = dict[@"status"];
    c.coverURL = dict[@"coverURL"];
    c.originalLanguage = dict[@"originalLanguage"];
    c.originBadge = dict[@"originBadge"];
    c.tags = dict[@"tags"];
    return c;
}

@end

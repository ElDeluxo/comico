#import "Comic.h"

@implementation Comic

+ (instancetype)comicFromInternetArchiveDoc:(NSDictionary *)doc {
    if (![doc isKindOfClass:[NSDictionary class]]) return nil;
    
    NSString *ident = doc[@"identifier"];
    if (![ident isKindOfClass:[NSString class]] || ident.length == 0) return nil;
    
    Comic *c = [[Comic alloc] init];
    c.comicId = [NSString stringWithFormat:@"ia_%@", ident];
    
    id rawTitle = doc[@"title"];
    if ([rawTitle isKindOfClass:[NSString class]]) {
        c.title = rawTitle;
    } else if ([rawTitle isKindOfClass:[NSArray class]] && [rawTitle count] > 0) {
        c.title = [NSString stringWithFormat:@"%@", [rawTitle firstObject]];
    } else {
        c.title = ident;
    }
    
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
    
    id cId = dict[@"id"];
    if (![cId isKindOfClass:[NSString class]] || [cId length] == 0) return nil;
    
    Comic *comic = [[Comic alloc] init];
    comic.comicId = cId;
    comic.title = @"Sin título";
    comic.author = @"Autor desconocido";
    comic.status = @"Disponible";
    comic.comicDescription = @"Sin descripción disponible.";
    comic.tags = @[];
    
    NSDictionary *attributes = dict[@"attributes"];
    if ([attributes isKindOfClass:[NSDictionary class]]) {
        // Título principal
        NSDictionary *titleDict = attributes[@"title"];
        if ([titleDict isKindOfClass:[NSDictionary class]]) {
            id t = titleDict[@"es"] ?: titleDict[@"en"] ?: titleDict[@"ja-ro"] ?: [titleDict.allValues firstObject];
            if ([t isKindOfClass:[NSString class]] && [t length] > 0) {
                comic.title = t;
            }
        }
        
        // Si no hay título en inglés/español, buscar en altTitles
        if (!comic.title || [comic.title isEqualToString:@"Sin título"]) {
            NSArray *altTitles = attributes[@"altTitles"];
            if ([altTitles isKindOfClass:[NSArray class]]) {
                for (NSDictionary *altDict in altTitles) {
                    if ([altDict isKindOfClass:[NSDictionary class]]) {
                        id alt = altDict[@"es"] ?: altDict[@"en"];
                        if ([alt isKindOfClass:[NSString class]] && [alt length] > 0) {
                            comic.title = alt;
                            break;
                        }
                    }
                }
            }
        }
        
        // Idioma original y badge de procedencia
        id origLang = attributes[@"originalLanguage"];
        if ([origLang isKindOfClass:[NSString class]]) {
            comic.originalLanguage = origLang;
        } else {
            comic.originalLanguage = @"";
        }
        
        if ([comic.originalLanguage isEqualToString:@"en"]) {
            comic.originBadge = @"Cómic Occidental";
        } else if ([comic.originalLanguage isEqualToString:@"ko"]) {
            comic.originBadge = @"Manhwa Coreano";
        } else if ([comic.originalLanguage isEqualToString:@"zh"] || [comic.originalLanguage isEqualToString:@"zh-hk"]) {
            comic.originBadge = @"Manhua Chino";
        } else if ([comic.originalLanguage isEqualToString:@"ja"]) {
            comic.originBadge = @"Manga Japonés";
        } else if ([comic.originalLanguage isEqualToString:@"es"]) {
            comic.originBadge = @"Cómic Español";
        } else if ([comic.originalLanguage isEqualToString:@"fr"]) {
            comic.originBadge = @"BD Francesa";
        } else {
            comic.originBadge = @"Cómic Global";
        }
        
        // Descripción
        NSDictionary *descDict = attributes[@"description"];
        if ([descDict isKindOfClass:[NSDictionary class]]) {
            id d = descDict[@"es"] ?: descDict[@"en"] ?: [descDict.allValues firstObject];
            if ([d isKindOfClass:[NSString class]] && [d length] > 0) {
                comic.comicDescription = d;
            }
        }
        
        // Estado
        id statusStr = attributes[@"status"];
        if ([statusStr isKindOfClass:[NSString class]]) {
            if ([statusStr isEqualToString:@"ongoing"]) {
                comic.status = @"En emisión";
            } else if ([statusStr isEqualToString:@"completed"]) {
                comic.status = @"Completado";
            } else if ([statusStr isEqualToString:@"hiatus"]) {
                comic.status = @"En pausa";
            } else if ([statusStr isEqualToString:@"cancelled"]) {
                comic.status = @"Cancelado";
            } else {
                comic.status = statusStr;
            }
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
                            id name = nameDict[@"en"] ?: nameDict[@"es"];
                            if ([name isKindOfClass:[NSString class]] && [name length] > 0) {
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
                    id fileName = relAttrs[@"fileName"];
                    if ([fileName isKindOfClass:[NSString class]] && [fileName length] > 0 && comic.comicId) {
                        comic.coverURL = [NSString stringWithFormat:@"https://uploads.mangadex.org/covers/%@/%@.256.jpg", comic.comicId, fileName];
                    }
                }
            } else if ([type isEqualToString:@"author"]) {
                NSDictionary *relAttrs = rel[@"attributes"];
                if ([relAttrs isKindOfClass:[NSDictionary class]]) {
                    id authorName = relAttrs[@"name"];
                    if ([authorName isKindOfClass:[NSString class]] && [authorName length] > 0) {
                        comic.author = authorName;
                    }
                }
            }
        }
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
    c.comicId = [dict[@"id"] isKindOfClass:[NSString class]] ? dict[@"id"] : nil;
    c.title = [dict[@"title"] isKindOfClass:[NSString class]] ? dict[@"title"] : @"Cómic";
    c.comicDescription = [dict[@"description"] isKindOfClass:[NSString class]] ? dict[@"description"] : @"";
    c.author = [dict[@"author"] isKindOfClass:[NSString class]] ? dict[@"author"] : @"Desconocido";
    c.status = [dict[@"status"] isKindOfClass:[NSString class]] ? dict[@"status"] : @"Disponible";
    c.coverURL = [dict[@"coverURL"] isKindOfClass:[NSString class]] ? dict[@"coverURL"] : nil;
    c.originalLanguage = [dict[@"originalLanguage"] isKindOfClass:[NSString class]] ? dict[@"originalLanguage"] : @"";
    c.originBadge = [dict[@"originBadge"] isKindOfClass:[NSString class]] ? dict[@"originBadge"] : @"Cómic";
    c.tags = [dict[@"tags"] isKindOfClass:[NSArray class]] ? dict[@"tags"] : @[];
    return c;
}

@end

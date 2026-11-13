//
//  Comic.swift
//  Comico
//
//  Modelos de datos que mapean a las respuestas JSON de la API de MangaDex.
//

import Foundation

// MARK: - Comic

struct Comic: Codable {
    let id: String
    let title: String
    let description: String
    let coverURL: String?
    let author: String?
    let status: ComicStatus?
    let tags: [Tag]

    init(id: String, title: String, description: String, coverURL: String?, author: String?, status: ComicStatus?, tags: [Tag]) {
        self.id = id
        self.title = title
        self.description = description
        self.coverURL = coverURL
        self.author = author
        self.status = status
        self.tags = tags
    }

    /// Inicializa un `Comic` a partir de los datos crudos de MangaDex (`MangaDexMangaData`).
    /// Extrae título, descripción, autor y cover de los atributos y relaciones.
    init(from mangaData: MangaDexMangaData) {
        self.id = mangaData.id

        // Título: preferir inglés, luego japonés romanizado, luego el primero disponible
        let titles = mangaData.attributes.title
        self.title = titles["en"]
            ?? titles["ja-ro"]
            ?? titles["ja"]
            ?? titles.values.first
            ?? "Sin título"

        // Descripción: preferir español, luego inglés
        let descriptions = mangaData.attributes.description ?? [:]
        let rawDescription = descriptions["es"] ?? descriptions["en"] ?? ""
        self.description = rawDescription.strippingHTML()

        // Estado
        if let statusStr = mangaData.attributes.status {
            self.status = ComicStatus(rawValue: statusStr)
        } else {
            self.status = nil
        }

        // Tags
        self.tags = (mangaData.attributes.tags ?? []).compactMap { tagData -> Tag? in
            let name = tagData.attributes.name["en"] ?? tagData.attributes.name.values.first ?? ""
            return Tag(id: tagData.id, name: name)
        }

        // Extraer autor y cover de relaciones
        var authorName: String? = nil
        var coverFileName: String? = nil

        if let relationships = mangaData.relationships {
            for rel in relationships {
                if rel.type == "author", let attrs = rel.attributes {
                    authorName = attrs["name"]?.stringValue
                }
                if rel.type == "cover_art", let attrs = rel.attributes {
                    coverFileName = attrs["fileName"]?.stringValue
                }
            }
        }

        self.author = authorName

        if let fileName = coverFileName {
            self.coverURL = APIService.buildCoverURL(mangaId: mangaData.id, fileName: fileName)
        } else {
            self.coverURL = nil
        }
    }
}

// MARK: - ComicStatus

enum ComicStatus: String, Codable {
    case ongoing
    case completed
    case hiatus
    case cancelled
}

// MARK: - Tag

struct Tag: Codable {
    let id: String
    let name: String
}

// MARK: - Chapter

struct Chapter: Codable {
    let id: String
    let chapterNumber: String?
    let title: String?
    let volume: String?
    let pagesCount: Int
    let translatedLanguage: String?
    let publishDate: Date?

    /// Inicializa un `Chapter` a partir de los datos crudos de MangaDex.
    init(from chapterData: MangaDexChapterData) {
        self.id = chapterData.id
        self.chapterNumber = chapterData.attributes.chapter
        self.title = chapterData.attributes.title
        self.volume = chapterData.attributes.volume
        self.pagesCount = chapterData.attributes.pages ?? 0
        self.translatedLanguage = chapterData.attributes.translatedLanguage

        if let dateStr = chapterData.attributes.publishAt {
            self.publishDate = Chapter.parseDate(dateStr)
        } else {
            self.publishDate = nil
        }
    }

    init(id: String, chapterNumber: String?, title: String?, volume: String?, pagesCount: Int, translatedLanguage: String?, publishDate: Date?) {
        self.id = id
        self.chapterNumber = chapterNumber
        self.title = title
        self.volume = volume
        self.pagesCount = pagesCount
        self.translatedLanguage = translatedLanguage
        self.publishDate = publishDate
    }

    /// Alias de conveniencia para `chapterNumber`.
    var chapter: String? {
        return chapterNumber
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // MangaDex usa formato ISO 8601
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+SS:SS"
        return formatter.date(from: string)
    }
}

// MARK: - Page

struct Page: Codable {
    let imageURL: String
}

// MARK: - Modelos RAW de MangaDex (para decodificación directa del JSON)

/// Datos crudos de un manga tal como vienen de la API.
struct MangaDexMangaData: Codable {
    let id: String
    let type: String
    let attributes: MangaDexMangaAttributes
    let relationships: [RelationshipData]?
}

struct MangaDexMangaAttributes: Codable {
    let title: [String: String]
    let altTitles: [[String: String]]?
    let description: [String: String]?
    let status: String?
    let year: Int?
    let tags: [MangaDexTagData]?
    let contentRating: String?
}

struct MangaDexTagData: Codable {
    let id: String
    let type: String?
    let attributes: MangaDexTagAttributes
}

struct MangaDexTagAttributes: Codable {
    let name: [String: String]
    let group: String?
}

/// Datos crudos de un capítulo tal como vienen de la API.
struct MangaDexChapterData: Codable {
    let id: String
    let type: String?
    let attributes: MangaDexChapterAttributes
}

struct MangaDexChapterAttributes: Codable {
    let volume: String?
    let chapter: String?
    let title: String?
    let translatedLanguage: String?
    let pages: Int?
    let publishAt: String?
}

/// Respuesta del endpoint at-home/server
struct AtHomeResponse: Codable {
    let baseUrl: String
    let chapter: AtHomeChapter
}

struct AtHomeChapter: Codable {
    let hash: String
    let data: [String]
    let dataSaver: [String]
}

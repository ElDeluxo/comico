//
//  LocalComic.swift
//  Comico
//
//  Modelos para comics locales (CBZ/CBR) - comics occidentales
//

import Foundation
import UIKit

// MARK: - LocalComic

/// Representa un comic local almacenado en el dispositivo
struct LocalComic: Codable {
    let id: String
    let title: String
    let author: String?
    let coverImagePath: String?
    let filePath: String
    let fileFormat: ComicFileFormat
    let pageCount: Int
    let lastReadPage: Int
    let lastReadDate: Date?
    let dateAdded: Date

    init(id: String = UUID().uuidString,
         title: String,
         author: String? = nil,
         coverImagePath: String? = nil,
         filePath: String,
         fileFormat: ComicFileFormat,
         pageCount: Int = 0,
         lastReadPage: Int = 0,
         lastReadDate: Date? = nil,
         dateAdded: Date = Date()) {
        self.id = id
        self.title = title
        self.author = author
        self.coverImagePath = coverImagePath
        self.filePath = filePath
        self.fileFormat = fileFormat
        self.pageCount = pageCount
        self.lastReadPage = lastReadPage
        self.lastReadDate = lastReadDate
        self.dateAdded = dateAdded
    }
}

// MARK: - ComicFileFormat

enum ComicFileFormat: String, Codable, CaseIterable {
    case cbz = "cbz"
    case cbr = "cbr"
    case pdf = "pdf"
    case epub = "epub"

    static var supportedExtensions: [String] {
        return ComicFileFormat.allCases.map { $0.rawValue }
    }

    var displayName: String {
        return rawValue.uppercased()
    }
}

// MARK: - LocalComicPage

/// Representa una página individual de un comic local
struct LocalComicPage {
    let index: Int
    let imagePath: String
    let imageName: String
}

// MARK: - LocalComicLibrary

/// Gestiona la biblioteca de comics locales
final class LocalComicLibrary {

    static let shared = LocalComicLibrary()

    private let libraryKey = "comico_local_comics_library"
    private let documentsURL: URL
    private let comicsDirectoryURL: URL

    private init() {
        documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        comicsDirectoryURL = documentsURL.appendingPathComponent("Comics", isDirectory: true)
        createComicsDirectoryIfNeeded()
    }

    // MARK: - Public API

    /// Obtiene todos los comics de la biblioteca local
    func getAllComics() -> [LocalComic] {
        guard let data = UserDefaults.standard.data(forKey: libraryKey),
              let comics = try? JSONDecoder().decode([LocalComic].self, from: data) else {
            return []
        }
        return comics.sorted { $0.dateAdded > $1.dateAdded }
    }

    /// Añade un comic a la biblioteca
    func addComic(_ comic: LocalComic) {
        var comics = getAllComics()
        comics.removeAll { $0.id == comic.id }
        comics.insert(comic, at: 0)
        saveComics(comics)
    }

    /// Elimina un comic de la biblioteca
    func removeComic(withId id: String) {
        var comics = getAllComics()
        comics.removeAll { $0.id == id }
        saveComics(comics)
    }

    /// Actualiza el progreso de lectura
    func updateReadingProgress(for comicId: String, page: Int) {
        var comics = getAllComics()
        if let index = comics.firstIndex(where: { $0.id == comicId }) {
            let comic = comics[index]
            let updatedComic = LocalComic(
                id: comic.id,
                title: comic.title,
                author: comic.author,
                coverImagePath: comic.coverImagePath,
                filePath: comic.filePath,
                fileFormat: comic.fileFormat,
                pageCount: comic.pageCount,
                lastReadPage: page,
                lastReadDate: Date(),
                dateAdded: comic.dateAdded
            )
            comics[index] = updatedComic
            saveComics(comics)
        }
    }

    /// Actualiza el número de páginas de un comic
    func updatePageCount(for comicId: String, count: Int) {
        var comics = getAllComics()
        if let index = comics.firstIndex(where: { $0.id == comicId }) {
            let comic = comics[index]
            let updatedComic = LocalComic(
                id: comic.id,
                title: comic.title,
                author: comic.author,
                coverImagePath: comic.coverImagePath,
                filePath: comic.filePath,
                fileFormat: comic.fileFormat,
                pageCount: count,
                lastReadPage: comic.lastReadPage,
                lastReadDate: comic.lastReadDate,
                dateAdded: comic.dateAdded
            )
            comics[index] = updatedComic
            saveComics(comics)
        }
    }

    /// Actualiza la portada de un comic
    func updateCoverImage(for comicId: String, coverPath: String) {
        var comics = getAllComics()
        if let index = comics.firstIndex(where: { $0.id == comicId }) {
            let comic = comics[index]
            let updatedComic = LocalComic(
                id: comic.id,
                title: comic.title,
                author: comic.author,
                coverImagePath: coverPath,
                filePath: comic.filePath,
                fileFormat: comic.fileFormat,
                pageCount: comic.pageCount,
                lastReadPage: comic.lastReadPage,
                lastReadDate: comic.lastReadDate,
                dateAdded: comic.dateAdded
            )
            comics[index] = updatedComic
            saveComics(comics)
        }
    }

    /// Obtiene la URL del directorio donde se guardan los comics importados
    var importDirectoryURL: URL {
        return comicsDirectoryURL
    }

    /// Escanea el directorio de comics y detecta archivos CBZ/CBR
    func scanForNewComics() -> [URL] {
        let fileManager = FileManager.default
        var foundFiles: [URL] = []

        guard fileManager.fileExists(atPath: comicsDirectoryURL.path) else {
            return []
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: comicsDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for fileURL in contents {
                let ext = fileURL.pathExtension.lowercased()
                if ComicFileFormat.supportedExtensions.contains(ext) {
                    // Verificar si ya está en la biblioteca
                    let comics = getAllComics()
                    let alreadyExists = comics.contains { $0.filePath == fileURL.path }
                    if !alreadyExists {
                        foundFiles.append(fileURL)
                    }
                }
            }
        } catch {
            print("Error scanning comics directory: \(error)")
        }

        return foundFiles
    }

    /// Importa un archivo de comic desde una URL externa (ej. Files app)
    func importComic(from sourceURL: URL) -> LocalComic? {
        let fileManager = FileManager.default
        let fileName = sourceURL.lastPathComponent
        let destinationURL = comicsDirectoryURL.appendingPathComponent(fileName)

        // Si ya existe, añadir número
        var finalURL = destinationURL
        var counter = 1
        while fileManager.fileExists(atPath: finalURL.path) {
            let nameWithoutExt = (fileName as NSString).deletingPathExtension
            let ext = fileName.pathExtension
            finalURL = comicsDirectoryURL.appendingPathComponent("\(nameWithoutExt) (\(counter)).\(ext)")
            counter += 1
        }

        do {
            // Copiar archivo
            if sourceURL.path != finalURL.path {
                try fileManager.copyItem(at: sourceURL, to: finalURL)
            }

            // Extraer información básica
            let title = extractTitleFromFileName(finalURL.lastPathComponent)
            let format = ComicFileFormat(rawValue: finalURL.pathExtension.lowercased()) ?? .cbz

            let comic = LocalComic(
                title: title,
                filePath: finalURL.path,
                fileFormat: format
            )

            addComic(comic)

            // Extraer portada y contar páginas en background
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.processComicFile(comic)
            }

            return comic
        } catch {
            print("Error importing comic: \(error)")
            return nil
        }
    }

    /// Procesa un archivo de comic para extraer portada y contar páginas
    private func processComicFile(_ comic: LocalComic) {
        let fileURL = URL(fileURLWithPath: comic.filePath)
        let format = comic.fileFormat

        var pageCount = 0
        var coverImagePath: String? = nil

        switch format {
        case .cbz:
            (pageCount, coverImagePath) = processCBZ(fileURL)
        case .cbr:
            (pageCount, coverImagePath) = processCBR(fileURL)
        case .pdf:
            (pageCount, coverImagePath) = processPDF(fileURL)
        case .epub:
            (pageCount, coverImagePath) = processEPUB(fileURL)
        }

        // Actualizar en main thread
        DispatchQueue.main.async { [weak self] in
            self?.updatePageCount(for: comic.id, count: pageCount)
            if let coverPath = coverImagePath {
                self?.updateCoverImage(for: comic.id, coverPath: coverPath)
            }
        }
    }

    // MARK: - File Format Processors

    private func processCBZ(_ url: URL) -> (Int, String?) {
        // CBZ es un ZIP con imágenes
        // En iOS 9+, podemos usar libarchive o simplemente listar el contenido
        // Por simplicidad, usamos un enfoque básico
        return processArchive(url, extensions: ["jpg", "jpeg", "png", "webp", "bmp"])
    }

    private func processCBR(_ url: URL) -> (Int, String?) {
        // CBR es un RAR con imágenes - más complejo, requiere librería externa
        // Por ahora, retornamos 0 y nil
        return (0, nil)
    }

    private func processPDF(_ url: URL) -> (Int, String?) {
        // PDF - usar CGPDFDocument
        guard let document = CGPDFDocument(url as CFURL) else { return (0, nil) }
        let count = document.numberOfPages

        // Extraer primera página como imagen para portada
        var coverPath: String? = nil
        if count > 0, let page = document.page(at: 1) {
            coverPath = extractPDFPageAsImage(page, for: url)
        }

        return (count, coverPath)
    }

    private func processEPUB(_ url: URL) -> (Int, String?) {
        // EPUB - más complejo, requiere parsing XML
        return (0, nil)
    }

    private func processArchive(_ url: URL, extensions: [String]) -> (Int, String?) {
        // Para CBZ/CBR, intentamos leer como ZIP
        // En una implementación real, usaríamos libarchive o ZipArchive
        // Por simplicidad, retornamos valores por defecto
        // NOTA: En producción se necesitaría una librería como ZipArchive o SSZipArchive
        return (0, nil)
    }

    private func extractPDFPageAsImage(_ page: CGPDFPage, for url: URL) -> String? {
        let pageRect = page.getBoxRect(.mediaBox)
        guard pageRect.width > 0 && pageRect.height > 0 else { return nil }

        UIGraphicsBeginImageContextWithOptions(pageRect.size, true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        UIColor.white.setFill()
        context.fill(pageRect)
        context.translateBy(x: 0, y: pageRect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.drawPDFPage(page)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let validImage = image else { return nil }

        // Guardar imagen en directorio de cache
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let coverURL = cacheDir.appendingPathComponent("\(url.lastPathComponent)_cover.jpg")

        if let data = validImage.jpegData(compressionQuality: 0.8) {
            try? data.write(to: coverURL)
            return coverURL.path
        }
        return nil
    }

    private func extractTitleFromFileName(_ fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        // Limpiar nombre: quitar números de volumen, corchetes, etc.
        var cleaned = name
            .replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalizar primera letra de cada palabra
        cleaned = cleaned.split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")

        return cleaned.isEmpty ? name : cleaned
    }

    // MARK: - Persistence

    private func saveComics(_ comics: [LocalComic]) {
        if let data = try? JSONEncoder().encode(comics) {
            UserDefaults.standard.set(data, forKey: libraryKey)
            UserDefaults.standard.synchronize()
        }
    }

    private func createComicsDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: comicsDirectoryURL.path) {
            try? fileManager.createDirectory(at: comicsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

// MARK: - ComicFileExtractor

/// Utilidad para extraer páginas de archivos de comic
final class ComicFileExtractor {

    /// Extrae todas las páginas de un comic local
    static func extractPages(from comic: LocalComic) -> [LocalComicPage] {
        let fileURL = URL(fileURLWithPath: comic.filePath)

        switch comic.fileFormat {
        case .cbz:
            return extractCBZPages(fileURL)
        case .cbr:
            return extractCBRPages(fileURL)
        case .pdf:
            return extractPDFPages(fileURL)
        case .epub:
            return extractEPUBPages(fileURL)
        }
    }

    private static func extractCBZPages(_ url: URL) -> [LocalComicPage] {
        // Implementación real requeriría librería ZIP
        // Placeholder para demostración
        return []
    }

    private static func extractCBRPages(_ url: URL) -> [LocalComicPage] {
        // Requiere librería RAR
        return []
    }

    private static func extractPDFPages(_ url: URL) -> [LocalComicPage] {
        guard let document = CGPDFDocument(url as CFURL) else { return [] }
        var pages: [LocalComicPage] = []

        for i in 1...document.numberOfPages {
            if let page = document.page(at: i) {
                // Generar nombre de archivo para la página
                let pageName = "page_\(i).jpg"
                pages.append(LocalComicPage(index: i - 1, imagePath: "", imageName: pageName))
            }
        }
        return pages
    }

    private static func extractEPUBPages(_ url: URL) -> [LocalComicPage] {
        return []
    }

    /// Renderiza una página específica de un comic a UIImage
    static func renderPage(_ page: LocalComicPage, from comic: LocalComic, completion: @escaping (UIImage?) -> Void) {
        let fileURL = URL(fileURLWithPath: comic.filePath)

        DispatchQueue.global(qos: .userInitiated).async {
            var image: UIImage?

            switch comic.fileFormat {
            case .cbz:
                image = renderCBZPage(page, from: fileURL)
            case .cbr:
                image = renderCBRPage(page, from: fileURL)
            case .pdf:
                image = renderPDFPage(page.index + 1, from: fileURL)
            case .epub:
                image = nil
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    private static func renderCBZPage(_ page: LocalComicPage, from url: URL) -> UIImage? {
        // Requiere librería ZIP
        return nil
    }

    private static func renderCBRPage(_ page: LocalComicPage, from url: URL) -> UIImage? {
        return nil
    }

    private static func renderPDFPage(_ pageNumber: Int, from url: URL) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: pageNumber) else { return nil }

        let pageRect = page.getBoxRect(.mediaBox)
        guard pageRect.width > 0 && pageRect.height > 0 else { return nil }

        UIGraphicsBeginImageContextWithOptions(pageRect.size, true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        UIColor.white.setFill()
        context.fill(pageRect)
        context.translateBy(x: 0, y: pageRect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.drawPDFPage(page)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
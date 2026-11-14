//
//  ImageCache.swift
//  Comico
//
//  Cache de imágenes en memoria (NSCache) y disco (Documents/ImageCache/).
//  Compatible con iOS 9+. Sin dependencias externas.
//

import UIKit

/// Cache de imágenes con dos niveles: memoria (NSCache) y disco.
final class ImageCache {

    // MARK: - Singleton

    static let shared = ImageCache()

    // MARK: - Properties

    /// Cache en memoria usando NSCache (se purga automáticamente bajo presión de memoria).
    private let memoryCache = NSCache<NSString, UIImage>()

    /// Cola serial para operaciones de disco.
    private let diskQueue = DispatchQueue(label: "com.comico.imagecache.disk")

    /// Directorio en disco para las imágenes cacheadas.
    private let diskCacheDirectory: String

    /// Sesión de URL compartida para descargas.
    private let session: URLSession

    // MARK: - Init

    private init() {
        // Configurar directorio de cache en Documents/ImageCache/
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        diskCacheDirectory = (documentsPath as NSString).appendingPathComponent("ImageCache")

        // Crear directorio si no existe
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: diskCacheDirectory) {
            try? fileManager.createDirectory(atPath: diskCacheDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        // Configurar NSCache
        memoryCache.countLimit = 100  // Máximo 100 imágenes en memoria
        memoryCache.totalCostLimit = 50 * 1024 * 1024  // 50 MB máximo

        // URLSession para descargas
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Carga una imagen desde cache (memoria → disco) o la descarga de la red.
    /// También soporta rutas de archivos locales (file:// o path absoluto).
    ///
    /// - Parameters:
    ///   - urlString: URL de la imagen como String, o ruta de archivo local.
    ///   - completion: Closure ejecutado en el main thread con la imagen o nil en caso de error.
    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        let cacheKey = cacheKeyForURL(urlString)

        // 1. Buscar en memoria
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }

        // 2. Buscar en disco
        diskQueue.async { [weak self] in
            guard let self = self else { return }

            if let diskImage = self.loadFromDisk(key: cacheKey) {
                // Guardar en memoria para acceso rápido futuro
                self.memoryCache.setObject(diskImage, forKey: cacheKey as NSString)
                DispatchQueue.main.async {
                    completion(diskImage)
                }
                return
            }

            // 3. Verificar si es un archivo local
            if self.isLocalFilePath(urlString) {
                self.loadLocalImage(path: urlString, cacheKey: cacheKey, completion: completion)
                return
            }

            // 4. Descargar de la red
            self.downloadImage(urlString: urlString, cacheKey: cacheKey, completion: completion)
        }
    }

    /// Verifica si el string es una ruta de archivo local
    private func isLocalFilePath(_ path: String) -> Bool {
        return path.hasPrefix("file://") || path.hasPrefix("/") || (path as NSString).pathExtension != ""
    }

    /// Carga una imagen desde el sistema de archivos local
    private func loadLocalImage(path: String, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        var filePath = path
        if path.hasPrefix("file://") {
            filePath = (path as NSString).replacingOccurrences(of: "file://", with: "")
        }

        // Intentar cargar directamente
        if let image = UIImage(contentsOfFile: filePath) {
            // Guardar en memoria
            self.memoryCache.setObject(image, forKey: cacheKey as NSString)

            // Guardar en disco cache también
            self.diskQueue.async {
                self.saveToDisk(image: image, key: cacheKey)
            }

            DispatchQueue.main.async {
                completion(image)
            }
        } else {
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }

    /// Precarga una imagen sin devolver resultado (para prefetching).
    ///
    /// - Parameter urlString: URL de la imagen.
    func prefetchImage(from urlString: String) {
        loadImage(from: urlString) { _ in }
    }

    /// Elimina una imagen específica del cache.
    ///
    /// - Parameter urlString: URL de la imagen a eliminar.
    func removeImage(for urlString: String) {
        let cacheKey = cacheKeyForURL(urlString)
        memoryCache.removeObject(forKey: cacheKey as NSString)
        diskQueue.async { [weak self] in
            self?.removeFromDisk(key: cacheKey)
        }
    }

    /// Limpia todo el cache de memoria.
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    /// Limpia todo el cache de disco.
    func clearDiskCache() {
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            if let files = try? fileManager.contentsOfDirectory(atPath: self.diskCacheDirectory) {
                for file in files {
                    let filePath = (self.diskCacheDirectory as NSString).appendingPathComponent(file)
                    try? fileManager.removeItem(atPath: filePath)
                }
            }
        }
    }

    /// Limpia ambos caches (memoria y disco).
    func clearAllCaches() {
        clearMemoryCache()
        clearDiskCache()
    }

    // MARK: - Private Helpers

    /// Genera una clave de cache segura para el sistema de archivos a partir de una URL.
    private func cacheKeyForURL(_ urlString: String) -> String {
        // Usar un hash simple para evitar problemas con caracteres especiales en nombres de archivo
        var hash: UInt64 = 5381
        for char in urlString.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        // Mantener extensión para que el OS pueda identificar el tipo
        let ext = (urlString as NSString).pathExtension
        if ext.isEmpty {
            return String(hash)
        }
        return "\(hash).\(ext)"
    }

    /// Carga una imagen del disco.
    private func loadFromDisk(key: String) -> UIImage? {
        let filePath = (diskCacheDirectory as NSString).appendingPathComponent(key)
        guard let data = NSData(contentsOfFile: filePath) else { return nil }
        return UIImage(data: data as Data)
    }

    /// Guarda una imagen en disco.
    private func saveToDisk(image: UIImage, key: String) {
        let filePath = (diskCacheDirectory as NSString).appendingPathComponent(key)
        // Usar JPEG para portadas (mejor compresión), PNG para otros
        if let data = image.jpegData(compressionQuality: 0.8) {
            (data as NSData).write(toFile: filePath, atomically: true)
        } else if let data = image.pngData() {
            (data as NSData).write(toFile: filePath, atomically: true)
        }
    }

    /// Elimina una imagen del disco.
    private func removeFromDisk(key: String) {
        let filePath = (diskCacheDirectory as NSString).appendingPathComponent(key)
        try? FileManager.default.removeItem(atPath: filePath)
    }

    /// Descarga una imagen de la red y la guarda en cache.
    private func downloadImage(urlString: String, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data,
                  let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Guardar en memoria
            self.memoryCache.setObject(image, forKey: cacheKey as NSString)

            // Guardar en disco
            self.diskQueue.async {
                self.saveToDisk(image: image, key: cacheKey)
            }

            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
    }
}

//
//  APIService.swift
//  Comico
//
//  Servicio singleton para comunicación con la API de MangaDex.
//  Usa URLSession directamente, compatible con iOS 9+. Sin dependencias externas.
//

import Foundation

// MARK: - APIError

/// Errores posibles de la capa de networking.
enum APIError: Error {
    /// No se pudo construir la URL del request.
    case invalidURL
    /// Error de red (sin conexión, timeout, etc.).
    case networkError(Error)
    /// El servidor devolvió un código HTTP no exitoso.
    case httpError(statusCode: Int)
    /// No se recibieron datos del servidor.
    case noData
    /// Error al decodificar la respuesta JSON.
    case decodingError(Error)
    /// Se superó el rate limit; reintentar después.
    case rateLimited
    /// Error desconocido.
    case unknown

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "URL inválida."
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .httpError(let code):
            return "Error HTTP: \(code)"
        case .noData:
            return "No se recibieron datos."
        case .decodingError(let error):
            return "Error al decodificar: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limit alcanzado. Intenta de nuevo en unos segundos."
        case .unknown:
            return "Error desconocido."
        }
    }
}

// MARK: - APIService

/// Singleton para interactuar con la API de MangaDex.
final class APIService {

    // MARK: - Singleton

    static let shared = APIService()

    // MARK: - Constants

    private let baseURL = "https://api.mangadex.org"
    private let coversBaseURL = "https://uploads.mangadex.org/covers"

    /// Número de elementos por página por defecto.
    private let defaultLimit = 20

    // MARK: - Rate Limiting

    /// MangaDex permite max 5 req/s. Mantenemos un historial de timestamps.
    private let maxRequestsPerSecond = 5
    private var requestTimestamps: [Date] = []
    private let rateLimitQueue = DispatchQueue(label: "com.comico.ratelimit")

    // MARK: - URLSession

    private let session: URLSession

    // MARK: - Init

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Obtiene los mangas más populares (ordenados por followedCount descendente).
    ///
    /// - Parameters:
    ///   - page: Número de página (0-indexed).
    ///   - completion: Closure con `Result<[Comic], APIError>`.
    func fetchPopularComics(page: Int = 0, completion: @escaping (Result<[Comic], APIError>) -> Void) {
        let offset = page * defaultLimit
        let params: [(String, String)] = [
            ("limit", String(defaultLimit)),
            ("offset", String(offset)),
            ("order[followedCount]", "desc"),
            ("includes[]", "cover_art"),
            ("includes[]", "author"),
            ("contentRating[]", "safe"),
            ("contentRating[]", "suggestive")
        ]

        guard let url = buildURL(path: "/manga", queryItems: params) else {
            completion(.failure(.invalidURL))
            return
        }

        performRequest(url: url) { (result: Result<MangaDexResponse<MangaDexMangaData>, APIError>) in
            switch result {
            case .success(let response):
                let comics = response.data.map { Comic(from: $0) }
                completion(.success(comics))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Busca mangas por título.
    ///
    /// - Parameters:
    ///   - query: Texto de búsqueda.
    ///   - page: Número de página (0-indexed).
    ///   - completion: Closure con `Result<[Comic], APIError>`.
    func searchComics(query: String, page: Int = 0, completion: @escaping (Result<[Comic], APIError>) -> Void) {
        let offset = page * defaultLimit
        let params: [(String, String)] = [
            ("title", query),
            ("limit", String(defaultLimit)),
            ("offset", String(offset)),
            ("order[relevance]", "desc"),
            ("includes[]", "cover_art"),
            ("includes[]", "author"),
            ("contentRating[]", "safe"),
            ("contentRating[]", "suggestive")
        ]

        guard let url = buildURL(path: "/manga", queryItems: params) else {
            completion(.failure(.invalidURL))
            return
        }

        performRequest(url: url) { (result: Result<MangaDexResponse<MangaDexMangaData>, APIError>) in
            switch result {
            case .success(let response):
                let comics = response.data.map { Comic(from: $0) }
                completion(.success(comics))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Obtiene los capítulos de un manga, filtrados por idioma (inglés y español).
    ///
    /// - Parameters:
    ///   - mangaId: ID del manga.
    ///   - page: Número de página (0-indexed).
    ///   - completion: Closure con `Result<[Chapter], APIError>`.
    func fetchChapters(mangaId: String, page: Int = 0, completion: @escaping (Result<[Chapter], APIError>) -> Void) {
        let offset = page * defaultLimit
        let params: [(String, String)] = [
            ("limit", String(defaultLimit)),
            ("offset", String(offset)),
            ("translatedLanguage[]", "en"),
            ("translatedLanguage[]", "es"),
            ("order[chapter]", "asc"),
            ("includes[]", "scanlation_group")
        ]

        guard let url = buildURL(path: "/manga/\(mangaId)/feed", queryItems: params) else {
            completion(.failure(.invalidURL))
            return
        }

        performRequest(url: url) { (result: Result<MangaDexResponse<MangaDexChapterData>, APIError>) in
            switch result {
            case .success(let response):
                let chapters = response.data.map { Chapter(from: $0) }
                completion(.success(chapters))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Obtiene las URLs de las páginas de un capítulo usando el endpoint at-home/server.
    ///
    /// - Parameters:
    ///   - chapterId: ID del capítulo.
    ///   - completion: Closure con `Result<[Page], APIError>`.
    func fetchPages(chapterId: String, completion: @escaping (Result<[Page], APIError>) -> Void) {
        guard let url = buildURL(path: "/at-home/server/\(chapterId)", queryItems: []) else {
            completion(.failure(.invalidURL))
            return
        }

        performRequest(url: url) { (result: Result<AtHomeResponse, APIError>) in
            switch result {
            case .success(let response):
                let baseUrl = response.baseUrl
                let hash = response.chapter.hash
                // Usar dataSaver para menor uso de datos
                let pages = response.chapter.data.map { filename -> Page in
                    let imageURL = "\(baseUrl)/data/\(hash)/\(filename)"
                    return Page(imageURL: imageURL)
                }
                completion(.success(pages))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Construye la URL completa de una portada de manga.
    ///
    /// - Parameters:
    ///   - mangaId: ID del manga.
    ///   - fileName: Nombre del archivo de la portada.
    /// - Returns: URL completa de la portada, o nil si los datos son inválidos.
    static func buildCoverURL(mangaId: String, fileName: String) -> String {
        return "https://uploads.mangadex.org/covers/\(mangaId)/\(fileName).256.jpg"
    }

    /// Versión de instancia para conveniencia.
    func fetchCoverURL(mangaId: String, fileName: String) -> String {
        return APIService.buildCoverURL(mangaId: mangaId, fileName: fileName)
    }

    // MARK: - Private Helpers

    /// Construye una URL con path y query items.
    private func buildURL(path: String, queryItems: [(String, String)]) -> URL? {
        // Usamos NSURLComponents para compatibilidad con iOS 9
        guard let components = NSURLComponents(string: baseURL + path) else {
            return nil
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems.map { NSURLQueryItem(name: $0.0, value: $0.1) as URLQueryItem }
        }

        return components.url
    }

    /// Ejecuta un request HTTP con rate limiting, decodifica la respuesta JSON.
    private func performRequest<T: Codable>(url: URL, completion: @escaping (Result<T, APIError>) -> Void) {
        // Verificar rate limit
        if !checkRateLimit() {
            // Esperar 200ms y reintentar
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.performRequest(url: url, completion: completion)
            }
            return
        }

        recordRequest()

        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // User-Agent recomendado por MangaDex
        request.setValue("Comico/1.0", forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request as URLRequest) { data, response, error in
            // Siempre despachar al main thread para UI
            let dispatchResult: (Result<T, APIError>) -> Void = { result in
                DispatchQueue.main.async {
                    completion(result)
                }
            }

            if let error = error {
                dispatchResult(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                dispatchResult(.failure(.unknown))
                return
            }

            // Rate limit de MangaDex (429)
            if httpResponse.statusCode == 429 {
                dispatchResult(.failure(.rateLimited))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                dispatchResult(.failure(.httpError(statusCode: httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                dispatchResult(.failure(.noData))
                return
            }

            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(T.self, from: data)
                dispatchResult(.success(decoded))
            } catch {
                dispatchResult(.failure(.decodingError(error)))
            }
        }
        task.resume()
    }

    // MARK: - Rate Limiting

    /// Verifica si podemos hacer una nueva petición sin superar el rate limit.
    private func checkRateLimit() -> Bool {
        var allowed = false
        rateLimitQueue.sync {
            let now = Date()
            // Remover timestamps más viejos que 1 segundo
            requestTimestamps = requestTimestamps.filter {
                now.timeIntervalSince($0) < 1.0
            }
            allowed = requestTimestamps.count < maxRequestsPerSecond
        }
        return allowed
    }

    /// Registra el timestamp de un request para el rate limiter.
    private func recordRequest() {
        rateLimitQueue.sync {
            requestTimestamps.append(Date())
        }
    }
}

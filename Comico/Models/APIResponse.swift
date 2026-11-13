//
//  APIResponse.swift
//  Comico
//
//  Wrappers genéricos para las respuestas de la API de MangaDex.
//

import Foundation

// MARK: - MangaDexResponse (lista paginada)

/// Respuesta genérica de MangaDex para endpoints que devuelven listas paginadas.
/// Ejemplo: GET /manga, GET /manga/{id}/feed
struct MangaDexResponse<T: Codable>: Codable {
    let result: String
    let response: String?
    let data: [T]
    let limit: Int
    let offset: Int
    let total: Int
}

// MARK: - MangaDexEntityResponse (entidad individual)

/// Respuesta de MangaDex para endpoints que devuelven una sola entidad.
/// Ejemplo: GET /manga/{id}
struct MangaDexEntityResponse<T: Codable>: Codable {
    let result: String
    let response: String?
    let data: T
}

// MARK: - RelationshipData

/// Representa una relación dentro de los datos de MangaDex.
/// Usada para enlazar mangas con autores, artistas, cover_art, etc.
struct RelationshipData: Codable {
    let id: String
    let type: String
    let attributes: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case attributes
    }
}

// MARK: - AnyCodableValue

/// Tipo auxiliar para decodificar valores JSON heterogéneos en los atributos
/// de las relaciones (que pueden ser String, Int, Bool, etc.).
/// Compatible con iOS 9 (no requiere `JSONValue` de iOS 16+).
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    /// Extrae el valor como `String?` si es de tipo string, o convierte desde otros tipos.
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return nil
        }
    }
}

// Permitir subscript directo en diccionarios de AnyCodableValue para obtener valores
// como tipos nativos de Swift.
extension Dictionary where Key == String, Value == AnyCodableValue {
    /// Subscript que devuelve el valor nativo (String, Int, etc.) de una clave.
    func nativeValue(forKey key: String) -> Any? {
        guard let value = self[key] else { return nil }
        switch value {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .null: return nil
        }
    }
}

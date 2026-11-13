//
//  String+HTML.swift
//  Comico
//
//  Extensión para limpiar etiquetas HTML de las descripciones de MangaDex.
//  Compatible con iOS 9+.
//

import Foundation

extension String {

    /// Elimina las etiquetas HTML y decodifica entidades HTML comunes,
    /// devolviendo texto plano limpio.
    ///
    /// Ejemplo:
    /// ```
    /// let html = "<p>Hola <b>mundo</b> &amp; amigos</p>"
    /// html.strippingHTML() // "Hola mundo & amigos"
    /// ```
    func strippingHTML() -> String {
        guard !self.isEmpty else { return self }

        var result = self

        // 1. Reemplazar <br>, <br/>, <br /> con saltos de línea
        result = result.replacingOccurrences(
            of: "<br\\s*/?>",
            with: "\n",
            options: .regularExpression,
            range: nil
        )

        // 2. Reemplazar </p>, </div>, </li> con salto de línea (separador de párrafo)
        result = result.replacingOccurrences(
            of: "</(?:p|div|li)>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive],
            range: nil
        )

        // 3. Eliminar todas las demás etiquetas HTML
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression,
            range: nil
        )

        // 4. Decodificar entidades HTML comunes
        result = result.decodingHTMLEntities()

        // 5. Colapsar múltiples saltos de línea en máximo 2
        result = result.replacingOccurrences(
            of: "\\n{3,}",
            with: "\n\n",
            options: .regularExpression,
            range: nil
        )

        // 6. Eliminar espacios al inicio y final, y líneas vacías al principio/final
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }

    /// Decodifica las entidades HTML más comunes a sus caracteres correspondientes.
    private func decodingHTMLEntities() -> String {
        var result = self

        // Entidades con nombre
        let namedEntities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&laquo;", "«"),
            ("&raquo;", "»"),
            ("&hellip;", "…"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™"),
            ("&euro;", "€"),
            ("&pound;", "£"),
            ("&yen;", "¥"),
            ("&iexcl;", "¡"),
            ("&iquest;", "¿")
        ]

        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Entidades numéricas decimales: &#123;
        result = decodeNumericEntities(result, pattern: "&#(\\d+);") { Int($0) }

        // Entidades numéricas hexadecimales: &#x1F4A9;
        result = decodeNumericEntities(result, pattern: "&#[xX]([0-9a-fA-F]+);") {
            Int($0, radix: 16)
        }

        return result
    }

    /// Decodifica entidades numéricas (decimales o hexadecimales) del texto.
    private func decodeNumericEntities(_ text: String, pattern: String, parser: (String) -> Int?) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        var result = text
        let nsString = text as NSString
        // Procesar matches en reversa para no invalidar rangos
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let fullRange = match.range(at: 0)
            let numberRange = match.range(at: 1)
            let numberString = nsString.substring(with: numberRange)

            if let codePoint = parser(numberString),
               let scalar = UnicodeScalar(codePoint) {
                let replacement = String(Character(scalar))
                result = (result as NSString).replacingCharacters(in: fullRange, with: replacement)
            }
        }

        return result
    }
}

import UIKit

struct AppColors {
    static let primary = UIColor(red: 255.0/255.0, green: 107.0/255.0, blue: 53.0/255.0, alpha: 1.0)   // #FF6B35
    static let dark = UIColor(red: 26.0/255.0, green: 26.0/255.0, blue: 46.0/255.0, alpha: 1.0)        // #1A1A2E
    static let lightGray = UIColor(red: 232.0/255.0, green: 232.0/255.0, blue: 232.0/255.0, alpha: 1.0) // #E8E8E8
    static let background = UIColor.white
    static let textPrimary = UIColor(red: 26.0/255.0, green: 26.0/255.0, blue: 46.0/255.0, alpha: 1.0)
    static let textSecondary = UIColor.gray
    static let cardBackground = UIColor.white
    static let shadow = UIColor.black
}

struct AppFonts {
    static func bold(size: CGFloat) -> UIFont {
        return UIFont.boldSystemFont(ofSize: size)
    }

    static func regular(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size)
    }

    static func medium(size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .medium)
    }

    static let titleLarge = UIFont.boldSystemFont(ofSize: 24)
    static let titleMedium = UIFont.boldSystemFont(ofSize: 18)
    static let titleSmall = UIFont.boldSystemFont(ofSize: 16)
    static let body = UIFont.systemFont(ofSize: 14)
    static let caption = UIFont.systemFont(ofSize: 12)
    static let small = UIFont.systemFont(ofSize: 10)
}

struct AppSpacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let standard: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32

    static let cellCornerRadius: CGFloat = 12
    static let badgeCornerRadius: CGFloat = 8
    static let buttonCornerRadius: CGFloat = 10
    static let shadowRadius: CGFloat = 4
    static let shadowOpacity: Float = 0.12
}

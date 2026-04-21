import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let primary      = Color("Primary")       // warm sage green
    static let accent       = Color("Accent")        // warm orange
    static let background   = Color("Background")
    static let surface      = Color("Surface")
    static let textPrimary  = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let success      = Color("Success")
    static let warning      = Color("Warning")
    static let error        = Color("Error")

    // Fallback system colors (used in previews and before asset catalog is set up)
    static var primaryFallback:       Color { Color(red: 0.36, green: 0.54, blue: 0.44) }
    static var accentFallback:        Color { Color(red: 0.91, green: 0.58, blue: 0.36) }
    static var surfaceFallback:       Color { Color(UIColor.secondarySystemBackground) }
    static var successFallback:       Color { Color.green }
    static var warningFallback:       Color { Color.orange }
    static var errorFallback:         Color { Color.red }

    // MARK: - Typography
    enum Font {
        static func headline(_ size: CGFloat = 22) -> SwiftUI.Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static func title(_ size: CGFloat = 18) -> SwiftUI.Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }
        static func body(_ size: CGFloat = 16) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .rounded)
        }
        static func caption(_ size: CGFloat = 13) -> SwiftUI.Font {
            .system(size: size, weight: .regular, design: .rounded)
        }
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat  = 4
        static let s:  CGFloat  = 8
        static let m:  CGFloat  = 16
        static let l:  CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let s: CGFloat  = 8
        static let m: CGFloat  = 12
        static let l: CGFloat  = 20
        static let xl: CGFloat = 28
    }
}

// Convenience extensions for card shadow
extension View {
    func cardStyle() -> some View {
        self
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(AppTheme.Radius.m)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

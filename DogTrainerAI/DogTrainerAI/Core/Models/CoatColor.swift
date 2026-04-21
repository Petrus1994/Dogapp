import SwiftUI

enum CoatColor: String, Codable, CaseIterable, Identifiable {
    case black
    case white
    case brown
    case golden
    case gray
    case cream
    case red
    case merle
    case brindle
    case tricolor
    case spotted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black:    return "Black"
        case .white:    return "White"
        case .brown:    return "Brown"
        case .golden:   return "Golden"
        case .gray:     return "Gray"
        case .cream:    return "Cream"
        case .red:      return "Red"
        case .merle:    return "Merle"
        case .brindle:  return "Brindle"
        case .tricolor: return "Tricolor"
        case .spotted:  return "Spotted"
        }
    }

    // Primary body fill color
    var primary: Color {
        switch self {
        case .black:    return Color(red: 0.13, green: 0.13, blue: 0.13)
        case .white:    return Color(red: 0.95, green: 0.93, blue: 0.90)
        case .brown:    return Color(red: 0.55, green: 0.30, blue: 0.12)
        case .golden:   return Color(red: 0.90, green: 0.68, blue: 0.25)
        case .gray:     return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .cream:    return Color(red: 0.96, green: 0.88, blue: 0.72)
        case .red:      return Color(red: 0.75, green: 0.30, blue: 0.10)
        case .merle:    return Color(red: 0.50, green: 0.60, blue: 0.75)
        case .brindle:  return Color(red: 0.45, green: 0.28, blue: 0.14)
        case .tricolor: return Color(red: 0.15, green: 0.12, blue: 0.10)
        case .spotted:  return Color(red: 0.90, green: 0.85, blue: 0.75)
        }
    }

    // Secondary color (muzzle, chest, paws)
    var secondary: Color {
        switch self {
        case .black:    return Color(red: 0.75, green: 0.60, blue: 0.40)
        case .white:    return Color(red: 0.85, green: 0.82, blue: 0.78)
        case .brown:    return Color(red: 0.80, green: 0.60, blue: 0.35)
        case .golden:   return Color(red: 0.98, green: 0.85, blue: 0.55)
        case .gray:     return Color(red: 0.78, green: 0.78, blue: 0.80)
        case .cream:    return Color(red: 1.0,  green: 0.96, blue: 0.88)
        case .red:      return Color(red: 0.90, green: 0.65, blue: 0.30)
        case .merle:    return Color(red: 0.75, green: 0.80, blue: 0.90)
        case .brindle:  return Color(red: 0.70, green: 0.50, blue: 0.25)
        case .tricolor: return Color(red: 0.90, green: 0.78, blue: 0.40)
        case .spotted:  return Color(red: 0.30, green: 0.22, blue: 0.15)
        }
    }

    // Accent (nose, eye rims, details)
    var accent: Color {
        switch self {
        case .white, .cream: return Color(red: 0.20, green: 0.15, blue: 0.10)
        default:             return Color(red: 0.10, green: 0.08, blue: 0.06)
        }
    }

    // Swatch color for picker UI
    var swatchColor: Color { primary }

    // Whether to use dark text labels on this background
    var needsDarkLabel: Bool {
        switch self {
        case .white, .cream, .golden: return true
        default:                      return false
        }
    }
}

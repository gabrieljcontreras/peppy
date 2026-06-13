import SwiftUI

extension Color {
    // MARK: - Primary
    static let pepPrimary = Color(hex: "FF5A52")
    static let pepPrimaryLight = Color(hex: "FF8B84")
    static let pepPrimaryDark = Color(hex: "E74842")
    static let pepPrimaryMuted = Color(hex: "FFF0ED")

    // MARK: - Background & Surface
    static let pepBackground = Color(hex: "FDF9F6")
    static let pepSurface = Color.white
    static let pepSurfaceElevated = Color(hex: "F8F3EF")
    static let pepBorder = Color(hex: "E8E2DE")
    static let pepBorderLight = Color(hex: "F1ECE8")

    // MARK: - Text
    static let pepTextPrimary = Color(hex: "1C1D20")
    static let pepTextSecondary = Color(hex: "6F7278")
    static let pepTextTertiary = Color(hex: "A7A5A3")

    // MARK: - Status
    static let pepSuccess = Color(hex: "42B883")
    static let pepSuccessMuted = Color(hex: "EAF8F1")
    static let pepWarning = Color(hex: "F1A33B")
    static let pepWarningMuted = Color(hex: "FFF5E6")
    static let pepError = Color(hex: "FF5A52")
    static let pepErrorMuted = Color(hex: "FFF0ED")
    static let pepInfo = Color(hex: "5599E8")
    static let pepInfoMuted = Color(hex: "EDF5FE")
    static let pepInk = Color(hex: "1C1D20")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

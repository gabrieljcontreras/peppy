import SwiftUI

extension Color {
    // MARK: - Primary
    static let pepPrimary = Color(hex: "E07A5F")
    static let pepPrimaryLight = Color(hex: "F2CC8F")
    static let pepPrimaryDark = Color(hex: "C45C3E")
    static let pepPrimaryMuted = Color(hex: "D4A373")

    // MARK: - Background & Surface (Dark Mode Default)
    static let pepBackground = Color(hex: "1C1917")
    static let pepSurface = Color(hex: "292524")
    static let pepSurfaceElevated = Color(hex: "44403C")
    static let pepBorder = Color(hex: "44403C")
    static let pepBorderLight = Color(hex: "57534E")

    // MARK: - Text
    static let pepTextPrimary = Color(hex: "FAFAF9")
    static let pepTextSecondary = Color(hex: "A8A29E")
    static let pepTextTertiary = Color(hex: "78716C")

    // MARK: - Status
    static let pepSuccess = Color(hex: "81B29A")
    static let pepSuccessMuted = Color(hex: "81B29A").opacity(0.15)
    static let pepWarning = Color(hex: "F2CC8F")
    static let pepWarningMuted = Color(hex: "F2CC8F").opacity(0.15)
    static let pepError = Color(hex: "E07A5F")
    static let pepErrorMuted = Color(hex: "E07A5F").opacity(0.15)
    static let pepInfo = Color(hex: "7EB8C9")
    static let pepInfoMuted = Color(hex: "7EB8C9").opacity(0.15)
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

import SwiftUI

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum CornerRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let full: CGFloat = 9999
}

extension View {
    func pepCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    func pepElevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
    }
}

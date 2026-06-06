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
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let full: CGFloat = 9999
}

extension View {
    func pepCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
    }

    func pepElevatedShadow() -> some View {
        self.shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 4)
    }
}

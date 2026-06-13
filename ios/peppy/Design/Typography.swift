import SwiftUI

extension View {
    func pepLargeTitle() -> some View {
        self.font(.system(size: 36, weight: .bold, design: .rounded))
            .foregroundColor(.pepTextPrimary)
    }

    func pepTitle() -> some View {
        self.font(.system(size: 30, weight: .bold, design: .rounded))
            .foregroundColor(.pepTextPrimary)
    }

    func pepTitle2() -> some View {
        self.font(.system(size: 24, weight: .bold, design: .rounded))
            .foregroundColor(.pepTextPrimary)
    }

    func pepTitle3() -> some View {
        self.font(.title3).fontWeight(.semibold)
            .foregroundColor(.pepTextPrimary)
    }

    func pepHeadline() -> some View {
        self.font(.headline)
            .foregroundColor(.pepTextPrimary)
    }

    func pepBody() -> some View {
        self.font(.body)
            .foregroundColor(.pepTextPrimary)
    }

    func pepCallout() -> some View {
        self.font(.callout)
            .foregroundColor(.pepTextPrimary)
    }

    func pepSubheadline() -> some View {
        self.font(.subheadline)
            .foregroundColor(.pepTextSecondary)
    }

    func pepFootnote() -> some View {
        self.font(.footnote)
            .foregroundColor(.pepTextSecondary)
    }

    func pepCaption() -> some View {
        self.font(.caption)
            .foregroundColor(.pepTextTertiary)
    }
}

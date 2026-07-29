import CoreText
import SwiftUI
import UIKit

/// Fraunces Italic — the accent face the marketing site uses for emphasis
/// (`font-serif italic font-medium`). Bundled as a variable font and
/// registered at runtime: the app target generates its Info.plist from build
/// settings and has no plist file to add `UIAppFonts` to.
enum PeppyFonts {
    static let premiumFamilyName = "Fraunces"

    private static let registerOnce: Void = {
        guard let url = Bundle.main.url(
            forResource: "Fraunces-Italic",
            withExtension: "ttf"
        ) else {
            assertionFailure("Fraunces-Italic.ttf is missing from the bundle")
            return
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            assertionFailure("Failed to register Fraunces: \(String(describing: error))")
        }
    }()

    /// Weight 500 italic, matching the site's `font-medium`. Falls back to the
    /// system serif italic if registration or descriptor matching fails, so a
    /// bundling mistake degrades instead of rendering nothing.
    static func premiumItalicUIFont(size: CGFloat) -> UIFont {
        _ = registerOnce

        let variationAxisWeight = 2003265652 // 'wght' as a four-char code
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: premiumFamilyName,
            kCTFontVariationAttribute as UIFontDescriptor.AttributeName: [
                variationAxisWeight: 500
            ]
        ])

        let italic = descriptor.withSymbolicTraits(.traitItalic) ?? descriptor
        let candidate = UIFont(descriptor: italic, size: size)

        guard candidate.familyName == premiumFamilyName else {
            let fallback = UIFont.systemFont(ofSize: size, weight: .medium)
            let serif = fallback.fontDescriptor
                .withDesign(.serif)?
                .withSymbolicTraits(.traitItalic)
            return serif.map { UIFont(descriptor: $0, size: size) } ?? fallback
        }

        return candidate
    }
}

extension Font {
    /// The "Premium" half of the paywall headline.
    static func peppyPremiumItalic(size: CGFloat) -> Font {
        Font(PeppyFonts.premiumItalicUIFont(size: size))
    }
}

import SwiftUI

struct PeppyLogo: View {
    var size: CGFloat = 38
    var showsWordmark = false

    var body: some View {
        Group {
            if showsWordmark {
                Image("PeppyLogoWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: size * 1.2)
            } else {
                Image("PeppyLogoMark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: size)
            }
        }
        /*
         The exported wordmark includes its original Figma background so the
         letterforms and spacing remain pixel-identical to the supplied design.
         */
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Peppy")
    }
}

#Preview {
    PeppyLogo(size: 54, showsWordmark: true)
        .padding()
        .background(Color.pepBackground)
}

import SafariServices
import SwiftUI

enum PeppyWebDestination: String, CaseIterable, Identifiable {
    case help
    case contact
    case bug
    case feature
    case about
    case terms
    case privacy
    case privacySecurity

    var id: Self { self }

    var url: URL {
        switch self {
        case .help:
            URL(string: "https://get-peppy.com/help")!
        case .contact:
            URL(string: "https://get-peppy.com/contact")!
        case .bug:
            URL(string: "https://get-peppy.com/feedback/bug")!
        case .feature:
            URL(string: "https://get-peppy.com/feedback/feature")!
        case .about:
            URL(string: "https://get-peppy.com/about")!
        case .terms:
            URL(string: "https://get-peppy.com/terms")!
        case .privacy:
            URL(string: "https://get-peppy.com/privacy")!
        case .privacySecurity:
            URL(string: "https://get-peppy.com/privacy#security")!
        }
    }
}

/// Browser destinations are represented by `PeppyWebDestination` instead of a
/// raw URL so settings UI cannot accidentally open an unreviewed web address.
struct InAppBrowserView: UIViewControllerRepresentable {
    let destination: PeppyWebDestination

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.barCollapsingEnabled = true
        let controller = SFSafariViewController(
            url: destination.url,
            configuration: configuration
        )
        controller.preferredControlTintColor = UIColor(Color.pepPrimary)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}
}

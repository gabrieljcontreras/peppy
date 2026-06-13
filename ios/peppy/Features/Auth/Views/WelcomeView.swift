import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = proxy.size.width

                VStack(spacing: 0) {
                    PeppyLogo(size: 52, showsWordmark: true)
                        .padding(.top, 30)

                    VStack(spacing: 12) {
                        Text("Your protocol,")
                            .font(.system(size: 35, weight: .bold))
                            .foregroundColor(.pepTextPrimary)

                        Text("understood.")
                            .font(.system(size: 39, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundColor(.pepPrimary)
                            .offset(y: -8)
                    }
                    .padding(.top, 30)

                    Text("Track your peptide protocol, daily check-ins,\nweight, symptoms, labs, and wearable data\nin one private place.")
                        .font(.system(size: 14))
                        .foregroundColor(.pepTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.top, 10)

                    Image("WelcomeHero")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width - 18)
                        .padding(.top, 4)

                    Spacer(minLength: 4)

                    VStack(spacing: 11) {
                        PepButton(title: "Create account", style: .primary) {
                            showRegister = true
                        }

                        PepButton(title: "Sign in", style: .secondary) {
                            showLogin = true
                        }
                    }
                    .padding(.horizontal, 32)

                    Label(
                        "Your health data stays private and encrypted.",
                        systemImage: "lock"
                    )
                    .font(.system(size: 11))
                    .foregroundColor(.pepTextSecondary)
                    .symbolRenderingMode(.monochrome)
                    .padding(.top, 18)
                    .padding(.bottom, 8)
                }
                .frame(width: width, height: proxy.size.height)
            }
            .background(Color.pepBackground.ignoresSafeArea())
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
        .tint(.pepTextPrimary)
    }
}

#Preview {
    WelcomeView()
        .withDependencies(.mock())
}

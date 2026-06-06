import SwiftUI

struct WelcomeView: View {
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()

                VStack(spacing: Spacing.md) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pepPrimary, .pepPrimaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Peppy")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.pepTextPrimary)

                    Text("Your personalized peptide protocol engine")
                        .font(.title3)
                        .foregroundColor(.pepTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                }

                Spacer()

                VStack(spacing: Spacing.md) {
                    PepButton(title: "Get Started", style: .primary) {
                        showRegister = true
                    }

                    PepButton(title: "I Already Have an Account", style: .ghost) {
                        showLogin = true
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pepBackground)
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
}

#Preview {
    WelcomeView()
        .withDependencies(.mock())
}

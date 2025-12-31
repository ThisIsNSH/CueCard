import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo and Title
            VStack(spacing: 16) {
                Image("Icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48)

                Text("CueCard")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Teleprompter for everything")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Error message
            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Sign in button
            Button(action: {
                Task {
                    await authService.signInWithGoogle()
                }
            }) {
                HStack(spacing: 12) {
                    Image("GoogleLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    Text("Continue with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .disabled(authService.isLoading)
            .opacity(authService.isLoading ? 0.6 : 1)
            .padding(.horizontal, 32)

            if authService.isLoading {
                ProgressView()
                    .padding(.top, 8)
            }

            Spacer()
                .frame(height: 60)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationService.shared)
}

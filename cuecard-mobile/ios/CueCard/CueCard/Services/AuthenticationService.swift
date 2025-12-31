import Foundation
import FirebaseAuth
import FirebaseAnalytics
import GoogleSignIn
import FirebaseCore

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()

    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private init() {
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil

            if let user = user {
                Analytics.setUserID(user.uid)
                Analytics.logEvent(AnalyticsEventLogin, parameters: [
                    AnalyticsParameterMethod: "google"
                ])
            }
        }
    }

    func signInWithGoogle() async {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase configuration error"
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to get root view controller"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Unable to get ID token"
                isLoading = false
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )

            try await Auth.auth().signIn(with: credential)

            Analytics.logEvent("sign_in_success", parameters: nil)
        } catch {
            errorMessage = error.localizedDescription
            Analytics.logEvent("sign_in_error", parameters: [
                "error": error.localizedDescription
            ])
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            Analytics.logEvent("sign_out", parameters: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

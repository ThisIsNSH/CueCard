import SwiftUI
import FirebaseAnalytics

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showingProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Welcome message
                if let user = authService.user {
                    VStack(spacing: 8) {
                        Text("Welcome back!")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(user.displayName ?? user.email ?? "User")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                }

                Spacer()

                // Placeholder for flashcard content
                VStack(spacing: 16) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Your flashcards will appear here")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("CueCard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingProfile = true }) {
                        Image(systemName: "person.circle")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
        }
        .onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: "home"
            ])
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthenticationService.shared)
}

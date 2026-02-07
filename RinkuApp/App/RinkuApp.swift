import SwiftUI

@main
struct RinkuApp: App {
    @StateObject private var store = AppStore.shared
    @StateObject private var wearablesService = WearablesService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(wearablesService)
                // Handle URL callback from Meta AI app for glasses registration
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                // Alert for wearables errors
                .alert("Glasses Error", isPresented: $wearablesService.showError) {
                    Button("OK") {
                        wearablesService.dismissError()
                    }
                } message: {
                    Text(wearablesService.errorMessage)
                }
        }
    }
    
    /// Handle URL callbacks from external apps (Meta AI for glasses registration)
    private func handleOpenURL(_ url: URL) {
        // Check if this is a Meta Wearables callback
        guard url.scheme == "rinkuapp" else { return }
        
        Task {
            let handled = await wearablesService.handleURL(url)
            if handled {
                print("[RinkuApp] Handled Meta Wearables URL callback")
            }
        }
    }
}

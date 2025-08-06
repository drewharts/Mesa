import Firebase
import FirebaseAuth

// Add this temporary function to your app to get a token for testing
func getFirebaseTokenForTesting() {
    Task {
        guard let user = Auth.auth().currentUser else {
            print("No user logged in")
            return
        }
        
        do {
            let token = try await user.getIDToken()
            print("=== FIREBASE TOKEN FOR TESTING ===")
            print(token)
            print("=================================")
            
            // Also copy to clipboard if on iOS
            UIPasteboard.general.string = token
            print("Token copied to clipboard!")
        } catch {
            print("Error getting token: \(error)")
        }
    }
}
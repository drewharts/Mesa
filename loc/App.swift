class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // ... existing Firebase setup code ...
        
        // Run migrations
        let reviewLikesMigration = ReviewLikesMigration()
        reviewLikesMigration.migrate { error in
            if let error = error {
                print("Failed to migrate reviews: \(error.localizedDescription)")
            } else {
                print("Successfully completed review likes migration")
            }
        }
        
        let migrationManager = MigrationManager()
        migrationManager.runMigrations { error in
            if let error = error {
                print("Failed to run migrations: \(error.localizedDescription)")
            } else {
                print("Successfully completed all migrations")
            }
        }
        
        return true
    }
} 
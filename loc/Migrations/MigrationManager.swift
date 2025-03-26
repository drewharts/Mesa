import Foundation
import Firebase
import Network

class MigrationManager {
    static let shared = MigrationManager()
    private let defaults = UserDefaults.standard
    private var networkMonitor: NWPathMonitor?
    private var currentMigration: Any?
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 2.0
    
    private init() {
        print("MigrationManager initialized")
        defaults.set(false, forKey: "AddOpenHoursFieldMigrationCompleted")
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            let status = path.status == .satisfied ? "Connected" : "Disconnected"
            print("Network status updated: \(status)")
            
            // If network becomes available and we have a pending migration, try again
            if path.status == .satisfied {
                self?.checkFirebaseConnection()
            }
        }
        networkMonitor?.start(queue: DispatchQueue.global())
    }
    
    private func checkFirebaseConnection(completion: ((Bool) -> Void)? = nil) {
        // Try to make a small read from Firestore to verify connection
        let db = Firestore.firestore()
        db.collection("places").limit(to: 1).getDocuments { _, error in
            let isConnected = error == nil
            print("Firebase connection check: \(isConnected ? "✅ Connected" : "❌ Failed")")
            completion?(isConnected)
        }
    }
    
    func runMigrations(completion: @escaping (Error?) -> Void) {
        print("Starting migrations check...")
        
        guard let monitor = networkMonitor, monitor.currentPath.status == .satisfied else {
            print("⚠️ No network connection available")
            retryMigration(retriesLeft: maxRetries, completion: completion)
            return
        }
        
        // Check Firebase connection before proceeding
        checkFirebaseConnection { isConnected in
            if isConnected {
                self.runActualMigration(completion: completion)
            } else {
                print("⚠️ Firebase connection not available")
                self.retryMigration(retriesLeft: self.maxRetries, completion: completion)
            }
        }
    }
    
    private func retryMigration(retriesLeft: Int, completion: @escaping (Error?) -> Void) {
        guard retriesLeft > 0 else {
            let error = NSError(domain: "MigrationManager", 
                              code: 0, 
                              userInfo: [NSLocalizedDescriptionKey: "Failed to establish connection after \(maxRetries) retries"])
            completion(error)
            return
        }
        
        print("⏳ Retrying migration in \(retryDelay) seconds... (\(retriesLeft) attempts remaining)")
        
        DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            guard let self = self else { return }
            
            if self.networkMonitor?.currentPath.status == .satisfied {
                self.checkFirebaseConnection { isConnected in
                    if isConnected {
                        self.runActualMigration(completion: completion)
                    } else {
                        self.retryMigration(retriesLeft: retriesLeft - 1, completion: completion)
                    }
                }
            } else {
                self.retryMigration(retriesLeft: retriesLeft - 1, completion: completion)
            }
        }
    }
    
    private func runActualMigration(completion: @escaping (Error?) -> Void) {
        if !defaults.bool(forKey: "AddOpenHoursFieldMigrationCompleted") {
            print("AddOpenHoursField migration hasn't been run yet, starting now...")
            let migration = AddOpenHoursFieldMigration()
            currentMigration = migration
            
            migration.migrate { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Migration failed: \(error.localizedDescription)")
                    completion(error)
                } else {
                    self.defaults.set(true, forKey: "AddOpenHoursFieldMigrationCompleted")
                    print("✅ Migration completed successfully!")
                    completion(nil)
                }
                self.currentMigration = nil
            }
        } else {
            print("✅ All migrations already completed")
            completion(nil)
        }
    }
    
    deinit {
        networkMonitor?.cancel()
    }
}

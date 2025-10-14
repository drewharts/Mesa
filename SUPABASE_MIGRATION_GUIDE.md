# Mesa App - Supabase Migration Guide

This guide walks you through completing the migration from Firebase to Supabase.

## ✅ What's Already Done

The following components have been created and are ready to use:

1. ✅ **SupabaseManager.swift** - Main Supabase client wrapper
2. ✅ **SupabaseConfig.swift** - Configuration (needs your credentials)
3. ✅ **SupabaseAuthService.swift** - Authentication service
4. ✅ **SupabaseUserService.swift** - User management
5. ✅ **SupabasePlaceService.swift** - Place management with PostGIS
6. ✅ **SupabaseReviewService.swift** - Reviews and comments
7. ✅ **SupabaseRealtimeService.swift** - Real-time subscriptions
8. ✅ **supabase_schema.sql** - Database schema with PostGIS
9. ✅ **supabase_rls_policies.sql** - Row-Level Security policies

## 🚀 Step 1: Install Supabase SDK

Follow the instructions in `SUPABASE_SETUP_INSTRUCTIONS.md` to:
1. Add the Supabase Swift package to Xcode
2. Get your Supabase project credentials
3. Update `SupabaseConfig.swift` with your credentials

## 📊 Step 2: Set Up Supabase Database

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Create a new project (or use an existing one)
3. Go to **SQL Editor**
4. Run `supabase_schema.sql` (creates tables, indexes, functions)
5. Run `supabase_rls_policies.sql` (sets up security)
6. Go to **Database** > **Extensions** and verify PostGIS is enabled

### Create Storage Buckets

Go to **Storage** in your Supabase Dashboard and create these buckets:

1. **profile_photos** (private)
2. **review_photos** (public)
3. **comment_photos** (public)
4. **list_covers** (public)

For each bucket, set the policies as defined in `supabase_rls_policies.sql`.

## 🔄 Step 3: Update ServiceContainer

Update `ServiceContainer.swift` to use Supabase services:

```swift
class ServiceContainer {
    static let shared = ServiceContainer()
    
    // Replace Firebase services with Supabase services
    let userService: SupabaseUserService
    let placeService: SupabasePlaceService
    let reviewService: SupabaseReviewService
    let authService: SupabaseAuthService
    let realtimeService: SupabaseRealtimeService
    
    // Keep existing services
    let locationManager: LocationManager
    let imageService: ImageService
    let tikTokService: TikTokService
    // ... other services
    
    private init() {
        // Initialize Supabase services
        self.authService = SupabaseAuthService.shared
        self.userService = SupabaseUserService.shared
        self.placeService = SupabasePlaceService.shared
        self.reviewService = SupabaseReviewService.shared
        self.realtimeService = SupabaseRealtimeService.shared
        
        // Initialize other services
        self.locationManager = LocationManager()
        self.imageService = ImageService.shared
        self.tikTokService = TikTokService()
        // ... other services
    }
    
    func setupServices() {
        // Any additional setup
    }
}
```

## 🔧 Step 4: Update UserSession

Update `UserSession.swift` to use Supabase auth:

```swift
import Supabase

@MainActor
class UserSession: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userUID: String?
    
    private let authService = SupabaseAuthService.shared
    private let userService: SupabaseUserService
    // ... other dependencies
    
    init(userService: SupabaseUserService, ...) {
        self.userService = userService
        // ... other initializations
        
        // Check for existing session
        Task {
            await checkSession()
        }
    }
    
    func checkSession() async {
        if let session = try? await authService.getSession() {
            self.isLoggedIn = true
            self.userUID = session.user.id.uuidString
        }
    }
    
    func setUserLoggedIn(uid: String) {
        self.isLoggedIn = true
        self.userUID = uid
    }
    
    func signOut() async throws {
        try await authService.signOut()
        self.isLoggedIn = false
        self.userUID = nil
    }
}
```

## 📱 Step 5: Update locApp.swift

Replace Firebase initialization with Supabase:

```swift
import SwiftUI
import Supabase  // Replace Firebase imports

@main
struct locApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // ... existing StateObjects
    
    init() {
        // REMOVE: FirebaseApp.configure()
        // REMOVE: AppCheck configuration
        
        // Supabase is already initialized in SupabaseManager
        
        // Get services from container (now using Supabase)
        let services = ServiceContainer.shared
        services.setupServices()
        
        // ... rest of initialization (same as before)
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                // ... existing environment objects
                .task {
                    // Replace Auth.auth().currentUser with Supabase
                    if let currentUser = await authService.currentUser {
                        let userId = currentUser.id.uuidString
                        userSession.setUserLoggedIn(uid: userId)
                        await dataManager.initializeProfileData(userId: userId)
                        
                        // Set up real-time subscriptions
                        try? await setupRealtimeSubscriptions(userId: userId)
                    }
                }
        }
    }
    
    private func setupRealtimeSubscriptions(userId: String) async throws {
        let realtimeService = ServiceContainer.shared.realtimeService
        
        // Subscribe to notifications
        try await realtimeService.subscribeNotifications(userId: userId) { notification in
            // Handle new notification
            print("🔔 New notification: \(notification.message ?? "")")
        }
        
        // Subscribe to followers
        try await realtimeService.subscribeFollowers(userId: userId) { follower in
            // Handle new follower
            print("👥 New follower: \(follower.follower_id)")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var userService: SupabaseUserService?  // Changed from UserService
    // ... rest of AppDelegate (FCM setup stays the same)
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Keep FCM setup (Firebase Messaging can still be used for push notifications)
        // Or migrate to Supabase push notifications if preferred
        
        return true
    }
}
```

## 🗺️ Step 6: Update MapViewModel

The MapViewModel already has the structure to support Supabase. Update the service calls:

```swift
@MainActor
class MapViewModel: ObservableObject {
    // ... existing properties
    
    private let placeService: SupabasePlaceService  // Changed type
    
    init(placeService: SupabasePlaceService, detailPlaceVM: DetailPlaceViewModel) {
        self.placeService = placeService
        self.detailPlaceVM = detailPlaceVM
    }
    
    // The viewport loading methods work the same!
    // Supabase PlaceService has the same method signatures
    private func loadPlacesForViewport(_ region: MKCoordinateRegion) async {
        // ... existing code works as-is
        // The SupabasePlaceService has the same method signatures
    }
}
```

## 📦 Step 7: Update DataManager

The DataManager uses the services, so just update the type annotations:

```swift
@MainActor
class DataManager: ObservableObject {
    // Update service types
    private let userService: SupabaseUserService
    private let placeService: SupabasePlaceService
    private let reviewService: SupabaseReviewService
    
    // ... rest stays the same! The methods have the same signatures
    
    init(
        userService: SupabaseUserService,
        placeService: SupabasePlaceService,
        reviewService: SupabaseReviewService,
        // ... other dependencies
    ) {
        self.userService = userService
        self.placeService = placeService
        self.reviewService = reviewService
        // ... other initializations
    }
    
    // All existing methods work as-is!
    // The Supabase services have compatibility methods with the same signatures
}
```

## 🔐 Step 8: Update Authentication Views

Update your sign-in/sign-up views to use SupabaseAuthService:

```swift
// In your sign-in view
@EnvironmentObject var authService: SupabaseAuthService

func signIn() async {
    do {
        let session = try await authService.signIn(
            email: email,
            password: password
        )
        
        // User is now signed in
        userSession.setUserLoggedIn(uid: session.user.id.uuidString)
        
    } catch {
        print("Sign in error: \(error.localizedDescription)")
    }
}
```

## 🖼️ Step 9: Update Image Uploads

Update image upload code to use Supabase Storage:

```swift
// Example: Upload profile photo
func uploadProfilePhoto(image: UIImage, userId: String) async throws -> String {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        throw NSError(domain: "ImageUpload", code: -1)
    }
    
    let fileName = "\(userId)_\(Date().timeIntervalSince1970).jpg"
    let path = "\(userId)/\(fileName)"
    
    // Upload to Supabase Storage
    try await SupabaseManager.shared.storage
        .from("profile_photos")
        .upload(
            path: path,
            file: imageData,
            options: FileOptions(contentType: "image/jpeg")
        )
    
    // Get public URL
    let url = try SupabaseManager.shared.storage
        .from("profile_photos")
        .getPublicURL(path: path)
    
    return url.absoluteString
}
```

## 📡 Step 10: Add Real-Time Features

Add real-time subscriptions where needed:

```swift
// In a review detail view
class ReviewDetailViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    
    private let realtimeService = SupabaseRealtimeService.shared
    
    func subscribeToComments(reviewId: String) async {
        try? await realtimeService.subscribeComments(reviewId: reviewId) { newComment in
            Task { @MainActor in
                self.comments.append(newComment)
            }
        }
    }
    
    func unsubscribe() async {
        await realtimeService.unsubscribeAll()
    }
}
```

## 🧪 Step 11: Testing

1. **Test Authentication**
   - Sign up new users
   - Sign in existing users
   - Sign out
   - Password reset

2. **Test Database Operations**
   - Create/read/update/delete places
   - Add/remove favorites
   - Create/edit lists
   - Post reviews and comments

3. **Test Real-Time**
   - Open two devices/simulators
   - Perform actions on one, see updates on the other

4. **Test RLS Security**
   - Try to access another user's private data
   - Verify proper access controls

## 🔄 Step 12: Data Migration (Optional)

If you have existing Firebase data to migrate:

1. Export Firebase data using Firebase Console or Admin SDK
2. Transform the data to match Supabase schema
3. Import using Supabase SQL Editor or REST API
4. Verify data integrity

Example migration script structure:

```typescript
// firebase-to-supabase-migration.ts
import { createClient } from '@supabase/supabase-js'
import admin from 'firebase-admin'

// Export from Firebase
const firebaseData = await exportFirebaseData()

// Transform to Supabase format
const supabaseData = transformData(firebaseData)

// Import to Supabase
await importToSupabase(supabaseData)
```

## 📊 Step 13: Performance Monitoring

Monitor the migration:

1. Check Supabase Dashboard > Database > Performance
2. Verify indexes are being used (check query plans)
3. Monitor API usage in Dashboard > Settings > API
4. Check real-time connections in Dashboard > Database > Realtime

## 🎯 Troubleshooting

### Issue: "Invalid API key"
**Solution**: Verify you copied the correct anon key from Supabase Dashboard > Settings > API

### Issue: RLS policy blocks my query
**Solution**: Check RLS policies in `supabase_rls_policies.sql`. Use Supabase Dashboard > Authentication > Policies to debug.

### Issue: PostGIS function not found
**Solution**: Enable PostGIS extension: `CREATE EXTENSION IF NOT EXISTS postgis;`

### Issue: Real-time not working
**Solution**: Enable Realtime in Supabase Dashboard > Database > Replication. Add tables to publication.

### Issue: Build errors after adding Supabase SDK
**Solution**: 
- Clean build folder (Cmd+Shift+K)
- Reset package cache (File > Packages > Reset Package Caches)
- Check minimum iOS deployment target is 15.0+

## 🚀 Go Live Checklist

Before deploying to production:

- [ ] All SQL scripts run successfully
- [ ] RLS policies tested and verified
- [ ] Storage buckets created with correct policies
- [ ] Environment variables/config secured (not in git)
- [ ] Authentication flows tested
- [ ] Real-time subscriptions working
- [ ] Image uploads working
- [ ] Database indexes created (check supabase_schema.sql)
- [ ] Performance tested with production-like data
- [ ] Error handling and logging in place
- [ ] Backup strategy defined
- [ ] Rollback plan prepared

## 📚 Additional Resources

- [Supabase Swift Docs](https://supabase.com/docs/reference/swift)
- [PostGIS Documentation](https://postgis.net/docs/)
- [Row-Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [Storage Guide](https://supabase.com/docs/guides/storage)

## 🆘 Need Help?

If you encounter issues during migration:

1. Check the Supabase Dashboard logs
2. Review the SQL logs in Dashboard > SQL Editor
3. Check the Auth logs in Dashboard > Authentication > Users
4. Use the Supabase Discord community
5. Review the files created in this migration for examples

---

**Migration created on**: October 12, 2025
**Branch**: feature/migrate-to-supabase

Good luck with your migration! 🚀


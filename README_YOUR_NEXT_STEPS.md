# Your Supabase Migration - Next Steps

## ✅ What You Already Have

- ✅ Supabase database with schema (838 places, 29 users, etc.)
- ✅ PostGIS enabled
- ✅ All tables created with proper indexes
- ✅ Swift service files created (ready to use)

## 🚀 What You Need To Do Now (In Order)

### Step 1: Add Row-Level Security (CRITICAL - 2 minutes)

Without this, **anyone can access any user's data**!

1. Go to https://app.supabase.com → Your Project → SQL Editor
2. Copy and run: `supabase_rls_policies_ACTUAL.sql`
3. Verify: Dashboard → Authentication → Policies (should see policies for each table)

### Step 2: Add Helper Functions (Optional but Recommended - 1 minute)

These make your queries much easier and add automatic notifications.

1. In SQL Editor, run: `supabase_helper_functions_ACTUAL.sql`
2. This adds:
   - `get_map_places_in_viewport()` - Fast map loading
   - `get_nearby_places()` - Radius search
   - `search_places()` - Text search with location
   - `get_user_feed()` - Activity feed
   - `get_trending_places()` - Trending algorithm
   - Automatic notification triggers

### Step 3: Install Supabase SDK (5 minutes)

1. Open `loc.xcodeproj` in Xcode
2. File → Add Package Dependencies
3. Enter: `https://github.com/supabase/supabase-swift.git`
4. Select version: "2.0.0" or later
5. Add these products to your `loc` target:
   - Supabase
   - Auth
   - PostgREST
   - Realtime
   - Storage
6. Click "Add Package"

### Step 4: Add Your Credentials (30 seconds)

1. Supabase Dashboard → Settings → API
2. Copy:
   - Project URL
   - anon/public key
3. Edit `loc/Services/SupabaseConfig.swift`:

```swift
static let supabaseURL = URL(string: "https://YOUR-PROJECT.supabase.co")!
static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Step 5: Create Storage Buckets (1 minute)

Dashboard → Storage → New Bucket:

| Bucket Name | Public | Policy |
|-------------|--------|--------|
| `profile_photos` | No (private) | Users can only access their own folder |
| `review_photos` | Yes (public) | Anyone can read, authenticated can upload |
| `comment_photos` | Yes (public) | Anyone can read, authenticated can upload |
| `list_covers` | Yes (public) | Anyone can read, authenticated can upload |

Apply the storage policies from `supabase_rls_policies_ACTUAL.sql` (at the bottom of that file).

### Step 6: Update Your Code (15-30 minutes)

Follow the detailed guide in `SUPABASE_MIGRATION_GUIDE.md`, but here's the quick version:

#### A. Update ServiceContainer.swift

```swift
// Change from Firebase services to Supabase services
class ServiceContainer {
    let userService: SupabaseUserService = SupabaseUserService.shared
    let placeService: SupabasePlaceService = SupabasePlaceService.shared
    let reviewService: SupabaseReviewService = SupabaseReviewService.shared
    let authService: SupabaseAuthService = SupabaseAuthService.shared
    let realtimeService: SupabaseRealtimeService = SupabaseRealtimeService.shared
    
    // Keep other services as-is
    let locationManager: LocationManager
    let imageService: ImageService
    // ...
}
```

#### B. Update locApp.swift

```swift
import Supabase  // Add this

@main
struct locApp: App {
    init() {
        // REMOVE: FirebaseApp.configure()
        // Supabase auto-initializes via SupabaseManager.shared
        
        // Rest stays the same...
    }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .task {
                    // Change from Auth.auth().currentUser
                    if let session = try? await SupabaseAuthService.shared.getSession() {
                        let userId = session.user.id.uuidString
                        userSession.setUserLoggedIn(uid: userId)
                        await dataManager.initializeProfileData(userId: userId)
                    }
                }
        }
    }
}
```

#### C. Update UserSession.swift

```swift
class UserSession: ObservableObject {
    private let authService = SupabaseAuthService.shared
    
    func checkSession() async {
        if let session = try? await authService.getSession() {
            self.isLoggedIn = true
            self.userUID = session.user.id.uuidString
        }
    }
    
    func signOut() async throws {
        try await authService.signOut()
        self.isLoggedIn = false
        self.userUID = nil
    }
}
```

#### D. Update Auth Views (Sign In/Sign Up)

```swift
// In your sign-in view
func signIn() async {
    do {
        let session = try await SupabaseAuthService.shared.signIn(
            email: email,
            password: password
        )
        // Success! User is signed in
        userSession.setUserLoggedIn(uid: session.user.id.uuidString)
    } catch {
        // Handle error
    }
}
```

### Step 7: Build & Test (5 minutes)

1. Build: Cmd+B
2. Fix any import/compile errors
3. Run the app
4. Test these operations:
   - Sign in
   - Load map (should be faster!)
   - View favorites
   - Create a review
   - Search places

## 🎯 Quick Test Script

Once built, test in this order:

```swift
// 1. Test auth
let session = try await SupabaseAuthService.shared.signIn(
    email: "test@example.com",
    password: "password"
)
print("✅ Auth works: \(session.user.id)")

// 2. Test database
let places = try await SupabasePlaceService.shared.fetchAllPlaces()
print("✅ Database works: \(places.count) places")

// 3. Test PostGIS
let nearby = try await SupabasePlaceService.shared.getNearbyPlaces(
    lat: 37.7749, lng: -122.4194, radiusMeters: 5000
)
print("✅ PostGIS works: \(nearby.count) nearby")

// 4. Test viewport loading
let bounds = getMapBounds()
let viewportPlaces = try await supabase.database
    .rpc("get_map_places_in_viewport", params: [
        "p_user_id": userId,
        "p_north_lat": bounds.north,
        "p_south_lat": bounds.south,
        "p_east_lng": bounds.east,
        "p_west_lng": bounds.west
    ])
    .execute()
print("✅ Viewport loading works: \(viewportPlaces.count) in view")
```

## 🔒 Security Checklist

Before going live, verify:

- [ ] RLS policies are enabled on ALL tables
- [ ] Try to access another user's data (should fail)
- [ ] Storage buckets have correct policies
- [ ] anon key (not service_role key) is used in app
- [ ] No sensitive data in git (check SupabaseConfig.swift is in .gitignore)

## 📊 Expected Performance

| Operation | Before (Firebase) | After (Supabase) |
|-----------|-------------------|------------------|
| Map load (all places) | 2-5 seconds | N/A (use viewport) |
| Map viewport load | N/A | < 500ms |
| Nearby search | Client filter | < 100ms (PostGIS) |
| Text search | Client filter | < 200ms (Database) |

## 🆘 Troubleshooting

### "Invalid API key"
→ Check `SupabaseConfig.swift` - make sure you pasted the anon key, not service_role

### "Relation does not exist"
→ You're already set! Just run the RLS and helper SQL files

### "RLS policy blocks query"
→ Make sure user is authenticated before queries

### Build errors after adding SDK
→ Clean build (Cmd+Shift+K), reset packages, rebuild

### "No such function: get_map_places_in_viewport"
→ Run `supabase_helper_functions_ACTUAL.sql` in SQL Editor

## 📚 Files to Reference

| File | Purpose | Status |
|------|---------|--------|
| `supabase_rls_policies_ACTUAL.sql` | Security policies | **RUN THIS** |
| `supabase_helper_functions_ACTUAL.sql` | Helper functions | **RUN THIS** |
| `SUPABASE_QUICK_START.md` | Quick reference | Read |
| `SUPABASE_MIGRATION_GUIDE.md` | Detailed guide | Read for details |

## ✅ Your Migration Checklist

- [ ] Step 1: Run RLS policies SQL
- [ ] Step 2: Run helper functions SQL
- [ ] Step 3: Install Supabase SDK in Xcode
- [ ] Step 4: Add credentials to SupabaseConfig.swift
- [ ] Step 5: Create storage buckets
- [ ] Step 6: Update ServiceContainer, locApp, UserSession
- [ ] Step 7: Update auth views
- [ ] Step 8: Build & test
- [ ] Step 9: Test RLS security
- [ ] Step 10: Deploy!

## 🎉 You're Almost Done!

Your database is already set up, so you're 50% there. The remaining work is:
1. Adding security (critical!)
2. Installing the SDK
3. Updating your Swift code to use Supabase services

The Supabase services I created have the **exact same method signatures** as your Firebase services, so most code will work with just type changes!

Good luck! 🚀

---

**Questions?** Check `SUPABASE_MIGRATION_GUIDE.md` for more details.


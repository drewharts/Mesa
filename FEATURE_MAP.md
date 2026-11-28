# Mesa feature map

What users can do in the app, derived from the code as of 2026-11-26 (branch `feature/agent-docs`, based on `feature/tab-nav-redesign`: the map is the base layer, Explore and Trips are bottom sheets over it, Profile is a full page, the profile picture is the tab icon). Each feature lists how to reach it, the files that implement it, accessibility identifiers, backend endpoints/tables, and caveats.

## How to use this map

Turn a vague bug report into concrete UI, then into files and IDs:

1. **Find the feature.** Scan the [index](#index) for words from the report ("map", "trip", "import", "find a table"). Use the **How to reach it** path to reproduce by hand or in a UI test.
2. **Open the files.** **Main views/files** and **ViewModels/services** are where to look first; **Known caveats** lists traps (gated states, hard-coded values, stubs).
3. **Drive it.** **Accessibility identifiers** are the stable handles for XCUITest (`app.buttons["tab.trips"]`). See [docs/skills/verify-mesa.md](docs/skills/verify-mesa.md).
4. **Check the backend.** **Backend / Supabase** names the Mesa-backend route (`METHOD /path`, repo `/workspace/Mesa-backend`) or Supabase table/RPC.
5. **Update this file** whenever you add or change UI, and add accessibility IDs per the scheme below.

Worked example: *"the map didn't reset after leaving a trip"* -> Trips list / Trip detail / Trip map and overlays below -> `loc/Views/Trips/TripMapExitModifier.swift`, `loc/ViewModels/Trips/TripsListViewModel.swift`, `loc/Views/Containers/MapContainerView.swift` -> IDs `tab.trips`, `trips.row`, `trip.close`, `tab.map` -> reproduce: Tab bar -> Trips -> open a trip -> leave it (back / close / switch tab) -> Map tab.

## Accessibility identifier naming scheme

`area.element[.qualifier]`: lowercase-first camelCase segments separated by dots.

- `area` is the screen or feature (`tab`, `map`, `search`, `place.detail`, `list`, `explore`, `trips`/`trip`, `profile`, `import`, `onboarding`, `auth`, `settings`).
- `element` is what it is (`save`, `field`, `recenter`, `findTable`); `qualifier` narrows it (`import.googleMaps.url`, `list.menu.delete`).
- **IDs are static strings.** Never interpolate ids, names or indices (`list.row.<id>` is NOT allowed). For repeated cells use one shared ID (`list.row`, `trips.row`, `explore.list`) and select by label or index (`app.buttons.matching(identifier: "trips.row").element(boundBy: 0)`).
- Put the ID on the tappable control (Button, Menu, NavigationLink, TextField), not on a container.
- Only one element on screen per ID where possible. Known exceptions are listed in [Gaps](#gaps-and-known-limits).
- Pre-existing legacy IDs outside the scheme: `foodSlider`, `serviceSlider`, `ambienceSlider` (`loc/Views/PlaceReviews/RatingSlidersView.swift`).
- New IDs also go into the `A11yID` constants used by `locUITests/` (added by the CI checks work) and into the table at the end of this file.

## Index

- [Naming scheme](#accessibility-identifier-naming-scheme)
- [App launch and splash](#app-launch-and-splash)
- [App update gate](#app-update-gate)
- [Login (Sign in with Apple / Google)](#login-sign-in-with-apple--google)
- [Phone number onboarding](#phone-number-onboarding)
- [Profile photo onboarding](#profile-photo-onboarding)
- [List onboarding (Google Maps import)](#list-onboarding-google-maps-import)
- [Suggested profiles popup and contacts match](#suggested-profiles-popup-and-contacts-match)
- [Account menu (gear)](#account-menu-gear)
- [Sign out](#sign-out)
- [Delete account](#delete-account)
- [Edit profile](#edit-profile)
- [Send feedback](#send-feedback)
- [Push notifications](#push-notifications)
- [Deep links](#deep-links)
- [Bottom tab bar](#bottom-tab-bar)
- [Map (base layer)](#map-base-layer)
- [Map controls: search pill, Fresh finds, layers, recenter](#map-controls-search-pill-fresh-finds-layers-recenter)
- [Places here (visible places popup)](#places-here-visible-places-popup)
- [Map sheets (PresentationService / AppSheetType)](#map-sheets-presentationservice--appsheettype)
- [Nearby discovery (tap-to-discover)](#nearby-discovery-tap-to-discover)
- [Drop a pin / create place](#drop-a-pin--create-place)
- [Search](#search)
- [Recent searches](#recent-searches)
- [Keyword results popup](#keyword-results-popup)
- [Place detail](#place-detail)
- [Save to list (from place detail)](#save-to-list-from-place-detail)
- [Create post / review](#create-post--review)
- [Tonight](#tonight)
- [Fresh finds](#fresh-finds)
- [Feed / Explore feed sheet](#feed--explore-feed-sheet)
- [Suggested profiles popup](#suggested-profiles-popup)
- [Explore tab home](#explore-tab-home)
- [Featured list card (with Find a table)](#featured-list-card-with-find-a-table)
- [Browse by city / city lists](#browse-by-city--city-lists)
- [Explore list detail](#explore-list-detail)
- [City detail sheet (map)](#city-detail-sheet-map)
- [Create list](#create-list)
- [List detail popup (own lists) and overflow menu](#list-detail-popup-own-lists-and-overflow-menu)
- [Rename / edit list](#rename--edit-list)
- [List settings (privacy and pricing)](#list-settings-privacy-and-pricing)
- [Collaborators](#collaborators)
- [Share list (link and story card)](#share-list-link-and-story-card)
- [Find a table (Resy availability)](#find-a-table-resy-availability)
- [Place reservation link](#place-reservation-link)
- [Save to list (save-to sheet) and Saved banner](#save-to-list-save-to-sheet-and-saved-banner)
- [Saved library (on-device grouping)](#saved-library-on-device-grouping)
- [Paid lists, purchase, creator earnings](#paid-lists-purchase-creator-earnings)
- [List reorder](#list-reorder)
- [Trips list](#trips-list)
- [Create trip wizard](#create-trip-wizard)
- [Trip detail and itinerary](#trip-detail-and-itinerary)
- [Trip map and overlays](#trip-map-and-overlays)
- [Trip collaborators and invites](#trip-collaborators-and-invites)
- [Add place to trip (from place detail)](#add-place-to-trip-from-place-detail)
- [Profile page (own)](#profile-page-own)
- [Profile photo import card](#profile-photo-import-card)
- [Profile lists section and "+" menu](#profile-lists-section-and--menu)
- [Followers / following lists](#followers--following-lists)
- [Other users' profiles and follow/unfollow](#other-users-profiles-and-followunfollow)
- [Recommended users](#recommended-users)
- [Google Maps list import](#google-maps-list-import)
- [Import help sheet](#import-help-sheet)
- [Photo import ("Import Photos to Discover Places")](#photo-import-import-photos-to-discover-places)
- [Video/URL import (TikTok / Instagram) progress sheet](#videourl-import-tiktok--instagram-progress-sheet)
- [Share extension (MesaShare)](#share-extension-mesashare)
- [Recently imported (map imports sheet)](#recently-imported-map-imports-sheet)
- [External videos on place detail](#external-videos-on-place-detail)
- [Photo feed](#photo-feed)
- [Contacts matching (onboarding)](#contacts-matching-onboarding)
- [Voice review (dictation)](#voice-review-dictation)
- [Instagram Stories sharing (outbound, not import)](#instagram-stories-sharing-outbound-not-import)
- [All accessibility identifiers (table)](#accessibility-identifiers-table)
- [Backend endpoint inventory](#backend-endpoint-inventory)
- [Gaps and known limits](#gaps-and-known-limits)


## Features

### App launch and splash
- **Purpose:** Boot services, restore the Supabase session, show an animated MESA splash, then mount the app.
- **How to reach it:** Cold launch.
- **Main views/files:** loc/locApp.swift, loc/Views/SplashScreenView.swift, loc/Views/AnimatedSplashView.swift, loc/Views/ContentView.swift
- **ViewModels/services:** loc/ViewModels/SplashScreenViewModel.swift, loc/Models/UserSession.swift, loc/Services/OnboardingStatusService.swift
- **Accessibility identifiers:** none added
- **Backend / Supabase:** Supabase auth session restore; users/place_lists reads for onboarding status
- **Known caveats:** Splash stays up until both the intro animation and session check finish (reduce-motion skips animation). ContentView layers LoginView, Phone, Photo and List onboarding over an always-mounted MainTabView. App forces light color scheme.

### App update gate
- **Purpose:** Blocking "Update Mesa" screen when installed version < server min version.
- **How to reach it:** Automatic on launch/foreground when backend min_ios_version exceeds the installed version.
- **Main views/files:** loc/Services/AppUpdateGate.swift (contains UpdateRequiredView), overlay in loc/locApp.swift
- **ViewModels/services:** AppUpdateGate.shared
- **Accessibility identifiers:** `update.open` (loc/Services/AppUpdateGate.swift:92)
- **Backend / Supabase:** `GET /app/config` (routes/admin.py; returns min_ios_version from env MIN_IOS_VERSION, '0' = no gate)
- **Known caveats:** Fails open on any error; checks throttled to once per 60s. Hard to reach in UI tests (needs backend config). Update button opens App Store URL. UpdateRequiredView shares a file with the gate class.

### Login (Sign in with Apple / Google)
- **Purpose:** Authenticate the user and create/migrate their profile.
- **How to reach it:** Launch while logged out; LoginView overlays ContentView with a bottom sheet "Get Started".
- **Main views/files:** loc/Views/LoginView.swift, loc/Views/LoginViewPreview.swift
- **ViewModels/services:** loc/ViewModels/LoginViewModel.swift, loc/Services/SupabaseAuthService.swift, loc/Models/UserSession.swift
- **Accessibility identifiers:** `auth.signInApple` (loc/Views/LoginView.swift:119); `auth.signInGoogle` (loc/Views/LoginView.swift:145)
- **Backend / Supabase:** Supabase auth signInWithIdToken (Apple, Google); tables users (find by email/migrate, create), plus favorites, following, place_lists, reviews, comments, my_places, external_places, place_notes, tik_tok_place_flags, user_notifications, review_likes (ID re-keying when migrating legacy accounts)
- **Known caveats:** There is NO email/password UI in LoginView, so pre-assigned auth.signIn, auth.email and auth.password do not exist (SupabaseAuthService has signUp/signIn methods but no view uses them). Apple/Google need real credentials and system sheets, so they cannot be automated in simulator UI tests without a test hook. Google uses GIDSignIn; url handling in AppDelegate.

### Phone number onboarding
- **Purpose:** Collect the user's phone number so contacts matching works.
- **How to reach it:** After first sign-in when users record has no phone.
- **Main views/files:** loc/Views/Onboarding/PhoneOnboardingView.swift
- **ViewModels/services:** loc/ViewModels/Onboarding/PhoneOnboardingViewModel.swift, UserSession.completePhoneOnboarding
- **Accessibility identifiers:** `onboarding.phone` (loc/Views/Onboarding/PhoneOnboardingView.swift:166); `onboarding.continue` (loc/Views/Onboarding/PhoneOnboardingView.swift:198)
- **Backend / Supabase:** Supabase `users` table update
- **Known caveats:** Continue disabled until number valid. Country code picker is a Menu (no ID added).

### Profile photo onboarding
- **Purpose:** Let new user pick a profile photo.
- **How to reach it:** After phone step if no photo.
- **Main views/files:** loc/Views/Onboarding/ProfilePhotoOnboardingView.swift
- **ViewModels/services:** loc/ViewModels/Onboarding/ProfilePhotoOnboardingViewModel.swift
- **Accessibility identifiers:** `onboarding.photo.choose` (loc/Views/Onboarding/ProfilePhotoOnboardingView.swift:183); `onboarding.continue` (loc/Views/Onboarding/ProfilePhotoOnboardingView.swift:207)
- **Backend / Supabase:** image upload via ImageService plus `users` table update
- **Known caveats:** Uses system photo picker. Continue disabled until a photo is selected (canContinue).

### List onboarding (Google Maps import)
- **Purpose:** Prompt new user to import lists; skippable.
- **How to reach it:** After photo step if user has no place_lists.
- **Main views/files:** loc/Views/Onboarding/ListOnboardingView.swift (wraps loc/Views/MyProfileViews/GoogleMapsImportView.swift)
- **ViewModels/services:** UserSession.completeListOnboarding, OnboardingStatusService
- **Accessibility identifiers:** none added
- **Backend / Supabase:** `place_lists` read (status); import endpoints belong to the import area
- **Known caveats:** Skip button is the import view's cancel button (import.cancel, owned by the import area). On completion ContentView auto-follows 3 curated accounts and may present Suggested Profiles.

### Suggested profiles popup and contacts match
- **Purpose:** Suggest accounts to follow; optionally match phone contacts.
- **How to reach it:** Presented automatically once after list onboarding (PresentationService .suggestedProfiles).
- **Main views/files:** loc/Views/Onboarding/SuggestedProfilesPopupView.swift, SuggestedProfileRowView.swift, ContactsMatchSection.swift, ContactsConsentCard.swift
- **ViewModels/services:** loc/ViewModels/Onboarding/SuggestedProfilesViewModel.swift, loc/Services/ContactsService.swift, SupabaseUserService.autoFollowCuratedAccounts / followUser
- **Accessibility identifiers:** `onboarding.suggested.done` (loc/Views/Onboarding/SuggestedProfilesPopupView.swift:37) `onboarding.contacts.allow` (loc/Views/Onboarding/ContactsConsentCard.swift:38); `onboarding.contacts.decline` (loc/Views/Onboarding/ContactsConsentCard.swift:43)
- **Backend / Supabase:** RPC `match_contacts_by_phone`; `following` table
- **Known caveats:** Shown once (shouldShowPopup flag). Contacts consent card precedes system contacts permission; denied state shows Open Settings button. Follow buttons in rows not given IDs (row is a Button wrapping a Button).

### Account menu (gear)
- **Purpose:** Share profile, edit profile, send feedback, log out, delete account.
- **How to reach it:** Tab bar -> Profile -> gear icon (toolbar).
- **Main views/files:** loc/Views/MyProfileViews/AccountMenuView.swift, ProfileView.swift (AccountManagementModifier holds the delete alerts)
- **ViewModels/services:** ProfileViewModel (logout, accountViewModel), loc/ViewModels/ProfileAccountViewModel.swift, PlaceShareService
- **Accessibility identifiers:** `settings.menu` (loc/Views/MyProfileViews/AccountMenuView.swift:103); `settings.editProfile` (loc/Views/MyProfileViews/AccountMenuView.swift:65); `settings.feedback` (loc/Views/MyProfileViews/AccountMenuView.swift:75); `settings.signOut` (loc/Views/MyProfileViews/AccountMenuView.swift:85)
- **Backend / Supabase:** Supabase auth signOut
- **Known caveats:** Share Profile item has no ID (conditional on user loaded).

### Sign out
- **Purpose:** Log out and clear cached session data.
- **How to reach it:** Profile -> gear -> Log Out (no confirmation).
- **Main views/files:** AccountMenuView.swift
- **ViewModels/services:** ProfileViewModel.logout -> UserSession.logout -> SupabaseAuthService.signOut, GIDSignIn.signOut, SessionCleanupService
- **Accessibility identifiers:** `settings.menu` (loc/Views/MyProfileViews/AccountMenuView.swift:103); `settings.editProfile` (loc/Views/MyProfileViews/AccountMenuView.swift:65); `settings.feedback` (loc/Views/MyProfileViews/AccountMenuView.swift:75); `settings.signOut` (loc/Views/MyProfileViews/AccountMenuView.swift:85) (settings.signOut)
- **Backend / Supabase:** Supabase auth signOut
- **Known caveats:** Immediate, no confirm dialog; returns to LoginView.

### Delete account
- **Purpose:** Two-step delete flow.
- **How to reach it:** Profile -> gear -> Delete Account -> alert "Delete Account?" (Continue) -> alert "Final Warning" (Delete Forever).
- **Main views/files:** AccountMenuView.swift, loc/Views/MyProfileViews/ProfileView.swift (AccountManagementModifier, ~line 518)
- **ViewModels/services:** loc/ViewModels/ProfileAccountViewModel.swift, UserService.deleteUserAccount, SupabaseAuthService.deleteAccount
- **Accessibility identifiers:** `settings.deleteAccount` (loc/Views/MyProfileViews/AccountMenuView.swift:95)
- **Backend / Supabase:** none effectively
- **Known caveats:** IMPORTANT: UserService.deleteUserAccount is a stub that only logs "not fully implemented" and calls completion(nil); SupabaseAuthService.deleteAccount only signs out (comment relies on cascade deletes that are not implemented). So deleting an account currently does NOT delete server data (App Store 5.1.1(v) risk). Alert buttons not given IDs (system alerts; target by label "Continue"/"Delete Forever").

### Edit profile
- **Purpose:** Edit name, social handles, profile photo.
- **How to reach it:** Profile -> gear -> Edit Profile.
- **Main views/files:** loc/Views/MyProfileViews/EditProfileView.swift
- **ViewModels/services:** loc/ViewModels/EditProfileViewModel.swift
- **Accessibility identifiers:** `editProfile.firstName` (loc/Views/MyProfileViews/EditProfileView.swift:130); `editProfile.save` (loc/Views/MyProfileViews/EditProfileView.swift:185)
- **Backend / Supabase:** `users` table update
- **Known caveats:** Save disabled until hasChanges; photo editing via action sheet (Adjust Crop / Choose New Photo).

### Send feedback
- **Purpose:** Send feedback to the creator.
- **How to reach it:** Profile -> gear -> Send Feedback.
- **Main views/files:** loc/Views/MyProfileViews/FeedbackSheet.swift
- **ViewModels/services:** none (insert is done inside the View, an MVVM violation)
- **Accessibility identifiers:** `feedback.text` (loc/Views/MyProfileViews/FeedbackSheet.swift:71); `feedback.send` (loc/Views/MyProfileViews/FeedbackSheet.swift:95)
- **Backend / Supabase:** Supabase insert into `user_feedback` (user_id, message, app_version)
- **Known caveats:** Errors are only printed; success shows "Thank You!" alert.

### Push notifications
- **Purpose:** Register for APNs, store token, route tapped pushes.
- **How to reach it:** System permission prompt appears on 3rd launch (fallback) or at first video import; taps handled by AppDelegate.
- **Main views/files:** loc/locApp.swift (AppDelegate + UNUserNotificationCenterDelegate), loc/ContentView.swift handling
- **ViewModels/services:** loc/Services/NotificationPermissionService.swift, loc/Services/PushNotificationService.swift, loc/Managers/NotificationManager.swift, ImportTracker
- **Accessibility identifiers:** none added
- **Backend / Supabase:** Supabase `users` update (FCM/device token via UserService.updateFCMToken)
- **Known caveats:** No in-app notifications list screen exists in the code (no NotificationsView found; only the user_notifications table is touched by the account migration). Push types handled: import_complete, group_pick_*, follow, place_added_to_list, trip_*, review/comment, generic deepLink. Cannot test in simulator UI tests. Comment in AppDelegate says "FCM removed" but token is stored via updateFCMToken.

### Deep links
- **Purpose:** Open places, lists, profiles, invites, group picks, shared content from URLs.
- **How to reach it:** `xcrun simctl openurl booted "loc://..."` or universal links on MesaBackendConfig.universalLinkHost.
- **Main views/files:** loc/locApp.swift (onOpenURL, universal link conversion, AppDelegate.open)
- **ViewModels/services:** loc/Services/DeepLinkManager.swift, loc/ViewModels/DeepLinkViewModel.swift
- **Accessibility identifiers:** none (no UI)
- **Backend / Supabase:** trip invitation redeem (TripInvitationService); place lookups via placeService
- **Known caveats:** Hosts: place, list, profile, invite, pick, share (/content, /tiktok, /list), tiktok-shared. Universal paths: /place /pick /list /profile /invite. Invite and pick tokens are stashed in UserDefaults when logged out. Requires logged-in user for profile/list.

#### Area notes: Gaps
- No email/password sign-in UI exists; auth.signIn/auth.email/auth.password not added.
- Exact contents of LoginViewModel Apple flow and DeepLinkViewModel not read in depth.
- Backend endpoints for push token not found (it goes through Supabase, not Mesa-backend).

#### Area notes: Unsure/skipped
- Alert buttons (delete account steps), country-code Menu, Share Profile item, row-level follow buttons in suggested profiles: no IDs added.


### Bottom tab bar
- **Purpose:** App-drawn tab bar (Map, Explore, Trips, Profile) over an always-present map; Explore/Trips open as bottom sheets over the map, Profile as a full page.
- **How to reach it:** Always visible after sign-in (safeAreaInset on MainTabView).
- **Main views/files:** loc/Views/SharedComponents/AppTabBar.swift, loc/Views/MainTabView.swift, loc/Views/SharedComponents/TabSheetContainer.swift
- **ViewModels/services:** loc/Services/AppTabRouter.swift (selected tab, visitedTabs, returnTab, handOffToMap/restoreReturnTab), loc/ViewModels/MainTabViewModel.swift, loc/ViewModels/TabSheetViewModel.swift, loc/ViewModels/ProfileTabIconViewModel.swift (profile-photo tab icon, ring when selected; falls back to person.crop.circle until photo cached)
- **Accessibility identifiers:** `tab.map` (loc/Views/SharedComponents/AppTabBar.swift:38)
- **Backend / Supabase:** none directly (profile photo via ProfilePhotoCache)
- **Known caveats:** Tab IDs are built by interpolation (`tab.\(title.lowercased())`) giving tab.map, tab.explore, tab.trips, tab.profile. Selecting Map hides any tab sheet. Tab sheet content is created on first visit and kept alive. Explore sheet can be dragged between medium/large detents or dismissed (returns to Map). Profile tab layer only exists after first visit. Map sheets requested while another tab is selected switch to Map first (400 ms delay in PresentationService.presentOnMapTab).

### Map (base layer)
- **Purpose:** Google Maps (GMSMapView) showing the user's, friends' and community places as pins with clustering; tap pins to open place detail.
- **How to reach it:** Tab bar -> Map (default tab at launch).
- **Main views/files:** loc/Views/MainView.swift, loc/Views/Containers/MapContainerView.swift, loc/Views/MapView.swift, loc/Views/GoogleMapView.swift, loc/Views/Map/ (MapTopBar, MapSearchBar, MapBottomControls, MapMarkerImageFactory, EmojiCircleMarkerContent, ClusterBadgeView, OverlapClusterAlgorithm, CityAnnotationMarkerView, SelectedPinView, MapCameraSettleGate, MapIdDiff), loc/Views/CommunityMarkerView.swift, loc/Views/SharedComponents/MapCircleButton.swift
- **ViewModels/services:** loc/ViewModels/MapViewModel.swift (parent) with children in loc/ViewModels/Map/ (MapViewportViewModel, MapFilteringViewModel, MapAnnotationSelectionViewModel, MapCityAnnotationViewModel, MapPhotoViewModel, MapExternalUserViewModel, MapTapDiscoveryViewModel, ImportsMapFraming); loc/ViewModels/MapDisplayCoordinatorViewModel.swift; loc/Services/SupabasePlaceService.swift; loc/Services/MesaBackendService.swift
- **Accessibility identifiers:** `map.recenter` (loc/Views/Map/MapBottomControls.swift:28); `map.layers` (loc/Views/Map/MapBottomControls.swift:50); `map.freshFinds` (loc/Views/Map/MapTopBar.swift:25); `map.searchBar` (loc/Views/Map/MapSearchBar.swift:35); `map.placesHere` (loc/Views/MapView.swift:405)
- **Backend / Supabase:** `GET /search/place-details` (MapViewportViewModel -> fetchPlaceDetails when a pin lacks details). Supabase RPCs: get_visible_annotations_with_users, get_all_friends_places_in_viewport, get_all_community_places_in_viewport, get_community_places_in_viewport, get_list_annotations_with_users, get_review_annotations_with_users, get_tiktok_annotations_with_users, get_favorite_annotations_with_users, get_my_places_annotations_with_users, get_keyword_annotations_with_users, get_followed_users_photos, search_cities.
- **Known caveats:** Floating controls (search pill, sparkles, layers, recenter) only render while no map sheet is active and no create-place popup is up. Pins are Google Maps markers, so individual pins are not accessible elements in XCUITest; use the identifiers on the overlay buttons. Map camera driven by `mapPosition` (MapCameraPosition) translated to GMSCameraPosition. Needs location permission (LocationManager.requestLocationPermission on appear).

### Map controls: search pill, Fresh finds, layers, recenter
- **Purpose:** Floating buttons on the map: open search, open Fresh finds, choose what annotations show (Everyone / Categories / My Places) plus Satellite toggle, recenter on user location.
- **How to reach it:** Tab bar -> Map (visible when no map sheet is open).
- **Main views/files:** loc/Views/Map/MapTopBar.swift, loc/Views/Map/MapSearchBar.swift, loc/Views/Map/MapBottomControls.swift, loc/Models/AnnotationDisplayMode.swift
- **ViewModels/services:** state is local @State in MainView (recenterMap, annotationDisplayMode, isSatelliteMap); filtering in loc/ViewModels/Map/MapFilteringViewModel.swift
- **Accessibility identifiers:** none added
- **Backend / Supabase:** none directly
- **Known caveats:** Recenter button has accessibilityLabel "Show my location". Layers is a Menu with a Picker plus a Toggle; menu items only appear once opened.

### Places here (visible places popup)
- **Purpose:** Grid of places currently in the map viewport with Friends/Community toggle.
- **How to reach it:** Tab bar -> Map -> "Places here" pill (top-left under the search bar).
- **Main views/files:** loc/Views/MapView.swift (button, sheet), loc/Views/MapView/VisiblePlacesPopupView.swift, FriendsPlaceGridCell.swift, CommunityPlaceGridCell.swift
- **ViewModels/services:** loc/ViewModels/VisiblePlacesPopupViewModel.swift, SupabasePlaceService, ImageCacheService
- **Accessibility identifiers:** `map.recenter` (loc/Views/Map/MapBottomControls.swift:28); `map.layers` (loc/Views/Map/MapBottomControls.swift:50); `map.freshFinds` (loc/Views/Map/MapTopBar.swift:25); `map.searchBar` (loc/Views/Map/MapSearchBar.swift:35); `map.placesHere` (loc/Views/MapView.swift:405) (map.placesHere)
- **Backend / Supabase:** RPCs get_all_friends_places_in_viewport, get_all_community_places_in_viewport
- **Known caveats:** Presented as a plain `.sheet` from MapView, not via PresentationService.

### Map sheets (PresentationService / AppSheetType)
- **Purpose:** Single sheet slot over the map; MainView.sheet(item: activeSheet) switches over AppSheetType: placeDetail, externalPlaceSelection, noPlacesFound, importPlaceConfirmation, importProgress, importJob, list, externalVideos, reviews, favorites, myPlaces, externalReviews, externalList, externalFavorites, keywordResults, nearbyDiscovery, cityOverview, feed, tripsList (redirected to Trips tab), tonight, freshFinds, groupPick, suggestedProfiles.
- **How to reach it:** Opened from pins, list/profile "show on map", deep links, notifications, share extension, Fresh finds button, etc.
- **Main views/files:** loc/Views/MainView.swift (sheetContent builder), loc/Models/AppSheetType.swift, loc/Views/Containers/ListPopupContainerView.swift
- **ViewModels/services:** loc/Services/PresentationService.swift (present, transition(to:), presentImmediately, dismiss, preserveAndDismiss/restorePreservedSheet), loc/Services/AppTabRouter.swift
- **Accessibility identifiers:** none on the container
- **Backend / Supabase:** per sheet
- **Known caveats:** Only one sheet at a time; presenting while a non-Map tab is selected first switches to Map. Place detail uses custom detents (min height and 800) with background interaction enabled so the map stays tappable.

### Nearby discovery (tap-to-discover)
- **Purpose:** Tapping empty map space lists nearby Apple Maps places; picking a row opens place detail.
- **How to reach it:** Tab bar -> Map -> tap an empty map location (tap-discovery overlay).
- **Main views/files:** loc/Views/Map/NearbyDiscoverySheet.swift, loc/Views/Map/NearbyPlaceCard.swift, loc/Views/Containers/MapContainerView.swift
- **ViewModels/services:** loc/ViewModels/Map/MapTapDiscoveryViewModel.swift (MKLocalSearch), loc/ViewModels/Map/NearbyDiscoverySheetViewModel.swift (singleton)
- **Accessibility identifiers:** none
- **Backend / Supabase:** MKLocalSearch (Apple). loc/Services/NearbyPlacesService.swift calls `GET /nearby-places` (Mesa-backend routes/nearby.py); not confirmed to be wired to this sheet.
- **Known caveats:** Hard to drive in UI tests (map tap at coordinates).

### Drop a pin / create place
- **Purpose:** Long-press the map to drop a pin and create a custom place.
- **How to reach it:** Tab bar -> Map -> long-press on the map; or Search -> pick a coordinate result.
- **Main views/files:** loc/Views/GoogleMapView.swift (didLongPressAt), loc/Views/MapView.swift, loc/Views/CreatePlacePopupView.swift, loc/Views/PlaceDetailViews/CustomPlaceCreatorView.swift
- **ViewModels/services:** loc/ViewModels/SelectedPlace/PlaceCreationViewModel.swift, loc/ViewModels/CreatePlaceSheetViewModel.swift, loc/ViewModels/CustomPlaceCreatorViewModel.swift
- **Accessibility identifiers:** `place.detail.save` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:186); `place.detail.createPlace` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:178); `place.detail.share` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:275); `place.detail.note` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:190); `place.detail.writeReview` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:179); `place.detail.reserve` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:123); `place.detail.call` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:168) (place.detail.createPlace on the dropped-pin detail)
- **Backend / Supabase:** Supabase places / my_places inserts via SupabasePlaceService; RPC get_custom_place_creator
- **Known caveats:** Gesture-based; not UI-test friendly.

### Search
- **Purpose:** Full-screen search sheet: Places | People toggle, typeahead place suggestions, AI suggestions, keyword (category) results, coordinate parsing (lat/lng), city results, recent searches.
- **How to reach it:** Tab bar -> Map -> "Search Mesa" pill.
- **Main views/files:** loc/Views/Search/ (SearchPageViewWrapper, SearchPageView, SearchHeaderView, SearchContentView, SearchResultsView, AISuggestionsSection), loc/Views/Map/MapSearchBar.swift
- **ViewModels/services:** loc/ViewModels/Search/SearchViewModel.swift (150 ms debounce places/users/keywords, 500 ms AI), SearchCoordinatorViewModel.swift, SearchPageViewModel.swift, AISuggestionsViewModel.swift; loc/Services/PlaceSearchService.swift, RecentSearchesService.swift, KeywordMappingService, ProfilePhotoCache; UserService.searchUsers
- **Accessibility identifiers:** `search.field` (loc/Views/Search/SearchHeaderView.swift:68); `search.cancel` (loc/Views/Search/SearchHeaderView.swift:93)
- **Backend / Supabase:** `GET /search/suggestions` (provider local_first), `GET /search/place-details`, `POST /search/ai-suggestions` (all Mesa-backend routes/search.py); Supabase RPC search_places_by_types (keyword results), search_cities; user search via UserService.
- **Known caveats:** Sheet is `.large` detent with interactiveDismissDisabled; leave via Cancel (search.cancel). On dismiss MainView handles pending place detail, keyword popup, region focus, and coordinate pin drop. Mode resets to Places on open. No voice search for the search bar (speech is only for voice reviews).

### Recent searches
- **Purpose:** Shows recently selected places/users when the search field is empty.
- **How to reach it:** Search -> empty field (shown only if history exists).
- **Main views/files:** loc/Views/Search/SearchContentView.swift (RecentSearchesView)
- **ViewModels/services:** SearchViewModel.recentSelections, loc/Services/RecentSearchesService.swift (local persistence)
- **Accessibility identifiers:** none
- **Backend / Supabase:** none for list; retrieving a recent place uses place details (`GET /search/place-details`)
- **Known caveats:** Local only, empty on fresh install.

### Keyword results popup
- **Purpose:** Paginated grid of places matching a keyword/category (e.g. "french").
- **How to reach it:** Search -> select a keyword result ("view all") -> sheet over map.
- **Main views/files:** loc/Views/MapView/KeywordResultsPopupView.swift
- **ViewModels/services:** MapViewModel (present .keywordResults), SupabasePlaceService
- **Accessibility identifiers:** none
- **Backend / Supabase:** RPC search_places_by_types, get_keyword_annotations_with_users
- **Known caveats:** Presented via AppCoordinator.hasPendingKeywordPopup after search sheet dismisses.

### Place detail
- **Purpose:** Place sheet: name, save (bookmark), share, rating/open status (inline with the meta row), a horizontal photo+video media strip right under the title, description, action row (Reserve, Menu, Website, Call, Review, Note), private note, reviews/posts section, hours, savers, category correction, travel time, Help Improve Detection row, one scrolling sheet (no About/Feed tabs), damnlines wait-time row (DamnlinesWaitRow.swift; `place.detail.damnlinesWait`; 5 mapped NYC venues).
- **How to reach it:** Tab bar -> Map -> tap a pin; or Search -> pick a place; or list/explore/tonight "open place".
- **Main views/files:** loc/Views/PlaceDetailViews/PlaceDetailView.swift, PlaceDetailTabsView.swift, PlaceInfoSection.swift, AboutTabContent.swift, NotesTabContent.swift, PlaceHoursSheetView.swift, OpenStatusBadgeView.swift, PlaceSaversSheetView.swift, CategoryCorrectionSheet.swift, PlaceFlaggingView.swift, ReserveActionLabel.swift, PlaceActionPillLabel.swift, TravelTimeSelector.swift, PlaceMediaStripView.swift, PlaceMediaStripPhotoTile.swift, PlacePostsView.swift, FullscreenMediaGalleryView.swift, ExternalVideosSection.swift
- **ViewModels/services:** loc/ViewModels/PlaceDetailViewModel.swift, DetailPlaceViewModel.swift, SelectedPlaceViewModel.swift (+ ViewModels/SelectedPlace/*), PlaceDetailTabsViewModel.swift, AboutTabViewModel.swift, NotesTabViewModel.swift, PlaceSaversViewModel.swift, PlaceMediaStripViewModel.swift (+ Models/PlaceMediaStripContent.swift, PlaceMediaStripItem.swift), PlaceInsightsViewModel.swift, ReservationViewModel.swift, DamnlinesWaitViewModel.swift; services DamnlinesWaitService, PlaceRepository, PlaceInsightsService, PlaceListService, PlaceShareService
- **Accessibility identifiers:** `place.detail.save` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:186); `place.detail.createPlace` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:178); `place.detail.share` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:275); `place.detail.note` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:190); `place.detail.writeReview` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:179); `place.detail.reserve` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:123); `place.detail.call` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:168)
- **Backend / Supabase:** `GET /search/place-details`; `GET /places/<place_id>/reservation` (routes/reservations.py); `GET /places/<place_id>/insights` (routes/place_insights.py); `POST /search/refresh-review-images`; RPCs get_place_savers, get_place_total_save_count, get_place_friend_activity, is_place_in_user_lists, get_place_reviews_with_tiktoks, get_place_tiktoks; tables place_notes, favorites, place_list_items, my_places, places.
- **Known caveats:** The bookmark does a one-tap save into the place's city list (CitySaveBannerViewModel) and shows a "Saved to <City>" banner; if already saved (or a dropped pin) it opens the list picker (PlaceListSelectionViewModel) instead. Dropped pins show "Create Place" instead of bookmark/share. Reserve/Menu/Website/Call appear only when data exists. Share is a Menu (Share Link / Create Story Card) for custom places, so place.detail.share only exists for non-custom places. Hours open via the open-status badge. Sheet resizes between min height and 800 pt. The About/Feed tab bar was removed: everything is one scroll (header, media strip, rating/summary/actions, insights, note, would-return, reviews, Help Improve Detection). The strip hides tiles that fail to load or have no URL and collapses when empty; reviews and other empty sections collapse with no gap. The note icon moved from the tab bar to a Note pill in the action row (`place.detail.note`).

### Save to list (from place detail)
- **Purpose:** Choose which list(s) a place belongs to.
- **How to reach it:** Place detail -> bookmark when already saved, or "change list" on the saved banner.
- **Main views/files:** sheet `showListSelection` in PlaceDetailView.swift (list selection view in ListViews)
- **ViewModels/services:** loc/ViewModels/PlaceListSelectionViewModel.swift, PlaceListService
- **Accessibility identifiers:** `place.detail.save` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:186); `place.detail.createPlace` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:178); `place.detail.share` (loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:275); `place.detail.note` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:190); `place.detail.writeReview` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:179); `place.detail.reserve` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:123); `place.detail.call` (loc/Views/PlaceDetailViews/PlaceInfoSection.swift:168) (place.detail.save)
- **Backend / Supabase:** RPC is_place_in_user_lists; tables place_lists, place_list_items
- **Known caveats:** First tap on an unsaved place saves immediately (no picker).

### Create post / review
- **Purpose:** Write a review/post for a place with text, media, ratings, sentiment (Would return?) and optional voice dictation.
- **How to reach it:** Place detail -> "Review" pill in the action row.
- **Main views/files:** loc/Views/PlaceReviews/CreatePostView.swift, VoiceReviewButton.swift, RatingSlidersView.swift, SelectedImagesView.swift, UploadPhotosButtonView.swift, UpvoteFavDishesView.swift, ReviewTextView.swift; post display in Views/PlaceDetailViews/PlacePostsView.swift, PlacePostView.swift, PostActionBar.swift, PostCommentsSheet.swift
- **ViewModels/services:** loc/ViewModels/PlacePostViewModel.swift, VoiceReviewViewModel.swift, PlacePostsViewModel.swift; loc/Services/SpeechTranscriber.swift, PostService
- **Accessibility identifiers:** `post.create.cancel` (loc/Views/PlaceReviews/CreatePostView.swift:74); `post.create.share` (loc/Views/PlaceReviews/CreatePostView.swift:85); `post.create.text` (loc/Views/PlaceReviews/CreatePostView.swift:355) (existing foodSlider/serviceSlider/ambienceSlider in RatingSlidersView.swift)
- **Backend / Supabase:** Supabase tables comments, comment_photos, review_likes via PostService; storage for media
- **Known caveats:** Share is disabled until canSubmit; voice needs mic + speech permission. SharePostButtonView (PostReviewButtonView.swift) appears unused.

### Tonight
- **Purpose:** "Where should we go?" - 3 instant picks from your and friends' saves (vibe chips, More options), one-tap "Ask the group" live vote, Plan for later, list of your group picks.
- **How to reach it:** Tab bar -> Explore -> "Tonight" shortcut card; also push notification tap with no pick id (AppSheetType.tonight via NotificationManager.pendingSheet).
- **Main views/files:** loc/Views/Tonight/TonightSheet.swift, TonightPickCard.swift, TonightVibeChipRow.swift, PlanGroupPickView.swift, GroupPickSheet.swift (+ Invite/Result/Vote/Rank/AddPlace views), PlacePeekSheet.swift
- **ViewModels/services:** loc/ViewModels/Tonight/TonightViewModel.swift, GroupPickViewModel.swift; loc/Services/Tonight/TonightService.swift, GroupPickService
- **Accessibility identifiers:** `tonight.planLater` (loc/Views/Tonight/TonightSheet.swift:189); `tonight.askGroup` (loc/Views/Tonight/TonightSheet.swift:212)
- **Backend / Supabase:** RPCs get_tonight_candidates, create_group_pick, get_group_pick, vote_group_pick, rank_group_pick, create_planned_group_pick, get_planned_group_pick; tables following, users, place_lists
- **Known caveats:** Needs location and friends' saves for good results (empty/"opening later" states otherwise). Explore shortcut presents it through ExploreShortcutSheetView, MainView.tonightSheet is the notification path. Group pick links open via DeepLinkManager.pendingGroupPick.

### Fresh finds
- **Purpose:** Swipeable card stack of recently imported (TikTok/Instagram) places; heart saves a favorite, X skips, info peeks.
- **How to reach it:** Tab bar -> Map -> sparkles button (top right); or Explore -> "Fresh finds" shortcut.
- **Main views/files:** loc/Views/FreshFinds/FreshFindsView.swift, loc/Views/Explore/ExploreShortcutSheetView.swift
- **ViewModels/services:** loc/Views/FreshFinds/FreshFindsViewModel.swift; FavoritesService, SupabasePlaceService.fetchAllUserPlaces, SupabasePostService, ImageCacheService
- **Accessibility identifiers:** none added (map.freshFinds only; card buttons are unlabeled via a generic circleButton helper)
- **Backend / Supabase:** RPC add_favorite_safe; places/external_places reads
- **Known caveats:** Empty state ("Share a TikTok or Reel to Mesa to import places") for new users. Large detent only.

### Feed / Explore feed sheet
- **Purpose:** Photo feed of followed users' posts plus an Explore tab (trending places, recommended users).
- **How to reach it:** Only via AppSheetType.feed (MainView.feedSheet); no current in-app button found that presents .feed.
- **Main views/files:** loc/Views/Feed/PhotoFeedView.swift, FeedCardView.swift, ExploreFeedView.swift, FeedCommentsSheet.swift, TrendingPlaceCard.swift, RecommendedUsersSection.swift
- **ViewModels/services:** loc/ViewModels/PhotoFeedViewModel.swift; PostService.fetchUserFeed
- **Accessibility identifiers:** none
- **Backend / Supabase:** RPCs get_user_feed, get_trending_places, get_recommended_users
- **Known caveats:** Likely unreachable from UI at present (see Gaps).

### Suggested profiles popup
- **Purpose:** Onboarding sheet suggesting people to follow.
- **How to reach it:** Presented from ContentView after onboarding (PresentationService.present(.suggestedProfiles)).
- **Main views/files:** loc/Views/Onboarding/SuggestedProfilesPopupView.swift
- **ViewModels/services:** (onboarding area, not mine)
- **Accessibility identifiers:** none
- **Backend / Supabase:** RPC get_recommended_users
- **Known caveats:** One-time.

#### Area notes: Unsure/skipped
- AppTabBar identifiers use string interpolation of the (constant) title, producing the exact required IDs; if a strictly static literal is required, add an `id` string to the private Item struct.
- No IDs added to FreshFinds card circle buttons (shared private helper with a closure arg) or Feed views.
- ExploreShortcutCard IDs belong to the Explore agent.

#### Area notes: Gaps
- Could not confirm who triggers AppSheetType.feed in the UI; grep found only MainView's builder.
- Did not trace UserService.searchUsers backing RPC/table, nor whether NearbyPlacesService (`GET /nearby-places`) is used by the nearby sheet.
- GoogleMapView clustering/marker internals and MapViewModel filter details only skimmed.
- Place detail sub-sheets (photos gallery, story card, flagging) not documented in depth.



### Explore tab home
- **Purpose:** Discover public lists, cities and people; shortcuts to Tonight and Fresh finds.
- **How to reach it:** Tab bar -> Explore
- **Main views/files:** loc/Views/Explore/ExploreTabView.swift, ExploreShortcutCard.swift, ExploreSkeletonRow.swift, ExplorePeopleSection.swift, ExploreSuggestedPersonCard.swift, ExploreShortcutSheetView.swift
- **ViewModels/services:** loc/ViewModels/Explore/ExploreTabViewModel.swift, ExploreNavigationViewModel.swift, ExplorePeopleViewModel.swift, ExploreListRanker.swift; loc/Services/ExploreListsService.swift, ExploreDiskCache.swift (stale-while-revalidate, ExploreCacheVersion.coverCacheVersion), CoverPhotoStore.swift, ListCoverImageResolver.swift
- **Accessibility identifiers:** `explore.shortcut` (loc/Views/Explore/ExploreShortcutCard.swift:45) `explore.featured` (loc/Views/Explore/ExploreFeaturedCard.swift:55) `explore.list` (loc/Views/Explore/ExploreListCard.swift:27) `explore.city` (loc/Views/Explore/ExploreCityCard.swift:33); `explore.retry` (loc/Views/Explore/ExploreTabView.swift:194)
- **Backend / Supabase:** tables place_lists, place_list_items, users (ExploreListsService); no Mesa-backend route. People section uses RecommendedUsers/user services (not traced).
- **Known caveats:** Own NavigationStack (ExploreDestination values: list, place, city, profile); map shows pins while a list is pushed. "Popular" is client-ranked (no counts from backend). Needs a signed-in user to load. Shortcut cards share one ID (distinguish by label). Shortcuts open sheets: Tonight, Fresh finds.

### Featured list card (with Find a table)
- **Purpose:** Hero card(s) at top of Explore that open a hard-coded featured list, optionally straight into Find a table.
- **How to reach it:** Explore -> top card (tap card, or its "Find a table" button)
- **Main views/files:** loc/Views/Explore/ExploreFeaturedCard.swift; loc/Models/FeaturedListConfig.swift (FeaturedLists.all)
- **ViewModels/services:** ExploreTabViewModel.openFeatured
- **Accessibility identifiers:** `explore.featured` (loc/Views/Explore/ExploreFeaturedCard.swift:55) (also find-table: explore.featured.findTable)
- **Backend / Supabase:** place_lists fetch to resolve the list
- **Known caveats:** Featured list ID is hard-coded; Find a table button only when config.offersFindTable.

### Browse by city / city lists
- **Purpose:** Browse public lists for a city, sorted Popular / Newest / Most places.
- **How to reach it:** Explore -> Browse by city -> city card
- **Main views/files:** loc/Views/Explore/ExploreCityCard.swift, ExploreCityListsView.swift, ExploreCitySkeletonCard.swift, ExploreDestinationView.swift
- **ViewModels/services:** loc/ViewModels/Explore/ExploreCityListsViewModel.swift
- **Accessibility identifiers:** `explore.city` (loc/Views/Explore/ExploreCityCard.swift:33); `explore.retry` (loc/Views/Explore/ExploreTabView.swift:194)
- **Backend / Supabase:** place_lists / place_list_items via ExploreListsService
- **Known caveats:** Sort chips use shared FilterChip (no ID).

### Explore list detail
- **Purpose:** View a public list's places inside Explore (map shows pins), with creator chip, share and Find a table in the sheet header.
- **How to reach it:** Explore -> any list card (Popular near you, city grid, featured)
- **Main views/files:** loc/Views/Explore/ExploreListDetailView.swift, ExploreListCard.swift, ListCreatorChip.swift, ExplorePlaceDestinationView.swift; loc/Views/ListViews/ListPlacesScrollView.swift; loc/Views/SharedComponents/TabSheetHeaderContent.swift
- **ViewModels/services:** loc/ViewModels/Explore/ExploreListDetailViewModel.swift, ListSheetLoadViewModel, ListMapSheetViewModel
- **Accessibility identifiers:** `explore.list` (loc/Views/Explore/ExploreListCard.swift:27)
- **Backend / Supabase:** RPC get_paginated_place_list_places (PlaceListService), place_lists
- **Known caveats:** Header (back/share/Find a table) is rendered by TabSheetHeaderContent, not the view itself; Share button there has only accessibilityLabel "Share" (file outside edit scope).

### City detail sheet (map)
- **Purpose:** Overview of a city (stats, lists, top places, TikToks, active users) from a city annotation or search.
- **How to reach it:** Map tab -> tap a city annotation / search a city
- **Main views/files:** loc/Views/CityDetailSheet.swift (presented from loc/Views/MainView.swift:475), related Views/CityListDetail* via CityListDetailViewModel
- **ViewModels/services:** loc/ViewModels/CityDetailViewModel.swift, CityListDetailViewModel.swift, CitySaveBannerViewModel.swift; SupabasePlaceService
- **Accessibility identifiers:** none added (file is outside assigned dirs)
- **Backend / Supabase:** RPCs get_city_detail_lists, get_city_top_places, get_city_tiktoks, get_city_active_users, get_city_annotations_in_viewport; fetchCityReviewPhotos
- **Known caveats:** Needs EnvironmentObjects (profile, userSession, nav VM, selectedPlaceVM).

### Create list
- **Purpose:** Create a new named list.
- **How to reach it:** Tab bar -> Profile -> Lists + menu -> New List (also from save-to sheet "new list", FullScreenListsView)
- **Main views/files:** loc/Views/ListViews/NewListSheetView.swift; callers Views/MyProfileViews/ProfileViewListsView.swift, FullScreenListsView.swift, ListSelectionSheet.swift
- **ViewModels/services:** none (onSave closure to ProfileListsViewModel / PlaceListService)
- **Accessibility identifiers:** `list.new.name` (loc/Views/ListViews/NewListSheetView.swift:46); `list.new.cancel` (loc/Views/ListViews/NewListSheetView.swift:74); `list.new.save` (loc/Views/ListViews/NewListSheetView.swift:84)
- **Backend / Supabase:** table place_lists insert
- **Known caveats:** Sheet auto-focuses the text field after 0.3s; Save disabled until name nonblank.

### List detail popup (own lists) and overflow menu
- **Purpose:** View/manage one of the user's lists; swipe between lists; overflow menu with Add Place, Add Collaborator, Share Link, Create Story Card, Edit List, List Settings, Delete List.
- **How to reach it:** Profile -> Lists -> tap a list -> ellipsis (top right of header)
- **Main views/files:** loc/Views/MyProfileViews/LightweightListPopupView.swift, Views/ListViews/ListPlacesScrollView.swift, ListPlaceRowView.swift, ListTypeFilterRow.swift, ListSheetLoadView.swift, AddPlaceToListSheet.swift; also PlaceListPopupView.swift, ExternalProfileViews/ExternalUserLightweightListPopupView.swift (other users' lists)
- **ViewModels/services:** ViewModels/Lists/ListsDataViewModel, ListPopupPaginationViewModel, ListMapSheetViewModel, AddPlaceToListViewModel, ListTypeFilterViewModel; PlaceListService
- **Accessibility identifiers:** `list.menu` (loc/Views/MyProfileViews/LightweightListPopupView.swift:361); `list.menu.addPlace` (loc/Views/MyProfileViews/LightweightListPopupView.swift:297); `list.menu.addCollaborator` (loc/Views/MyProfileViews/LightweightListPopupView.swift:304); `list.menu.shareLink` (loc/Views/MyProfileViews/LightweightListPopupView.swift:313); `list.menu.storyCard` (loc/Views/MyProfileViews/LightweightListPopupView.swift:320); `list.menu.edit` (loc/Views/MyProfileViews/LightweightListPopupView.swift:330); `list.menu.settings` (loc/Views/MyProfileViews/LightweightListPopupView.swift:337); `list.menu.delete` (loc/Views/MyProfileViews/LightweightListPopupView.swift:344)
- **Backend / Supabase:** RPCs get_paginated_place_list_places, get_paginated_user_place_lists_by_proximity, search_user_place_lists, get_all_user_list_metadata; tables place_lists, place_list_items
- **Known caveats:** Edit/Settings/Delete only shown for owner (user_role == "owner" or not shared). Delete asks an alert with "Delete" destructive button. Menu items inside a SwiftUI Menu appear only after the menu is opened.

### Rename / edit list
- **Purpose:** Change a list's name and description.
- **How to reach it:** List popup -> ellipsis -> Edit List
- **Main views/files:** loc/Views/ListViews/EditListSheet.swift
- **ViewModels/services:** loc/ViewModels/Lists/EditListViewModel.swift
- **Accessibility identifiers:** `list.edit.name` (loc/Views/ListViews/EditListSheet.swift:31); `list.edit.save` (loc/Views/ListViews/EditListSheet.swift:59)
- **Backend / Supabase:** table place_lists update
- **Known caveats:** Save disabled until a change and valid name.

### List settings (privacy and pricing)
- **Purpose:** Toggle Private List and set a paid price tier (paid lists must be public).
- **How to reach it:** List popup -> ellipsis -> List Settings
- **Main views/files:** loc/Views/ListViews/ListSettingsSheet.swift, ListPricingPickerView.swift, PriceTierChipView.swift
- **ViewModels/services:** ListSettingsViewModel.swift, ListPricingViewModel.swift (ViewModels/Lists); Models/PriceTier.swift
- **Accessibility identifiers:** `list.settings.private` (loc/Views/ListViews/ListSettingsSheet.swift:81); `list.settings.save` (loc/Views/ListViews/ListSettingsSheet.swift:51)
- **Backend / Supabase:** table place_lists update (is_public, price tier)
- **Known caveats:** Pricing picker hidden when list is private.

### Collaborators
- **Purpose:** Search people, add/remove collaborators with roles on a list.
- **How to reach it:** List popup -> ellipsis -> Add Collaborator
- **Main views/files:** loc/Views/Collaboration/ManageCollaboratorsSheet.swift, CollaboratorBadge.swift, AddedByIndicator.swift, SharedByIndicator.swift, SharedWithIndicator.swift
- **ViewModels/services:** loc/ViewModels/Collaboration/ManageCollaboratorsViewModel.swift; loc/Services/CollaborationService.swift; Models/Collaboration/
- **Accessibility identifiers:** `list.collaborators.search` (loc/Views/Collaboration/ManageCollaboratorsSheet.swift:56)
- **Backend / Supabase:** RPCs get_list_collaborators, get_user_shared_lists, get_user_collaborative_owned_lists, get_list_with_collaboration_info, add_list_collaborator; tables place_list_collaborators, place_lists
- **Known caveats:** Requires a second user account to exercise end to end.

### Share list (link and story card)
- **Purpose:** Share a list link, or generate an Instagram-style story card of the list.
- **How to reach it:** List popup -> ellipsis -> Share Link / Create Story Card; Explore list header Share button
- **Main views/files:** loc/Views/Sharing/ListShareCardView.swift, ListStoryCardView.swift, ListStoryShareButton.swift, StoryPhotoSelectorView.swift
- **ViewModels/services:** loc/ViewModels/ListStoryCardViewModel.swift; ServiceContainer.placeShareService (PlaceShareService.shareLightweightList)
- **Accessibility identifiers:** `list.menu` (loc/Views/MyProfileViews/LightweightListPopupView.swift:361); `list.menu.addPlace` (loc/Views/MyProfileViews/LightweightListPopupView.swift:297); `list.menu.addCollaborator` (loc/Views/MyProfileViews/LightweightListPopupView.swift:304); `list.menu.shareLink` (loc/Views/MyProfileViews/LightweightListPopupView.swift:313); `list.menu.storyCard` (loc/Views/MyProfileViews/LightweightListPopupView.swift:320); `list.menu.edit` (loc/Views/MyProfileViews/LightweightListPopupView.swift:330); `list.menu.settings` (loc/Views/MyProfileViews/LightweightListPopupView.swift:337); `list.menu.delete` (loc/Views/MyProfileViews/LightweightListPopupView.swift:344) (shareLink, storyCard)
- **Backend / Supabase:** none traced for link building (deep link loc://list/{id})
- **Known caveats:** Share sheet is system UI; story flow shows a "Link Copied" alert and photo selector sheet.

### Find a table (Resy availability)
- **Purpose:** Search a list's reservable places for open tables (party size, day, time window). Never books.
- **How to reach it:** Explore -> featured card "Find a table"; or any list with reservable places -> header "Find a table" button -> form -> Search; results as chips/pills/status bar
- **Main views/files:** loc/Views/ListViews/FindTableButton.swift, FindTableSheet.swift, FindTableChip.swift, FindTableStatusBar.swift, FindTableMessageView.swift, TableSlotPills.swift, ListPlacesScrollView.swift, Views/SharedComponents/TabSheetHeaderContent.swift
- **ViewModels/services:** loc/ViewModels/Lists/FindTableViewModel.swift, ListTypeFilterViewModel+FindTable.swift; loc/Services/TableAvailabilityService.swift, TableAvailabilityCache.swift (5 min), FindTableLog.swift; loc/Models/TableAvailability/*
- **Accessibility identifiers:** `explore.featured.findTable` (loc/Views/Explore/ExploreFeaturedCard.swift:102); `list.findTable` (loc/Views/ListViews/FindTableButton.swift:30); `list.findTable.search` (loc/Views/ListViews/FindTableSheet.swift:48)
- **Backend / Supabase:** `POST /lists/<list_id>/availability` (Mesa-backend routes/availability.py)
- **Known caveats:** Button hidden unless list has reservable places and the backend has not answered 404/405/501 this session (gate closed until app restart). Live Resy results vary, so assertions on slots are flaky. Real network needed.

### Place reservation link
- **Purpose:** Show a Resy/OpenTable/Tock/SevenRooms link on a place page.
- **How to reach it:** Place detail -> action row / summary (no tabs)
- **Main views/files:** loc/Views/PlaceDetailViews/AboutTabContent.swift; loc/Models/ReservationLink.swift
- **ViewModels/services:** loc/ViewModels/ReservationViewModel.swift; MesaBackendService.fetchReservation
- **Accessibility identifiers:** none (outside assigned files)
- **Backend / Supabase:** `GET /places/<place_id>/reservation` (routes/reservations.py, cached 30 days)
- **Known caveats:** Only shows when a link exists.

### Save to list (save-to sheet) and Saved banner
- **Purpose:** Add a place to a list or trip; confirmation banner "Added to {City}" with change action.
- **How to reach it:** Place detail -> Save (place.detail.save) -> ListSelectionSheet (Lists / Trips tabs, New list)
- **Main views/files:** loc/Views/ListViews/ListSelectionSheet.swift, FavoritesSelectionRow.swift, SharedComponents/SavedBannerView.swift
- **ViewModels/services:** ViewModels/PlaceListSelectionViewModel.swift, Lists/CitySaveViewModel.swift, CityListMatcher.swift, CanonicalCityResolver.swift (mirrors backend services/city_resolver.py); FavoritesService
- **Accessibility identifiers:** none added (not assigned)
- **Backend / Supabase:** RPC is_place_in_user_lists, add_favorite_safe; tables place_list_items, favorites
- **Known caveats:** One-tap save auto-files into a per-city list.

### Saved library (on-device grouping)
- **Purpose:** Pure client-side grouping of the user's places by city/type/cuisine plus smart groups.
- **How to reach it:** not traced to a visible entry point
- **Main views/files:** n/a
- **ViewModels/services:** loc/ViewModels/Saved/SavedLibraryBuilder.swift, ImportAutoSave.swift
- **Accessibility identifiers:** none
- **Backend / Supabase:** none (read-only)
- **Known caveats:** Builder is unit tested; UI wiring unclear.

### Paid lists, purchase, creator earnings
- **Purpose:** Sell lists via StoreKit price tiers; buyers unlock; creators view earnings.
- **How to reach it:** Setting price: List settings sheet. Purchase/earnings UI: see caveats.
- **Main views/files:** loc/Views/ListViews/ListPurchaseSheet.swift, PaidListTeaserOverlay.swift, CreatorEarningsView.swift
- **ViewModels/services:** ViewModels/Lists/ListPurchaseViewModel.swift, CreatorEarningsViewModel.swift; Services/ListPurchaseService.swift, StoreKitService.swift (mesa_list_tier_* products); Models/ListPurchase.swift, PriceTier.swift
- **Accessibility identifiers:** none
- **Backend / Supabase:** RPCs check_list_purchase, record_list_purchase, get_creator_earnings_summary; table list_purchases
- **Known caveats:** No call sites found for ListPurchaseSheet, PaidListTeaserOverlay or CreatorEarningsView in loc/ (grep), so purchase UI appears unwired. Requires StoreKit config; hard in UI tests.

### List reorder
- **Purpose:** n/a
- **How to reach it:** no list reorder UI found. Lists are sorted by proximity (ListsDistanceSortingViewModel). Reorder only exists for trip itinerary (Views/Trips/TripDayItineraryView.swift).
- **Main views/files:** n/a
- **ViewModels/services:** n/a
- **Accessibility identifiers:** none
- **Backend / Supabase:** n/a
- **Known caveats:** n/a

#### Area notes: Unsure/skipped
- ExploreCityListsView sort chips (shared FilterChip, would need editing shared file), ListActionsMenu (+ menu belongs to profile agent), TabSheetHeaderContent Share/FindTable header (FindTableButton already carries list.findTable), CityDetailSheet (not in assigned dirs, many EnvironmentObjects), ListSelectionSheet rows.

#### Area notes: Gaps
- Explore people section data sources, ExploreDestination routing details, ExploreListsService backend queries not read in depth.
- Delete-list confirmation alert buttons are alert actions (no IDs possible via modifier).
- Where Saved library UI is surfaced; whether purchase UI is reachable.
- Sharing/ListStoryShareButton usage not traced.


### Trips list
- **Purpose:** Shows the user's current and past trips; entry to create or open a trip.
- **How to reach it:** Tab bar -> Trips (root of tab, `showsCloseButton: false`); also presentable modally with a Close button.
- **Main views/files:** loc/Views/Trips/TripsListView.swift, TripCardView.swift, NewTripTileView.swift, TripSkeletonViews.swift, TripTabActivationModifier.swift
- **ViewModels/services:** loc/ViewModels/Trips/TripsListViewModel.swift; loc/Services/TripService.swift, TripDataCache.swift
- **Accessibility identifiers:** `trips.row` (loc/Views/Trips/TripsListView.swift:180); `trip.close` (loc/Views/Trips/TripsListView.swift:64); `trips.create` (loc/Views/Trips/TripsListView.swift:146); `trips.new` (loc/Views/Trips/NewTripTileView.swift:28)
- **Backend / Supabase:** RPC `get_user_trips`
- **Known caveats:** Reloads on tab activation and scenePhase active. Empty state shows "Create Trip" (trips.create); non-empty list shows a "+" tile (trips.new) above the cards. Past trips are collapsed behind a "Past trips (n)" header. A trip push notification auto-navigates via NotificationManager.pendingTripId. TripMapExitModifier clears trip pins and routes from the main map when a trip is popped or the tab hides.

### Create trip wizard
- **Purpose:** Multi-step flow to name a trip, pick dates, and add contributors.
- **How to reach it:** Trips tab -> "+" tile (or Create Trip in the empty state); or Profile -> Lists "+" menu -> New Trip.
- **Main views/files:** loc/Views/Trips/CreateTripView.swift, TripNameStepView.swift, TripDatesStepView.swift, DateRangeCalendarView.swift, DateRangeDayCellView.swift, TripContributorsStepView.swift, TripInviteByTextView.swift, MessageComposeView.swift, TripCreatingView.swift, TripCompletedView.swift, TripFailedView.swift
- **ViewModels/services:** loc/ViewModels/Trips/CreateTripViewModel.swift, DateRangePickerViewModel.swift, TripInviteViewModel.swift; loc/Services/TripService.swift, TripInvitationService.swift, TripCollaborationService.swift
- **Accessibility identifiers:** `trip.create.cancel` (loc/Views/Trips/CreateTripView.swift:48); `trip.create.name` (loc/Views/Trips/TripNameStepView.swift:38); `trip.create.next` (loc/Views/Trips/TripNameStepView.swift:61)
- **Backend / Supabase:** tables `trips`, `trip_collaborators`, `trip_invitations`
- **Known caveats:** Presented as a fullScreenCover. Cancel shows only on the name step, Back on later steps. Invite by text uses the system message composer, which is not available in the simulator. The Next button is disabled until the name is non-empty.

### Trip detail and itinerary
- **Purpose:** View and edit a trip's days, itinerary, and ideas, with travel times between stops.
- **How to reach it:** Trips tab -> tap a trip card (NavigationLink by tripId).
- **Main views/files:** loc/Views/Trips/TripDetailView.swift, TripDetailContentView.swift, TripDetailHeaderView.swift, TripDaySelectorView.swift, TripDayDetailView.swift, TripDayItineraryView.swift, TripCalendarGridView.swift, TripIdeasSectionView.swift, TripPlaceRowView.swift, TripTimelinePlaceCard.swift, TripTravelTimeConnectorView.swift, AddPlaceToTripSheet.swift, TripPlaceSearchContentView.swift, TripBrowsePlacesView.swift, TripBrowseListPlacesView.swift
- **ViewModels/services:** loc/ViewModels/Trips/TripDetailViewModel.swift, AddPlaceToTripViewModel.swift, TripTravelTimesViewModel.swift; loc/Services/TripService.swift, TripRouteService.swift (MapKit MKDirections walking routes, no backend), TripDataCache.swift
- **Accessibility identifiers:** `trip.menu` (loc/Views/Trips/TripDetailView.swift:113)
- **Backend / Supabase:** RPCs `get_trip_with_places`, `reorder_trip_day_places`; tables `trips`, `trip_day_places`
- **Known caveats:** Ellipsis menu has Manage People (all) and Delete Trip (owner only). Itinerary reorder uses drag and drop, which is hard to automate. Selecting a day or place detail leaves map annotations on the main map.

### Trip map and overlays
- **Purpose:** Map view of a trip's places with day selector and itinerary sheet.
- **How to reach it:** Open a trip; the trip's pins and routes show on the main map. TripMapView is also used from the trip.
- **Main views/files:** loc/Views/Trips/TripMapView.swift, TripMapItinerarySheetView.swift, TripMapDaySelectorView.swift, TripMapDayPlacesListView.swift, TripMapPlacePin.swift, TripItineraryPinView.swift, TripMapExitModifier.swift
- **ViewModels/services:** loc/ViewModels/Trips/TripMapViewModel.swift, TripsListViewModel.swift; loc/Services/TripRouteService.swift
- **Accessibility identifiers:** none added
- **Backend / Supabase:** none (MapKit directions)
- **Known caveats:** Exit logic (clearing the map when leaving the trip or the tab) lives in TripMapExitModifier and TripsListViewModel. No IDs were added here.

### Trip collaborators and invites
- **Purpose:** Add or remove trip collaborators and invite people by phone/SMS link.
- **How to reach it:** Trip detail -> ellipsis menu -> Manage People.
- **Main views/files:** loc/Views/Trips/ManageTripCollaboratorsSheet.swift, TripInviteByTextView.swift, TripContributorsStepView.swift
- **ViewModels/services:** loc/ViewModels/Trips/TripCollaboratorsViewModel.swift, TripInviteViewModel.swift; loc/Services/TripCollaborationService.swift, TripInvitationService.swift
- **Accessibility identifiers:** none added
- **Backend / Supabase:** tables `trip_collaborators`, `trip_invitations`, `users`, `trips`; RPCs `redeem_pending_invitations`, `redeem_invitation_by_token`
- **Known caveats:** Invites are redeemed on signup (by phone) or via deep link token. Needs a second account to test fully.

### Add place to trip (from place detail)
- **Purpose:** Add a place to a trip's ideas/itinerary from elsewhere in the app.
- **How to reach it:** Place detail -> add to trip (selection sheet).
- **Main views/files:** loc/Views/Trips/TripsInSelectionSheet.swift, TripSelectionRowView.swift
- **ViewModels/services:** loc/ViewModels/Trips/PlaceTripSelectionViewModel.swift; loc/Services/TripService.swift
- **Accessibility identifiers:** none added
- **Backend / Supabase:** tables `trip_day_places`; `fetchPlaceTripMembership` queries `trip_day_places`
- **Known caveats:** The exact entry point in place detail was not traced.

### Profile page (own)
- **Purpose:** Shows the user's header, counts, photo-import card, lists, favorites, reviews, and places.
- **How to reach it:** Tab bar -> Profile.
- **Main views/files:** loc/Views/MyProfileViews/ProfileView.swift, ProfileContentView.swift, ProfilePictureView.swift, FavoritesPopupView.swift, ReviewsListPopupView.swift, MyPlacesListView.swift, ProfileFavoritesExternalPlacesView.swift
- **ViewModels/services:** loc/ViewModels/ProfileViewModel.swift (parent, composes ProfileSocialViewModel, ProfileAccountViewModel, ProfileFavoritesViewModel, ProfileMyPlacesViewModel, ProfileReviewsViewModel, ProfileExternalContentViewModel, ProfileListsViewModel, ProfileNotesViewModel); loc/Services/SupabaseUserService.swift
- **Accessibility identifiers:** none added
- **Backend / Supabase:** table `users`; RPCs `get_user_stats`, `get_user_total_places_count`, `get_user_external_places_count`, `get_user_created_places_count`, `get_user_reviewed_places_count`
- **Known caveats:** Account menu and edit profile are covered by another area.

### Profile photo import card
- **Purpose:** Call-to-action to import photos and discover places.
- **How to reach it:** Tab bar -> Profile -> "Import Photos to Discover Places" card.
- **Main views/files:** loc/Views/MyProfileViews/ProfileQuickActionsRow.swift (shown by ProfileContentView.swift:82)
- **ViewModels/services:** photoImportVM.handleImportButtonTap() (PhotoImport view model)
- **Accessibility identifiers:** `import.photos` (loc/Views/MyProfileViews/ProfileQuickActionsRow.swift:44)
- **Backend / Supabase:** not traced here
- **Known caveats:** May be hidden under conditions in ProfileContentView, and it needs photo permission, which is hard in UI tests.

### Profile lists section and "+" menu
- **Purpose:** Search and browse the user's lists; create a list, create a trip, or import from Google Maps.
- **How to reach it:** Tab bar -> Profile -> lists section; tap "+" beside the "Search lists..." bar. The search bar opens FullScreenListsView, which has the same menu.
- **Main views/files:** loc/Views/MyProfileViews/ProfileViewListsView.swift, FullScreenListsView.swift, ProfileListSection.swift, LightweightProfileListSection.swift, CreateListTileView.swift, ListsSearchBar.swift, loc/Views/SharedComponents/ListActionsMenu.swift (the "+" menu: New List, New Trip, Import from Google Maps)
- **ViewModels/services:** loc/ViewModels/ProfileListsViewModel.swift; loc/Services/PlaceListService.swift
- **Accessibility identifiers:** `profile.lists.add` (loc/Views/SharedComponents/ListActionsMenu.swift:43); `lists.menu.newList` (loc/Views/SharedComponents/ListActionsMenu.swift:22); `lists.menu.newTrip` (loc/Views/SharedComponents/ListActionsMenu.swift:26); `import.googleMaps` (loc/Views/SharedComponents/ListActionsMenu.swift:30)
- **Backend / Supabase:** RPCs `get_paginated_user_place_lists_by_proximity`, `search_user_place_lists`, `get_all_user_list_metadata`, `get_paginated_place_list_places`
- **Known caveats:** The menu IDs live in the shared ListActionsMenu, so they appear in both ProfileViewListsView and FullScreenListsView (two instances in the hierarchy when the full-screen cover is open). New List opens a sheet, New Trip opens CreateTripView as a fullScreenCover, and Import opens GoogleMapsImportView as a sheet. Tapping a list closes the profile and shows the list on the map.

### Followers / following lists
- **Purpose:** View followers and following for the user or another user, with follow toggles.
- **How to reach it:** Profile -> tap the Followers or Following count.
- **Main views/files:** loc/Views/MyProfileViews/FollowersListView.swift, FollowingListView.swift, UserRow.swift; loc/Views/ExternalProfileViews/ProfileFollowersListView.swift, ProfileFollowingListView.swift
- **ViewModels/services:** loc/ViewModels/ProfileSocialViewModel.swift, ExternalUserProfileViewModel.swift; loc/Services/SupabaseUserService.swift
- **Accessibility identifiers:** none added
- **Backend / Supabase:** table `following`, `users`
- **Known caveats:** Following count is hidden on curated profiles.

### Other users' profiles and follow/unfollow
- **Purpose:** View another user's profile, lists, favorites, and reviews; follow or unfollow.
- **How to reach it:** Tap a user from search, feed, place reviews, followers lists, or a notification/deep link (`loc://profile/{id}`); navigation is handled by UserProfileNavigationViewModel.
- **Main views/files:** loc/Views/ExternalProfileViews/ExternalUserProfileViewWrapper.swift, ExternalUserProfileContentView.swift, ExternalUserProfileListsView.swift, ExternalUserProfileFavoritesReviewsView.swift, ExternalFavoritesListPopupView.swift, ExternalReviewsListPopupView.swift, ExternalUserLightweightListPopupView.swift
- **ViewModels/services:** loc/ViewModels/ExternalUserProfileViewModel.swift, UserProfileNavigationViewModel.swift, ViewModels/ExternalProfile/ExternalListsDataViewModel.swift, ExternalListsLoadingViewModel.swift; loc/Services/SupabaseUserService.swift
- **Accessibility identifiers:** `profile.external.follow` (loc/Views/ExternalProfileViews/ExternalUserProfileContentView.swift:85)
- **Backend / Supabase:** table `following` (insert/delete in followUser/unfollowUser), `users`
- **Known caveats:** Needs a second account or seeded data to test.

### Recommended users
- **Purpose:** Suggests users to follow, excluding self and already-followed users.
- **How to reach it:** Feed -> RecommendedUsersSection; Explore -> people section.
- **Main views/files:** loc/Views/Feed/RecommendedUsersSection.swift, RecommendedUserCard.swift, loc/Views/Explore/ExplorePeopleSection.swift
- **ViewModels/services:** loc/ViewModels/RecommendedUsersViewModel.swift; loc/Services/SupabaseUserService.swift (fetchRecommendedUsers)
- **Accessibility identifiers:** none added
- **Backend / Supabase:** RPC `get_recommended_users`
- **Known caveats:** Files live outside this area's edit list, so no IDs were added.

#### Area notes: Gaps
- Trips use Supabase only; the Mesa-backend has no trip routes (checked only by filename grep).
- Entry point of TripsInSelectionSheet from place detail was not traced.
- Notes and favorites sub-views and ProfileContentView's conditions for hiding sections were not examined in depth.
- Backend use by the photo import was not traced.

#### Area notes: Unsure/skipped
- IDs for trip-detail items such as Manage People and Delete Trip (inside a Menu with role, left alone).
- Trip map, itinerary, and collaborator sheets.
- Followers and following rows.
- The My Profile "Search lists..." button (in ProfileViewListsView, skipped to stay at the minimum).



### Google Maps list import
- **Purpose:** Paste a shared Google Maps list URL; extract places, resolve each, then create a new list or add to an existing list.
- **How to reach it:** (a) Tab bar -> Profile -> Lists section "+" menu (`profile.lists.add`) -> "Import from Google Maps" (`import.googleMaps`); same menu in the full-screen lists view. (b) New-user onboarding: ListOnboardingView (shown from ContentView) presents the same view with Cancel relabelled "Skip".
- **Main views/files:** loc/Views/MyProfileViews/GoogleMapsImportView.swift (sheet, states: URL entry -> extracting -> resolving N of M -> preview with Create New List / Add to Existing toggle -> adding -> completed or failed); loc/Views/SharedComponents/ListActionsMenu.swift (menu entry); loc/Views/MyProfileViews/ProfileViewListsView.swift, FullScreenListsView.swift (present the sheet); loc/Views/Onboarding/ListOnboardingView.swift.
- **ViewModels/services:** loc/ViewModels/GoogleMapsImportViewModel.swift; loc/Services/GoogleMapsImportService.swift; loc/Models/GoogleMapsImportResult.swift; PlaceRepository (owns a GoogleMapsImportService); SupabaseUserService.addPlaceToList, PlaceService.createNewList.
- **Accessibility identifiers:** `import.cancel` (loc/Views/MyProfileViews/GoogleMapsImportView.swift:65); `import.googleMaps.url` (loc/Views/MyProfileViews/GoogleMapsImportView.swift:99); `import.googleMaps.submit` (loc/Views/MyProfileViews/GoogleMapsImportView.swift:114); `import.googleMaps.listName` (loc/Views/MyProfileViews/GoogleMapsImportView.swift:260); `import.googleMaps.create` (loc/Views/MyProfileViews/GoogleMapsImportView.swift:473); `import.googleMaps.done` (loc/Views/MyProfileViews/GoogleMapsImportView.swift:544); `import.googleMaps.retry` (loc/Views/MyProfileViews/GoogleMapsImportView.swift:582)
- **Backend / Supabase:** `POST /maps/extract-list` (phase 1), `POST /maps/resolve-place` (phase 2, per place, bounded concurrency), `POST /maps/import-list` (one-shot variant, defined in service). List creation and add-place go through Supabase (createNewList, addPlaceToList).
- **Known caveats:** Cancel calls viewModel.cancelImport() (cancels VM-owned task) and also runs on disappear. Resolve is concurrent so progress counter order is not deterministic. Only works on shared-list links. Network required; hard to UI-test without a real Google Maps list URL (use a maps.app.goo.gl list link).

### Import help sheet
- **Purpose:** Infographic explaining how to import places from videos (share from TikTok/Instagram).
- **How to reach it:** Profile -> favorites/external places section -> Videos (external places) tab -> help (?) button -> ImportHelpView sheet.
- **Main views/files:** loc/Views/MyProfileViews/ImportHelpView.swift; presented from loc/Views/MyProfileViews/ProfileFavoritesExternalPlacesView.swift (activePopupSheet = .help via onExternalPlacesHelpTap).
- **ViewModels/services:** none (static content).
- **Accessibility identifiers:** `import.help.done` (loc/Views/MyProfileViews/ImportHelpView.swift:33)
- **Backend / Supabase:** none
- **Known caveats:** Help button only shown when the external places tab is enabled (own profile only; external profile passes nil).

### Photo import ("Import Photos to Discover Places")
- **Purpose:** Pick photos from the library; cluster by GPS, find nearby places, and create review posts / save places.
- **How to reach it:** Tab bar -> Profile -> "Import Photos to Discover Places" card (`import.photos`). First time shows an alert "Import Photos" -> "Got it" -> PhotosPicker (max 20 images). A one-time coach mark (PhotoImportTooltip, auto-dismiss 6s, key hasSeenPhotoImportTooltip) points at it. 1 GPS cluster -> PlaceSelectionView sheet; 2+ clusters -> "Review Places" (PhotoClusterOverviewView) with map, cluster cards, unassigned photos, Done; then CreatePostView per place. No-GPS photos -> "No Location Data" alert.
- **Main views/files:** loc/Views/MyProfileViews/ProfileQuickActionsRow.swift, ProfileContentView.swift, ProfileView.swift (picker, alert, sheets), PhotoImportTooltip.swift; loc/Views/PlaceReviews/Components/{PlaceSelectionView,PhotoClusterOverviewView,PhotoClusterCardView,PhotoClusterMapView,UnassignedPhotosCard,PlaceSelectionPhotoHeader}.swift.
- **ViewModels/services:** loc/ViewModels/PhotoImportViewModel.swift, PhotoClusteringViewModel.swift (child VM); loc/Models/{PhotoClusterBuilder,PhotoLocationCluster,PhotoSample,PhotoItem}.swift; loc/Services/NearbyPlacesService.swift.
- **Accessibility identifiers:** `import.photos.tooltip.dismiss` (loc/Views/MyProfileViews/PhotoImportTooltip.swift:49); `import.photos.cancel` (loc/Views/PlaceReviews/Components/PhotoClusterOverviewView.swift:48)
- **Backend / Supabase:** `GET /nearby-places` (via NearbyPlacesService), `GET /search/place-details` (MesaBackendService.fetchPlaceDetails); place/post saves via PlaceService/UserService (Supabase).
- **Known caveats:** System PhotosPicker and permission alerts are not accessible from the app's own element tree (use XCUI system UI handling). Photos need EXIF GPS; simulator photos usually lack it. Onboarding flag hasSeenPhotoImportOnboarding persists in UserDefaults (reset between UI-test runs).

### Video/URL import (TikTok / Instagram) progress sheet
- **Purpose:** Turn a shared TikTok/Instagram URL into saved places with live progress, then one-tap save to a list.
- **How to reach it:** From another app (TikTok/Instagram) Share -> "Mesa" share extension -> app opens loc://share/content?url=... -> DeepLinkManager -> PresentationService.present(.importProgress(contentUrl:)) -> ImportProgressView sheet (MainView sheetContent). Also reopened via `.importJob(jobId)` from an `import_complete` push / local notification tap. Also startImport is used in onboarding (ListOnboardingViewModel).
- **Main views/files:** loc/Views/PlaceDetailViews/ImportProgressView.swift (header with spinner/status, live place rows with "Wrong?" menu, "Add a place the video missed", list search/create field, save button, Hide/Done footer); loc/Views/MainView.swift (sheet host); loc/Views/ExternalPlaceSelectionView.swift and loc/Views/PlaceDetailViews/ImportPlaceConfirmationView.swift (older confirm/choose flows; ImportPlaceConfirmationView asks "is this the right place?").
- **ViewModels/services:** loc/ViewModels/ImportProgressViewModel.swift, ImportPlaceConfirmationViewModel.swift, ProfileExternalContentViewModel.swift; loc/Services/Import/ImportTracker.swift (persists pending job ids under ImportTracker.pending.v1, polls every 3s, 30-min max age, resumes on launch/foreground); loc/Services/ExternalContentService.swift; loc/Models/ImportJob.swift; loc/ViewModels/Saved/ImportAutoSave.swift; loc/Services/DeepLinkManager.swift (dedupes URLs within 30s).
- **Accessibility identifiers:** `import.progress.done` (loc/Views/PlaceDetailViews/ImportProgressView.swift:350); `import.progress.hide` (loc/Views/PlaceDetailViews/ImportProgressView.swift:374)
- **Backend / Supabase:** `POST /process-url` (starts async job / sync result), `GET /import-jobs/<job_id>` (poll; table import_jobs), `GET|POST /tiktok/oembed`, `POST /refresh-thumbnail`; backend sends `import_complete` push (edge function send-push-notification).
- **Known caveats:** Cannot be triggered from UI tests without the Share sheet; simulate with `xcrun simctl openurl booted "loc://share/content?url=<encoded tiktok url>"`. Needs real backend job. Many ImportProgressView controls (Wrong?, row toggles, save button, search field) have no identifiers (ImportSaveButton/ImportSaveSection are private structs, skipped).

### Share extension (MesaShare)
- **Purpose:** Headless iOS share extension that accepts TikTok/Instagram links from other apps and hands them to Mesa.
- **How to reach it:** Share sheet in TikTok/Instagram/Safari -> Mesa. Activation: one web URL or text (MesaShare/Info.plist NSExtensionActivationSupportsWebURLWithMaxCount=1, SupportsText).
- **Main views/files:** MesaShare/ShareViewController.swift (no UI; view alpha 0), MesaShare/Info.plist, MesaShare/MesaShare.entitlements, MesaShare/MesaShareRelease.entitlements. ShareExtension/ contains only ShareExtension.entitlements (no source; appears to be a leftover/legacy target).
- **ViewModels/services:** none in extension. Receiving side: loc/Services/DeepLinkManager.swift (host "share", paths /content and /tiktok -> handleExternalContentDeepLink; /list -> handleListShareDeepLink; host "tiktok-shared" -> reads URL from App Group/UserDefaults), loc/locApp.swift (onOpenURL, universal links, `onContinueUserActivity("com.mesa.share.tiktok")`, checkForSharedContentURL on launch).
- **Accessibility identifiers:** none added
- **Backend / Supabase:** none directly (app then calls POST /process-url).
- **Known caveats:** Hand-off is the URL scheme `loc://share/content?url=<percent-encoded>`; the extension walks the responder chain to find UIApplication and calls open(). The code comment says this avoids App Group/UserDefaults issues, but the app group `group.com.drewhartsfield.mesa` is still declared in loc, MesaShare and ShareExtension entitlements and the app still has fallback reads of UserDefaults keys sharedTikTokURL / sharedContentURL. Supported domains: tiktok.com, vm.tiktok.com, vt.tiktok.com, instagram.com, instagr.am (Instagram text regex only reel/reels/p paths). No SwiftUI in extension; no IDs added. Not testable in XCUITest.

### Recently imported (map imports sheet)
- **Purpose:** Shows the user's recently imported external (video) places with an All / Near me scope toggle, shown on the map.
- **How to reach it:** Profile -> favorites/external places section -> "Recently imported"/Videos tab -> popup (ExternalPlacesPopupView) with RecentlyImportedScopeToggle; also pins on the map.
- **Main views/files:** loc/Views/MyProfileViews/ExternalPlacesPopupView.swift, ExternalPlaceCard.swift, ProfileFavoritesExternalPlacesView.swift; loc/Views/ReusableViews/RecentlyImportedScopeToggle.swift.
- **ViewModels/services:** loc/ViewModels/RecentlyImportedViewModel.swift (owned by ProfileViewModel), loc/Models/RecentlyImportedScope.swift, loc/ViewModels/Map/ImportsMapFraming.swift, ProfileExternalContentViewModel.swift.
- **Accessibility identifiers:** none added
- **Backend / Supabase:** RPCs get_user_external_places, get_user_external_places_count (via userService.fetchUserExternalPlaces); get_external_places_annotations for map pins (db function files in database_functions/).
- **Known caveats:** "Near me" uses a 20-mile radius and is disabled when location is off ("Location off" note). Exact Supabase call for count not verified from the VM.

### External videos on place detail
- **Purpose:** Show TikTok/Instagram videos linked to a place, play/open them, delete from place.
- **How to reach it:** Place detail -> media strip (videos carry a play badge; tap plays, long-press deletes own videos); ExternalVideosSection is now only the compact Help Improve Detection row.
- **Main views/files:** loc/Views/PlaceDetailViews/ExternalVideosSection.swift, ExternalVideoView.swift, ExternalWebView.swift, ExternalReviewPhotoGallery.swift; loc/Views/Map/CityTikTokTile.swift.
- **ViewModels/services:** loc/ViewModels/ExternalVideosViewModel.swift, ExternalVideoViewModel.swift, ExternalMetadataCache; loc/Services/TikTokPlaceService.swift, ExternalContentService.swift; loc/Models/ExternalVideo.swift, ExternalPlace.swift.
- **Accessibility identifiers:** `place.detail.mediaStrip`, `place.detail.mediaStrip.video`, `place.detail.helpImproveDetection`
- **Backend / Supabase:** RPC get_places_for_tiktok_video; table external_places (select/delete); `POST /refresh-thumbnail`; `GET /tiktok/oembed`; `POST /search/refresh-review-images` (ExternalReviewPhotosViewModel).
- **Known caveats:** Loads WebView embeds from tiktok.com/instagram.com (baseURL in ExternalWebView); needs network and seeded external data.

### Photo feed
- **Purpose:** Feed of review photos from followed users (Feed + Explore tabs), with likes.
- **How to reach it:** MainView sheet `.feed` (AppSheetType.feed) - the presenting control was not located.
- **Main views/files:** loc/Views/Feed/PhotoFeedView.swift (tabs via FeedTabButton), loc/Views/MainView.swift:520 feedSheet.
- **ViewModels/services:** loc/ViewModels/PhotoFeedViewModel.swift; ExploreViewModel; postService.fetchUserFeed/likePost/unlikePost.
- **Accessibility identifiers:** none added
- **Backend / Supabase:** RPC get_followed_users_photos (SupabasePlaceService); post like/unlike via Supabase post service.
- **Known caveats:** Entry point unknown (see Gaps).

### Contacts matching (onboarding)
- **Purpose:** Find existing Mesa users among device contacts (suggest people to follow), only after explicit in-app consent.
- **How to reach it:** Onboarding -> Suggested profiles popup -> "People in Your Contacts" section; ContactsConsentCard asks Allow/Decline first, then system Contacts permission.
- **Main views/files:** loc/Views/Onboarding/SuggestedProfilesPopupView.swift, ContactsMatchSection.swift, ContactsConsentCard.swift.
- **ViewModels/services:** loc/ViewModels/Onboarding/SuggestedProfilesViewModel.swift (needsContactsConsent, grantContactsConsent, declineContactsConsent); loc/Services/ContactsService.swift (phone numbers normalized via PhoneNumberNormalizer then uploaded).
- **Accessibility identifiers:** none added
- **Backend / Supabase:** RPC match_contacts_by_phone.
- **Known caveats:** System Contacts permission dialog; consent flag stored by ContactsService.recordUploadConsent. Not an import into lists.

### Voice review (dictation)
- **Purpose:** Dictate a review: record, live-transcribe, summarize on-device, fill the review text; undo / toggle full transcript.
- **How to reach it:** Create review/post screen (CreatePostView) -> mic button (VoiceReviewButton).
- **Main views/files:** loc/Views/PlaceReviews/VoiceReviewButton.swift, loc/Views/PlaceReviews/CreatePostView.swift:373.
- **ViewModels/services:** loc/ViewModels/VoiceReviewViewModel.swift (phases idle/recording/summarizing, max 120s), loc/Services/SpeechTranscriber.swift (AVAudioEngine + SFSpeechRecognizer), loc/Services/ReviewSummarizer.swift (FoundationModels on iOS 26 when available, else cleaned transcript).
- **Accessibility identifiers:** none added
- **Backend / Supabase:** none
- **Known caveats:** Needs microphone and speech-recognition permissions; permissionDenied state; summarization depends on Apple Intelligence availability; not usable on simulator reliably.

### Instagram Stories sharing (outbound, not import)
- **Purpose:** Share a place/list card to Instagram Stories with a link sticker.
- **How to reach it:** Share flows (story card selectors in loc/Views/Sharing/).
- **Main views/files:** loc/Views/Sharing/StoryPhotoSelectorView.swift, PlaceStoryPhotoSelectorView.swift.
- **ViewModels/services:** loc/Services/InstagramStoriesService.swift (80 lines).
- **Accessibility identifiers:** none added
- **Backend / Supabase:** none
- **Known caveats:** Requires Instagram installed; hand-off via pasteboard/URL scheme (instagram-stories); not verified in detail. Info.plist LSApplicationQueriesSchemes includes tiktok.

#### Area notes: Gaps
- Could not locate what presents the MainView `.feed` sheet (PhotoFeedView) - no `present(.feed)` call found by grep.
- ImportProgressView private subviews (ImportSaveButton, ImportSaveSection search field, "Wrong?" menu, row toggles) and ImportPlaceConfirmationView buttons were not given IDs (non-trivial placement/risk).
- Backend routes /get-place-options and /process-selected-place exist but no iOS caller found; /auth/tiktok/* has no iOS caller either.
- Did not read ExternalPlaceSelectionView (288 lines) or ImportPlaceConfirmationView in detail; trigger conditions for noPlacesFound/externalPlaceSelection sheets unverified.
- Exact table/RPC use of RecentlyImportedViewModel beyond fetchUserExternalPlaces not traced.
- Instagram Stories entry point and exact URL scheme handling not verified.

#### Area notes: Unsure/skipped
- NearbyFilterButton (Create New List / Add to Existing toggle in GoogleMapsImportView) is a separate component, not edited.
- Existing-list picker rows (ForEach Button) skipped to avoid non-unique ids.
- MesaShare/ShareViewController.swift: no SwiftUI views; no IDs.

## Accessibility identifiers (table)

Every identifier added in the accessibility pass (ID -> file:line -> element). Lines drift as files change; grep for the ID. Count: 89 modifiers (88 unique IDs).

| ID | Location | Element | Feature |
|---|---|---|---|
| `auth.signInApple` | `loc/Views/LoginView.swift:119` | Continue with Apple button | login |
| `auth.signInGoogle` | `loc/Views/LoginView.swift:145` | Continue with Google button | login |
| `editProfile.firstName` | `loc/Views/MyProfileViews/EditProfileView.swift:130` | First name field | edit-profile |
| `editProfile.save` | `loc/Views/MyProfileViews/EditProfileView.swift:185` | Save button | edit-profile |
| `explore.city` | `loc/Views/Explore/ExploreCityCard.swift:33` | City tile button in Browse by city | explore-cities |
| `explore.featured` | `loc/Views/Explore/ExploreFeaturedCard.swift:55` | Featured list hero card button | explore-featured |
| `explore.featured.findTable` | `loc/Views/Explore/ExploreFeaturedCard.swift:102` | Featured card Find a table button | find-table |
| `explore.list` | `loc/Views/Explore/ExploreListCard.swift:27` | Public list card button (Popular near you and city grid) | explore-popular-lists |
| `explore.retry` | `loc/Views/Explore/ExploreTabView.swift:194` | Try again button after Explore load failure | explore-cities |
| `explore.shortcut` | `loc/Views/Explore/ExploreShortcutCard.swift:45` | Tonight / Fresh finds shortcut card (shared by both, same ID) | explore-shortcuts |
| `feedback.send` | `loc/Views/MyProfileViews/FeedbackSheet.swift:95` | Send button | feedback |
| `feedback.text` | `loc/Views/MyProfileViews/FeedbackSheet.swift:71` | Feedback text editor | feedback |
| `import.cancel` | `loc/Views/MyProfileViews/GoogleMapsImportView.swift:65` | Cancel/Skip toolbar button of Google Maps import sheet | google-maps-import |
| `import.googleMaps` | `loc/Views/SharedComponents/ListActionsMenu.swift:30` | Import from Google Maps menu item | profile-lists-menu |
| `import.googleMaps.create` | `loc/Views/MyProfileViews/GoogleMapsImportView.swift:473` | Create List / Add Places action button | google-maps-import |
| `import.googleMaps.done` | `loc/Views/MyProfileViews/GoogleMapsImportView.swift:544` | Done button on completed screen | google-maps-import |
| `import.googleMaps.listName` | `loc/Views/MyProfileViews/GoogleMapsImportView.swift:260` | New list name text field in preview step | google-maps-import |
| `import.googleMaps.retry` | `loc/Views/MyProfileViews/GoogleMapsImportView.swift:582` | Try Again button on failed screen | google-maps-import |
| `import.googleMaps.submit` | `loc/Views/MyProfileViews/GoogleMapsImportView.swift:114` | Extract Places button | google-maps-import |
| `import.googleMaps.url` | `loc/Views/MyProfileViews/GoogleMapsImportView.swift:99` | List URL text field | google-maps-import |
| `import.help.done` | `loc/Views/MyProfileViews/ImportHelpView.swift:33` | Done button of Import Content help sheet | import-help |
| `import.photos` | `loc/Views/MyProfileViews/ProfileQuickActionsRow.swift:44` | Import Photos quick action card on profile | profile-photo-import |
| `import.photos.cancel` | `loc/Views/PlaceReviews/Components/PhotoClusterOverviewView.swift:48` | Cancel in Review Places (multi-cluster photo import) | photo-import |
| `import.photos.tooltip.dismiss` | `loc/Views/MyProfileViews/PhotoImportTooltip.swift:49` | X button on photo-import coach mark | photo-import |
| `import.progress.done` | `loc/Views/PlaceDetailViews/ImportProgressView.swift:350` | Done button after auto-save banner | video-import |
| `import.progress.hide` | `loc/Views/PlaceDetailViews/ImportProgressView.swift:374` | Hide button while video import is running | video-import |
| `list.collaborators.search` | `loc/Views/Collaboration/ManageCollaboratorsSheet.swift:56` | Collaborator search field | list-collaborators |
| `list.edit.name` | `loc/Views/ListViews/EditListSheet.swift:31` | Edit list name field | list-edit |
| `list.edit.save` | `loc/Views/ListViews/EditListSheet.swift:59` | Edit list Save button | list-edit |
| `list.findTable` | `loc/Views/ListViews/FindTableButton.swift:30` | Find a table button in list header | find-table |
| `list.findTable.search` | `loc/Views/ListViews/FindTableSheet.swift:48` | Search button in Find a table form | find-table |
| `list.menu` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:361` | List overflow (ellipsis) menu | list-menu |
| `list.menu.addCollaborator` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:304` | Menu: Add Collaborator | list-menu |
| `list.menu.addPlace` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:297` | Menu: Add Place | list-menu |
| `list.menu.delete` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:344` | Menu: Delete List | list-menu |
| `list.menu.edit` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:330` | Menu: Edit List | list-menu |
| `list.menu.settings` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:337` | Menu: List Settings | list-menu |
| `list.menu.shareLink` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:313` | Menu: Share Link | list-menu |
| `list.menu.storyCard` | `loc/Views/MyProfileViews/LightweightListPopupView.swift:320` | Menu: Create Story Card | list-menu |
| `list.new.cancel` | `loc/Views/ListViews/NewListSheetView.swift:74` | New list Cancel button | list-create |
| `list.new.name` | `loc/Views/ListViews/NewListSheetView.swift:46` | New list name text field | list-create |
| `list.new.save` | `loc/Views/ListViews/NewListSheetView.swift:84` | New list Save button | list-create |
| `list.settings.private` | `loc/Views/ListViews/ListSettingsSheet.swift:81` | Private List toggle | list-settings |
| `list.settings.save` | `loc/Views/ListViews/ListSettingsSheet.swift:51` | List settings Save button | list-settings |
| `lists.menu.newList` | `loc/Views/SharedComponents/ListActionsMenu.swift:22` | New List menu item | profile-lists-menu |
| `lists.menu.newTrip` | `loc/Views/SharedComponents/ListActionsMenu.swift:26` | New Trip menu item | profile-lists-menu |
| `map.freshFinds` | `loc/Views/Map/MapTopBar.swift:25` | Fresh finds sparkles button | map |
| `map.layers` | `loc/Views/Map/MapBottomControls.swift:50` | Map layers menu (Everyone/Categories/My Places, Satellite) | map |
| `map.placesHere` | `loc/Views/MapView.swift:405` | Places here button (visible places popup) | map |
| `map.recenter` | `loc/Views/Map/MapBottomControls.swift:28` | Show my location button | map |
| `map.searchBar` | `loc/Views/Map/MapSearchBar.swift:35` | Search Mesa pill on the map | map |
| `onboarding.contacts.allow` | `loc/Views/Onboarding/ContactsConsentCard.swift:38` | Allow & Find Friends | onboarding-contacts |
| `onboarding.contacts.decline` | `loc/Views/Onboarding/ContactsConsentCard.swift:43` | Not Now | onboarding-contacts |
| `onboarding.continue` | `loc/Views/Onboarding/PhoneOnboardingView.swift:198` | Continue button (phone step) | onboarding-phone |
| `onboarding.continue` | `loc/Views/Onboarding/ProfilePhotoOnboardingView.swift:207` | Continue button (photo step) | onboarding-photo |
| `onboarding.phone` | `loc/Views/Onboarding/PhoneOnboardingView.swift:166` | Phone number field | onboarding-phone |
| `onboarding.photo.choose` | `loc/Views/Onboarding/ProfilePhotoOnboardingView.swift:183` | Choose/Change Photo button | onboarding-photo |
| `onboarding.suggested.done` | `loc/Views/Onboarding/SuggestedProfilesPopupView.swift:37` | Done button | onboarding-suggested |
| `place.detail.call` | `loc/Views/PlaceDetailViews/PlaceInfoSection.swift:168` | Call button | place-detail |
| `place.detail.createPlace` | `loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:178` | Create Place button (dropped pin) | place-detail |
| `place.detail.note` | `loc/Views/PlaceDetailViews/PlaceInfoSection.swift:190` | Private note button | place-detail |
| `place.detail.reserve` | `loc/Views/PlaceDetailViews/PlaceInfoSection.swift:123` | Reserve button | place-detail |
| `place.detail.save` | `loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:186` | Bookmark/save button | place-detail |
| `place.detail.share` | `loc/Views/PlaceDetailViews/PlaceDetailTabsView.swift:275` | Share button (non-custom places) | place-detail |
| `place.detail.writeReview` | `loc/Views/PlaceDetailViews/PlaceInfoSection.swift:179` | Write a Review button | place-detail |
| `place.detail.mediaStrip` | `loc/Views/PlaceDetailViews/PlaceMediaStripView.swift:63` | Horizontal photo + video strip | place-detail |
| `place.detail.mediaStrip.photo` | `loc/Views/PlaceDetailViews/PlaceMediaStripView.swift:97` | Photo / gallery-video tile in the strip | place-detail |
| `place.detail.mediaStrip.video` | `loc/Views/PlaceDetailViews/PlaceMediaStripView.swift:111` | External video tile (play badge) in the strip | place-detail |
| `place.detail.helpImproveDetection` | `loc/Views/PlaceDetailViews/PlaceFlaggingView.swift:43` | Help Improve Detection row | place-detail |
| `place.detail.posts` | `loc/Views/PlaceDetailViews/PlacePostsView.swift:30` | Reviews/posts section (only when posts exist) | place-detail |
| `post.create.cancel` | `loc/Views/PlaceReviews/CreatePostView.swift:74` | Create post Cancel | create-post |
| `post.create.share` | `loc/Views/PlaceReviews/CreatePostView.swift:85` | Create post Share | create-post |
| `post.create.text` | `loc/Views/PlaceReviews/CreatePostView.swift:355` | Post text editor | create-post |
| `profile.external.follow` | `loc/Views/ExternalProfileViews/ExternalUserProfileContentView.swift:85` | Follow/Following button on other user's profile | external-profile |
| `profile.lists.add` | `loc/Views/SharedComponents/ListActionsMenu.swift:43` | "+" Menu next to lists search bar | profile-lists-menu |
| `search.cancel` | `loc/Views/Search/SearchHeaderView.swift:93` | Search Cancel button | search |
| `search.field` | `loc/Views/Search/SearchHeaderView.swift:68` | Search text field | search |
| `settings.deleteAccount` | `loc/Views/MyProfileViews/AccountMenuView.swift:95` | Delete Account menu item | delete-account |
| `settings.editProfile` | `loc/Views/MyProfileViews/AccountMenuView.swift:65` | Edit Profile menu item | account-menu |
| `settings.feedback` | `loc/Views/MyProfileViews/AccountMenuView.swift:75` | Send Feedback menu item | account-menu |
| `settings.menu` | `loc/Views/MyProfileViews/AccountMenuView.swift:103` | Gear icon menu trigger | account-menu |
| `settings.signOut` | `loc/Views/MyProfileViews/AccountMenuView.swift:85` | Log Out menu item | account-menu |
| `tab.map` | `loc/Views/SharedComponents/AppTabBar.swift:38` | Map tab button (id built as tab.<lowercased title>; also tab.explore, tab.trips, tab.profile) | tab-bar |
| `tonight.askGroup` | `loc/Views/Tonight/TonightSheet.swift:212` | Ask the group button | tonight |
| `tonight.planLater` | `loc/Views/Tonight/TonightSheet.swift:189` | Plan for later button | tonight |
| `trip.close` | `loc/Views/Trips/TripsListView.swift:64` | Close button (only when list presented modally) | trips-list |
| `trip.create.cancel` | `loc/Views/Trips/CreateTripView.swift:48` | Cancel on name step of wizard | create-trip |
| `trip.create.name` | `loc/Views/Trips/TripNameStepView.swift:38` | Trip name text field | create-trip |
| `trip.create.next` | `loc/Views/Trips/TripNameStepView.swift:61` | Next button on name step | create-trip |
| `trip.menu` | `loc/Views/Trips/TripDetailView.swift:113` | Ellipsis menu in trip detail (Manage People/Delete) | trip-detail |
| `trips.create` | `loc/Views/Trips/TripsListView.swift:146` | Create Trip button in empty state | trips-list |
| `trips.new` | `loc/Views/Trips/NewTripTileView.swift:28` | "+" new trip tile atop list | trips-list |
| `trips.row` | `loc/Views/Trips/TripsListView.swift:180` | Trip card NavigationLink in trips list | trips-list |
| `update.open` | `loc/Services/AppUpdateGate.swift:92` | Update button on blocking screen | app-update-gate |


**Pre-assigned names that do not exist in the UI today:** `auth.signIn`, `auth.email`, `auth.password` (LoginView only offers Sign in with Apple and Google; `SupabaseAuthService` has email methods, but no view calls them). `import.photos` lives on the Profile "Import Photos" card, not in the "+" menu. `list.row` (profile/list tiles) has no ID yet: not added in this pass. If these screens appear later, use those names.

## Backend endpoint inventory

Source: `/workspace/Mesa-backend` blueprints, cross-checked against iOS callers in `loc/`. Most social, list, trip and profile features talk to **Supabase directly** (tables/RPCs), not to Mesa-backend.

### Mesa-backend endpoint inventory

Backend: /workspace/Mesa-backend (Flask). Base URL on iOS: `MesaBackendConfig.baseURL` (loc/Services/MesaBackendConfig.swift). All blueprints registered in app.py (lines 66-68, 160, 625-655); `tiktok_oembed_routes.py` registers `/tiktok/oembed` directly on the app. "iOS caller" = result of grepping loc/ for the path; "none" = no reference found in loc/, ShareExtension/, MesaShare/.

#### routes/google_maps_import.py (google_maps_import_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| POST | /maps/import-list | One-shot import of a shared Google Maps list URL; returns resolved places | loc/Services/GoogleMapsImportService.swift:20 |
| POST | /maps/extract-list | Phase 1: extract raw place names + coordinates from a list URL | loc/Services/GoogleMapsImportService.swift:53 |
| POST | /maps/resolve-place | Phase 2: resolve one extracted place via Google Places and ensure it exists in Supabase | loc/Services/GoogleMapsImportService.swift:84 |

#### routes/url_processing.py (url_processing_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| POST | /process-url | Process TikTok/Instagram/etc. URL into place(s); sync result or async import job | loc/Services/ExternalContentService.swift:37 (processURL), :139 (startImport; used by ImportProgressViewModel, ListOnboardingViewModel) |
| GET | /import-jobs/<job_id> | Poll status of an async import job (auth required, reads `import_jobs`) | loc/Services/ExternalContentService.swift:165 (fetchImportJob; ImportProgressViewModel, ImportTracker) |
| POST | /get-place-options | Return candidate places for a URL without saving, for user selection | none |
| POST | /process-selected-place | Process the place the user picked from get-place-options | none |
| GET | /process-url/platforms | List supported URL platforms | none |

#### routes/thumbnails.py (thumbnails_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| POST | /refresh-thumbnail | Re-fetch external content thumbnail and store in Supabase Storage | loc/Services/ExternalContentService.swift:257 (refreshTikTokThumbnail; ExternalVideoViewModel) |
| POST | /extract-thumbnail | Extract thumbnail URL without storage | none |

#### tiktok_oembed_routes.py (registered on app)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET, POST | /tiktok/oembed | oEmbed info for TikTok and Instagram URLs | loc/Services/ExternalContentService.swift:222 (getTikTokOEmbed; PlaceCorrectionViewModel, ExternalMetadataCache) |

#### routes/search.py (search_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET | / | API info root | none |
| GET | /search/suggestions | Autocomplete place suggestions (google/whoosh providers) | loc/Services/MesaBackendService.swift:377 (via PlaceSearchService.swift) |
| GET | /search/place-details | Full place details by place id/source | loc/Services/MesaBackendService.swift:299 (via PlaceRepository, MapViewportViewModel, PhotoImportViewModel, AddPlaceToTripViewModel, PlaceDetailTabsViewModel) |
| POST | /search/ai-suggestions | AI-ranked place suggestions near a location | loc/Services/MesaBackendService.swift:343 (via PlaceSearchService.swift) |
| POST | /search/refresh-review-images | Re-fetch stale (403) external review images for a place | loc/Services/MesaBackendService.swift:523 (ExternalReviewPhotosViewModel.swift:499) |

#### routes/nearby.py (nearby_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET | /nearby-places | Nearby places (local DB within 50m first, then Google Nearby Search); query latitude, longitude, radius | loc/Services/NearbyPlacesService.swift:13 (PhotoImportViewModel, PhotoClusteringViewModel) |

#### routes/place_insights.py (place_insights_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET | /places/<place_id>/insights | Place insights summary | loc/Services/PlaceInsightsService.swift:107 (PlaceInsightsViewModel) |

#### routes/reservations.py (reservations_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET | /places/<place_id>/reservation | Reservation provider/link for a place | loc/Services/MesaBackendService.swift:328 (ReservationViewModel) |

#### routes/availability.py (availability_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| POST | /lists/<list_id>/availability | "Find a table" availability across a list (Resy; 503 when disabled) | loc/Services/TableAvailabilityService.swift:44 (FindTableViewModel) |

#### routes/admin.py (admin_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET | /app/config | Public client config; `min_ios_version` drives forced-update gate | loc/Services/AppUpdateGate.swift:26 (locApp.swift) |
| GET | /health | Health check | none |
| POST | /admin/reindex | Reindex places from Supabase into Whoosh | none (admin) |
| GET | /admin/index-status | Whoosh index status | none (admin) |
| POST | /admin/refresh-index | Force refresh Whoosh index | none (admin) |

#### routes/tiktok_auth.py (tiktok_auth_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET | /auth/tiktok/login | Start TikTok OAuth (opened in Safari) | none found in loc/ |
| POST | /auth/tiktok/complete | Associate TikTok connection with Mesa user after OAuth | none found |
| GET | /auth/tiktok/web-login | Web variant of OAuth start | none |
| GET | /auth/tiktok/callback | OAuth redirect target | none (server-side) |
| GET | /auth/tiktok/status | TikTok connection/token status | none found |
| GET | /auth/tiktok/test-login | Test login helper | none |

#### routes/web_preview.py (web_preview_bp) - universal links / share pages
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET, OPTIONS | /serveWebPreview | Web preview page with meta tags | none |
| GET | /.well-known/apple-app-site-association | AASA for universal links | none (OS fetches); host in MesaBackendConfig.universalLinkHost |
| GET | /place/<place_id> | Shared place page | URLs built in loc/Services/PlaceShareService.swift:220, ViewModels/PlaceStoryCardViewModel.swift:219; parsed in locApp.swift |
| GET | /list/<list_id> | Shared list page | PlaceShareService.swift:255,271; ListStoryCardViewModel.swift:292 |
| GET | /profile/<user_id> | Shared profile page | PlaceShareService.swift:288 |
| GET | /pick/<pick_id> | Group pick ("where should we go") page | loc/Services/Tonight/GroupPickService.swift:143; locApp.swift:298 |
| GET | /pick/<pick_id>/og.jpg | Open Graph image for a pick | none (crawlers) |
Note: iOS also builds `/invite/<id>` links (loc/Services/TripInvitationService.swift:107); no matching route found in Mesa-backend blueprints.

#### routes/static_pages.py (static_pages_bp)
| Method | Path | Purpose | iOS caller |
|---|---|---|---|
| GET | /privacy-policy | Privacy policy page | none by path in loc/ (may be opened as external URL) |
| GET | /terms-of-service | Terms page | none by path |
| GET | /support | Support page | none by path |


## Gaps and known limits

- **Duplicate IDs in one hierarchy:** `onboarding.continue` (phone step and photo step, never on screen together); `explore.shortcut` (Tonight and Fresh finds cards share it; use labels); `profile.lists.add`, `lists.menu.*` and `import.googleMaps` come from the shared `ListActionsMenu`, which is also used by the full-screen lists cover, so two instances can exist while that cover is open.
- **Tab bar IDs are generated** as `"tab.\(title.lowercased())"` in `AppTabBar.swift` (constant titles Map/Explore/Trips/Profile give `tab.map`, `tab.explore`, `tab.trips`, `tab.profile`).
- **No email/password login**, so no `auth.signIn`/`auth.email`/`auth.password`. Apple/Google need real credentials and system sheets; signed-in flows cannot be automated until a `TEST_ACCOUNT` exists (see docs/AGENT_NOTES.md).
- **Delete account is a stub** (`UserService.deleteUserAccount` only logs; `SupabaseAuthService.deleteAccount` only signs out). App Store review risk.
- **Not found in UI:** a presenter of the `.feed` sheet (`PhotoFeedView`); call sites of `ListPurchaseSheet`, `PaidListTeaserOverlay`, `CreatorEarningsView` (paid lists look unwired); any list-reorder UI (only trip itineraries reorder); an in-app notifications list screen.
- **Not given IDs (unsure or shared code):** trip map/itinerary/collaborator sheets, followers/following rows, Manage People / Delete Trip menu items, list selection sheet rows, shared `FilterChip` (Explore city sort), ImportProgressView private subviews, ImportPlaceConfirmationView buttons, Fresh finds card buttons, system alert buttons (target by label), country-code menu.
- **Not traced in depth** (see each feature's notes): Explore people section data sources, Saved library entry point, ListStoryShareButton usage, GoogleMapView clustering internals, UserService.searchUsers backend, TripsInSelectionSheet entry from place detail, ExternalPlaceSelectionView, Instagram Stories entry point.
- Backend routes with no iOS caller: `/get-place-options`, `/process-selected-place`, `/process-url/platforms`, `/extract-thumbnail`, `/auth/tiktok/*`. iOS builds `/invite/<token>` links with no matching backend route.
- `ShareExtension/` holds only an entitlements file (the real extension is `MesaShare/`).

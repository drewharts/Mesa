# TikTok Travel Time Debugging

## Problem
Travel times aren't working when navigating to a place from the saved TikTok list under the "My Places" button.

## Debugging Changes Made

I've added comprehensive logging throughout the travel time calculation flow to identify where coordinates are getting lost or where the timing issue occurs.

### Files Modified

1. **SupabasePlaceService.swift** (line 1081)
   - Added logging when coordinates are parsed from database
   - Shows: `✅ [Supabase] Parsed coordinates for {place_name}: lat={lat}, lon={lon}`

2. **MyPlacesListView.swift** (lines 498-501)
   - Added logging in `loadPlaceAndNavigate()` to show if fetched place has coordinates
   - Shows: `🗺️ [LightweightPlaceGridCell] Fetched place '{name}' - Has coordinates: {true/false}`

3. **SelectedPlaceViewModel.swift** (lines 267-271, 284-288, 301)
   - Added logging when `selectPlaceAndFetchDetails()` is called
   - Shows coordinates from both Supabase fetch and backend fetch
   - Shows: `📍 [SelectedPlaceViewModel] selectPlaceAndFetchDetails called for '{name}'`

4. **TravelTimeViewModel.swift** (lines 46-52)
   - Added logging when travel time calculation fails due to missing coordinates
   - Added logging when calculation starts successfully
   - Shows: `⚠️ [TravelTimeViewModel] Cannot calculate travel time - place '{name}' has no coordinates`
   - Or: `🚗 [TravelTimeViewModel] Calculating travel time for '{name}'`

5. **PlaceDetailView.swift** (lines 72-91, 140-170)
   - Added logging for ViewModel creation timing
   - Added immediate travel time calculation after ViewModel is created
   - Added detailed logging for why travel time calculation might fail
   - Shows various states of `selectedPlace`, `currentLocation`, and `tabsViewModel`

## How to Test

1. **Run the app in Xcode** with the console visible
2. **Navigate to Profile** → My Places → TikTok tab
3. **Tap on a TikTok place**
4. **Watch the console logs** - you should see a sequence like:

```
✅ [Supabase] Parsed coordinates for {place}: lat={Y}, lon={X}
🗺️ [LightweightPlaceGridCell] Fetched place '{name}' - Has coordinates: true
   Coordinates: lat={Y}, lon={X}
📍 [SelectedPlaceViewModel] selectPlaceAndFetchDetails called for '{name}'
   Has coordinates: true
   Coordinates: lat={Y}, lon={X}
🔄 [SelectedPlaceViewModel] Setting selectedPlace (this will trigger PlaceDetailView.onChange)
🏗️ [PlaceDetailView] Creating tabsViewModel
   Calculating travel time immediately after ViewModel creation
🚗 [TravelTimeViewModel] Calculating travel time for '{name}' to coordinates: lat={Y}, lon={X}
```

## What to Look For

### If coordinates are missing from Supabase:
You'll see: `🔍 [Supabase] No location found for place: {name}`
- This means the database query returned a place without location data
- Check if the `location` column is NULL for TikTok places

### If coordinates are missing after fetch:
You'll see: `🗺️ [LightweightPlaceGridCell] Fetched place '{name}' - Has coordinates: false`
- This means `PlaceService.fetchPlace()` returned a place without coordinates
- The `convertToDetailPlace()` function failed to parse coordinates

### If travel time calculation is skipped:
You'll see: `⚠️ [TravelTimeViewModel] Cannot calculate travel time - place '{name}' has no coordinates`
- This confirms the place object has nil coordinates when reaching the ViewModel

### If tabsViewModel is nil:
You'll see: `⚠️ Cannot calculate travel time:` with `tabsViewModel: false`
- This is a timing issue where the ViewModel wasn't created yet

## Potential Issues Identified

### Timing Issue (Most Likely)
The travel time calculation in `PlaceDetailView` might be called before `tabsViewModel` is fully initialized. I've added an immediate calculation in the first `onAppear` (line 87) to handle this case.

### Coordinate Parsing Issue
If the `LocationData.coordinates` array from PostGIS is empty or malformed, coordinates won't be parsed. The logs will show this at the Supabase level.

### Backend Override
The backend fetch in `selectPlaceAndFetchDetails()` might return a place without coordinates that overwrites the Supabase place. The logs will show if backend coordinates are present or missing.

## Expected Fix

The most likely fix was adding the immediate travel time calculation at line 87 in PlaceDetailView:

```swift
// Calculate travel time now that ViewModel is created
if let place = selectedPlaceVM.selectedPlace,
   let currentLocation = locationManager.currentLocation {
    print("   Calculating travel time immediately after ViewModel creation")
    tabsViewModel?.travelTimeViewModel.updateTravelTime(for: place, from: currentLocation.coordinate)
}
```

This ensures travel time is calculated as soon as the ViewModel is ready, rather than relying on the second `onAppear` or `onChange` which might have timing issues.

## Next Steps

1. Test with a TikTok place and examine the console logs
2. Share the log output if travel times still aren't working
3. Based on the logs, we can pinpoint the exact issue:
   - Database coordinates missing
   - Parsing failure
   - Timing issue with ViewModel
   - Backend fetch issues

## Cleanup

Once the issue is resolved, you can optionally remove the debug print statements to clean up the console output. However, it's often useful to keep some of them for future debugging.


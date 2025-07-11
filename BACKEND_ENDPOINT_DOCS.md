# Backend Endpoint Documentation

## Process URL Endpoint

### Endpoint: `POST /process-url`

**Purpose**: Processes TikTok URLs to extract place information and optionally save the place to the database.

**Base URL**: `https://mesa-backend-production.up.railway.app`

**Full URL**: `https://mesa-backend-production.up.railway.app/process-url`

### Request

**Method**: POST

**Headers**:
- `Content-Type: application/json`
- `Authorization: Bearer <firebase-id-token>` (optional - if provided, enables place saving)

**Body**:
```json
{
  "url": "https://www.tiktok.com/@username/video/1234567890"
}
```

### Response

**Status**: 200 OK

**Response Body**:
```json
{
  "data": {
    "author": {
      "display_name": "Display Name",
      "url": "https://www.tiktok.com/@username",
      "username": "username"
    },
    "caption": "Video caption text",
    "embed_html": "<iframe src=\"...\"></iframe>",
    "hashtags": ["#food", "#restaurant", "#nyc"],
    "location": "Location mentioned in video",
    "thumbnail_url": "https://...",
    "title": "Video title",
    "url": "https://www.tiktok.com/@username/video/1234567890",
    "video_id": "1234567890"
  },
  "location_info": {
    "address_components": {
      "locality": "New York",
      "country": "US",
      "postal_code": "10001",
      "administrative_area_level_1": "NY"
    },
    "coordinates": [40.7128, -74.0060],
    "formatted_address": "123 Main St, New York, NY 10001",
    "location_name": "Restaurant Name",
    "place_id": "ChIJd8BlQ2BZwokRAFUEcm_qrcA",
    "raw_text": "Raw extracted text from video",
    "city": "New York",
    "state": "NY",
    "neighborhood": "Manhattan",
    "place_type": "restaurant",
    "extraction_method": "llm",
    "geocoding_source": "google_places",
    "llm_confidence": "high",
    "is_food_related": true
  },
  "processor_type": "tiktok",
  "processing_status": {
    "success": true,
    "location_found": true,
    "place_saved": true,
    "place_id": "uuid-string",
    "message": "Place successfully processed and saved"
  },
  "saved_place": {
    "id": "uuid-string",
    "name": "Restaurant Name",
    "address": "123 Main St, New York, NY 10001",
    "city": "New York",
    "coordinate": {
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    "categories": ["restaurant", "food"],
    "tiktok_videos": [
      {
        "id": "uuid-string",
        "video_id": "1234567890",
        "url": "https://www.tiktok.com/@username/video/1234567890",
        "title": "Video title",
        "caption": "Video caption text",
        "embed_html": "<iframe src=\"...\"></iframe>",
        "thumbnail_url": "https://...",
        "author": {
          "display_name": "Display Name",
          "url": "https://www.tiktok.com/@username",
          "username": "username"
        },
        "hashtags": ["#food", "#restaurant", "#nyc"],
        "created_at": "2025-07-10T12:00:00Z"
      }
    ]
  }
}
```

### Error Responses

**400 Bad Request**:
```json
{
  "error": "Invalid URL provided"
}
```

**401 Unauthorized**:
```json
{
  "error": "Authentication required to save place"
}
```

**500 Internal Server Error**:
```json
{
  "error": "Failed to process TikTok video"
}
```

### Implementation Notes

1. **Authentication**: Firebase ID token is optional. If provided, the endpoint will save the extracted place to the database.

2. **Place Extraction**: The endpoint uses multiple methods to extract place information:
   - LLM-based text extraction from video captions/descriptions
   - Google Places API for geocoding and place details
   - Pattern matching for common location formats

3. **Response Priority**: The client should prioritize data from `saved_place` over `location_info` when both are available.

4. **Coordinates Format**: Coordinates are returned as `[latitude, longitude]` array in `location_info` and as separate `latitude`/`longitude` fields in `saved_place`.

5. **TikTok Videos**: If a place is successfully saved, the `tiktok_videos` array contains the processed video information associated with that place.

### Client Implementation Example

The iOS client makes the request like this:

```swift
func processTikTokURL(_ url: String) async -> Result<TikTokProcessorResponse, Error> {
    guard let requestURL = URL(string: "https://mesa-backend-production.up.railway.app/process-url") else {
        return .failure(TikTokError.invalidURL)
    }
    
    var request = URLRequest(url: requestURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // Add Firebase auth token if available
    if let currentUser = Auth.auth().currentUser {
        do {
            let idToken = try await currentUser.getIDToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        } catch {
            // Continue without auth token
        }
    }
    
    // Set request body
    let requestBody = ["url": url]
    request.httpBody = try? JSONEncoder().encode(requestBody)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    let processorResponse = try JSONDecoder().decode(TikTokProcessorResponse.self, from: data)
    
    return .success(processorResponse)
}
```
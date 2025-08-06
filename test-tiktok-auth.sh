#!/bin/bash

# Test TikTok Authentication Endpoints
# Make sure to replace YOUR_FIREBASE_TOKEN with an actual token

BACKEND_URL="https://mesa-backend-production.up.railway.app"
FIREBASE_TOKEN="YOUR_FIREBASE_TOKEN"

echo "=== Testing TikTok Auth Endpoints ==="

# 1. Test Status Endpoint (should return connected: false initially)
echo -e "\n1. Testing /auth/tiktok/status"
curl -X GET "$BACKEND_URL/auth/tiktok/status" \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -H "Content-Type: application/json" \
  -v

# 2. Test Login Endpoint (should return redirect)
echo -e "\n\n2. Testing /auth/tiktok/login"
curl -X GET "$BACKEND_URL/auth/tiktok/login" \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -L -v

# 3. Test process-url endpoint (basic, no auth)
echo -e "\n\n3. Testing /process-url (basic)"
curl -X POST "$BACKEND_URL/process-url" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -d '{"url": "https://www.tiktok.com/@test/video/123456"}' \
  -v

# 4. Test process-url-with-auth endpoint (requires TikTok connection)
echo -e "\n\n4. Testing /process-url-with-auth"
curl -X POST "$BACKEND_URL/process-url-with-auth" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FIREBASE_TOKEN" \
  -d '{"url": "https://www.tiktok.com/@test/video/123456"}' \
  -v
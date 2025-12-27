# Push Notifications Setup Guide

This guide explains how to complete the push notification setup for the Loc app.

## ✅ What's Already Done

1. **iOS App Changes**
   - Device token storage in `locApp.swift`
   - Pending token handling in `UserSession.swift`
   - Token is stored in the `users.fcm_token` column when received

2. **Database Triggers**
   - `notify_on_follow` - Creates notification when user is followed
   - `notify_on_review` - Creates notification when review is posted on saved places
   - `trigger_send_push_notification` - Calls Edge Function when notification is created

3. **Supabase Edge Function**
   - `send-push-notification` - Deployed and ready to send APNs notifications

## 🔧 What You Need to Do

### Step 1: Get APNs Credentials from Apple

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click the **+** button to create a new key
3. Give it a name (e.g., "Loc Push Notifications")
4. Enable **Apple Push Notifications service (APNs)**
5. Click **Continue** and then **Register**
6. **Download the `.p8` file** (you can only download it once!)
7. Note the **Key ID** shown on the page
8. Find your **Team ID** in the top right corner of the Apple Developer portal

### Step 2: Set Environment Variables in Supabase

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/posfruqvibklcyfxmdbq
2. Navigate to **Project Settings** → **Edge Functions** → **Secrets**
3. Add the following secrets:

   - **APNS_KEY_ID**: Your APNs Key ID (from Step 1)
   - **APNS_TEAM_ID**: Your Apple Team ID (from Step 1)
   - **APNS_BUNDLE_ID**: `drewharts.locc` (your app's bundle ID)
   - **APNS_KEY**: The entire contents of your `.p8` file (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)
   - **APNS_PRODUCTION**: `false` for development/testing, `true` for production
   - **SUPABASE_URL**: `https://posfruqvibklcyfxmdbq.supabase.co` (already set by default)
   - **SUPABASE_SERVICE_ROLE_KEY**: Your service role key (get from Project Settings → API)

### Step 3: Test the Setup

1. **Test Device Token Storage**:
   - Run the app on a physical iOS device (push notifications don't work on simulator)
   - Grant notification permissions when prompted
   - Check the `users` table in Supabase - the `fcm_token` column should be populated

2. **Test Follow Notification**:
   - Have User A follow User B
   - User B should receive a push notification

3. **Test Review Notification**:
   - User A saves a place (adds to favorites or a list)
   - User B reviews that place
   - User A should receive a push notification

### Step 4: Monitor Edge Function Logs

1. Go to **Edge Functions** → **send-push-notification** → **Logs**
2. Check for any errors when notifications are created
3. Common issues:
   - Missing environment variables
   - Invalid APNs credentials
   - Device token not found

## 🔍 Troubleshooting

### No Push Notifications Received

1. **Check Device Token**:
   ```sql
   SELECT id, fcm_token FROM users WHERE id = 'your-user-id';
   ```
   - If `fcm_token` is NULL, the app didn't register properly
   - Make sure you're testing on a physical device, not simulator

2. **Check Edge Function Logs**:
   - Look for errors in the Supabase dashboard
   - Check if JWT generation is failing
   - Verify APNs credentials are correct

3. **Check APNs Response**:
   - The Edge Function logs will show APNs responses
   - Status 200 = success
   - Status 400/403 = authentication/credential issues
   - Status 410 = device token is invalid (user uninstalled app)

### Common Errors

- **"Missing APNs configuration"**: Environment variables not set correctly
- **"JWT generation failed"**: APNS_KEY format is wrong (should include BEGIN/END lines)
- **"No device token found"**: User hasn't granted notification permissions or token wasn't stored
- **"APNs request failed"**: Check APNs credentials and bundle ID

## 📱 Production Checklist

Before going to production:

- [ ] Set `APNS_PRODUCTION=true` in Edge Function secrets
- [ ] Test on TestFlight build (uses production APNs)
- [ ] Verify notifications work for all notification types:
  - [ ] Follow notifications
  - [ ] Review notifications (favorites)
  - [ ] Review notifications (place lists)
  - [ ] Comment notifications
  - [ ] Like notifications
- [ ] Monitor Edge Function logs for errors
- [ ] Set up error alerting if needed

## 🎯 How It Works

1. **User Action**: User follows someone or reviews a place
2. **Database Trigger**: `notify_on_follow` or `notify_on_review` creates a record in `user_notifications`
3. **Push Trigger**: `trigger_send_push_notification` fires and calls the Edge Function
4. **Edge Function**: `send-push-notification` function:
   - Fetches user's device token from `users.fcm_token`
   - Generates APNs JWT token
   - Sends push notification to Apple's APNs servers
5. **Device Receives**: iOS device receives and displays the notification

## 📚 Additional Resources

- [Apple Push Notification Service Documentation](https://developer.apple.com/documentation/usernotifications)
- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/sending_notification_requests_to_apns)


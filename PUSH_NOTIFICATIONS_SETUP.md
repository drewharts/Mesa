# Push Notifications Setup Guide

## Overview
I've implemented a complete push notification system for your Loc app that sends notifications to followers when users post reviews. Here's what was added:

## What's Been Implemented

### 1. **iOS App Changes**
- **ProfileData Model**: Added `fcmToken` field
- **AppDelegate**: Set up FCM registration, token handling, and notification permissions
- **UserSession**: Automatic FCM token registration on login
- **LoginViewModel**: FCM token inclusion for new users
- **FirestoreService**: Methods to save and retrieve FCM tokens
- **Array Extensions**: Helper for chunking arrays (needed for Firestore queries)

### 2. **Firebase Cloud Function**
- **notifyFriendsOnReview**: Triggers when a review is posted
- Uses your existing following system (followers/following collections)
- Sends push notifications to all followers' devices
- Stores in-app notifications for later viewing

## Setup Instructions

### Step 1: Deploy Firebase Cloud Functions

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Firebase Functions** in your project root:
   ```bash
   firebase login
   firebase init functions
   ```

3. **Copy the function files**:
   - Copy `firebase-functions/index.js` to your `functions/index.js`
   - Copy `firebase-functions/package.json` to your `functions/package.json`

4. **Deploy the functions**:
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

### Step 2: Enable Firebase Cloud Messaging

1. **In Firebase Console**:
   - Go to Project Settings
   - Navigate to Cloud Messaging tab
   - Generate/verify your iOS APNs certificates

2. **In Xcode**:
   - Enable Push Notifications capability
   - Add your APNs certificates

### Step 3: Use Your Existing Following System

The push notification system integrates seamlessly with your existing following system:

- **No changes needed** - your current follow/unfollow functionality works as-is
- **Followers automatically get notified** when someone they follow posts a review
- **Uses existing collections**: `followers` and `following`

### Step 4: Test the System

1. **Have users follow each other** using your existing follow functionality
2. **Post a review** from one user
3. **Check that followers receive push notifications**

## Handling Existing Users

### No Data Migration Required

**Good news!** You don't need to run any data migrations for existing users.

### How Existing Users Get FCM Tokens

1. **Automatic Registration**: When existing users open the app, they'll automatically register for FCM tokens
2. **On Login**: When users log in (or if they're already logged in), the app automatically calls `registerForFCMToken()`
3. **Gradual Rollout**: Users will get FCM tokens as they naturally use the app

### Transition Period Behavior

During the transition period:

**✅ What Works Immediately:**
- In-app notifications are created for all followers
- Users with FCM tokens receive push notifications
- New users automatically get FCM tokens

**⏳ What Happens Gradually:**
- Existing users get FCM tokens when they open the app
- More users receive push notifications over time
- No functionality is broken

### Monitoring the Transition

Check Firebase Functions logs to see the rollout:
```bash
firebase functions:log
```

You'll see logs like:
```
FCM Token Summary: 3 valid tokens, 2 users without tokens
Follower user123 has no FCM token (will get one on next login)
Successfully stored 5 in-app notifications
Push notification results: Success: 3, Failure: 0
```

### Accelerating FCM Token Registration (Optional)

If you want to speed up the process, you could:

1. **Send an app update announcement** encouraging users to open the app
2. **Add a one-time FCM refresh** to your data loading logic
3. **Show a subtle notification permission prompt** for users who haven't granted permissions

But this is **not necessary** - the system handles the transition gracefully.

## How It Works

### Data Flow
1. User posts a review → Firestore `reviews/{reviewId}` document created
2. Cloud Function `notifyFriendsOnReview` triggers
3. Function queries `followers` collection to find who follows the reviewer
4. Function gets FCM tokens for all followers
5. Push notifications sent to followers' devices
6. In-app notifications stored in `users/{followerId}/notifications`

### Firestore Structure
```
users/{userId} {
  fcmToken: "device_fcm_token", // Optional - added when user logs in
  // ... other profile data
}

followers/{documentId} {
  followerId: "userIdWhoFollows",
  followingId: "userIdBeingFollowed",
  followedAt: timestamp
}

following/{documentId} {
  followerId: "userIdWhoFollows", 
  followingId: "userIdBeingFollowed",
  followedAt: timestamp
}

users/{userId}/notifications/{notificationId} {
  type: "friend_review",
  fromUserId: "reviewerUserId",
  fromUserName: "Reviewer Name",
  reviewId: "reviewId",
  placeId: "placeId",
  timestamp: serverTimestamp,
  read: false
}
```

## Integration with Existing System

The push notification system leverages your existing architecture:

1. **Uses existing following relationships** - no need to manage separate friend lists
2. **Respects follow/unfollow actions** - notifications automatically stop when users unfollow
3. **No data duplication** - uses your existing `followers` and `following` collections

## Testing

1. **Test FCM Token Registration**:
   - Check Firestore to see if `fcmToken` is saved after login
   - Monitor console logs for FCM registration

2. **Test Notifications**:
   - Have users follow each other using your existing UI
   - Post a review and check if followers receive notifications
   - Check Firebase Functions logs for debugging

## Troubleshooting

### Common Issues:
1. **No notifications received**: Check FCM token registration and APNs setup
2. **Function not triggering**: Verify the review document path matches `reviews/{reviewId}`
3. **No followers**: Ensure users have followers in the existing following system
4. **Token errors**: Check that FCM tokens are being saved and retrieved correctly

### Debug Logs:
- iOS: Check Xcode console for FCM registration logs
- Cloud Functions: Use `firebase functions:log` to see function execution logs

## Security Considerations

1. **Validate follow relationships** before sending notifications
2. **Implement rate limiting** to prevent spam
3. **Add user blocking/muting** functionality
4. **Validate review data** in the Cloud Function

Your push notification system is now fully integrated with your existing following system! Users will receive notifications when people they follow post reviews, making your app more engaging and social. 
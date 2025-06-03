const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.notifyFriendsOnReview = onDocumentCreated('places/{placeId}/reviews/{reviewId}', async (event) => {
  const snap = event.data;
  const reviewId = event.params.reviewId;
  const placeId = event.params.placeId;
  
  if (!snap) {
    console.log('No data associated with the event');
    return;
  }
  
  const review = snap.data();
  const userId = review.userId;

  try {
    console.log(`Processing review notification for user: ${userId}, review: ${reviewId}, place: ${placeId}`);

    // Get the user's profile to fetch reviewer name
    const db = getFirestore();
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      return null;
    }

    const userData = userDoc.data();
    const reviewerName = userData.fullName || 'Your friend';

    // Get list of users who follow the reviewer (from followers collection)
    const followersSnapshot = await db
      .collection('followers')
      .where('followingId', '==', userId)
      .get();

    if (followersSnapshot.empty) {
      console.log(`User ${userId} has no followers to notify`);
      return null;
    }

    // Extract follower IDs
    const followerIds = followersSnapshot.docs.map(doc => doc.data().followerId);
    console.log(`Found ${followerIds.length} followers to notify`);

    // Batch fetch followers' FCM tokens (max 10 per query due to Firestore limitation)
    const followerChunks = [];
    for (let i = 0; i < followerIds.length; i += 10) {
      followerChunks.push(followerIds.slice(i, i + 10));
    }

    const tokens = [];
    let usersWithoutTokens = 0;
    
    for (const chunk of followerChunks) {
      // Query each follower document individually instead of using documentId 'in' query
      const followerPromises = chunk.map(followerId => 
        db.collection('users').doc(followerId).get()
      );
      const followerDocs = await Promise.all(followerPromises);
      
      followerDocs.forEach(doc => {
        if (doc.exists) {
          const data = doc.data();
          if (data.fcmToken && data.fcmToken.trim().length > 0) {
            tokens.push(data.fcmToken);
            console.log(`Added FCM token for follower: ${doc.id}`);
          } else {
            usersWithoutTokens++;
            console.log(`Follower ${doc.id} has no FCM token (will get one on next login)`);
          }
        }
      });
    }

    console.log(`FCM Token Summary: ${tokens.length} valid tokens, ${usersWithoutTokens} users without tokens`);

    if (tokens.length === 0) {
      console.log('No valid FCM tokens found for followers - all users need to log in to register tokens');
      // Still create in-app notifications even if no push notifications can be sent
    } else {
      console.log(`Sending push notifications to ${tokens.length} devices`);

      // Create the notification payload
      const payload = {
        notification: {
          title: 'New Review from Friend!',
          body: `${reviewerName} just reviewed a place. Check it out!`,
        },
        data: {
          reviewId: reviewId,
          placeId: placeId,
          userId: userId,
          type: 'friend_review'
        }
      };

      // Send the notifications
      const messaging = getMessaging();
      const response = await messaging.sendEachForMulticast({
        tokens: tokens,
        ...payload
      });
      
      console.log(`Push notification results: Success: ${response.successCount}, Failure: ${response.failureCount}`);
      
      // Log any failures for debugging
      if (response.failureCount > 0) {
        response.responses.forEach((result, index) => {
          if (!result.success) {
            console.error(`Failed to send to token ${tokens[index]}: ${result.error}`);
          }
        });
      }
    }

    // Always store in-app notifications for all followers (regardless of FCM token status)
    const batch = db.batch();
    followerIds.forEach(followerId => {
      const notificationRef = db
        .collection('users')
        .doc(followerId)
        .collection('notifications')
        .doc();
      
      batch.set(notificationRef, {
        type: 'friend_review',
        fromUserId: userId,
        fromUserName: reviewerName,
        reviewId: reviewId,
        placeId: placeId,
        timestamp: db.FieldValue.serverTimestamp(),
        read: false
      });
    });
    
    await batch.commit();
    console.log(`Successfully stored ${followerIds.length} in-app notifications`);

    return { success: true, pushNotificationsSent: tokens.length, inAppNotificationsStored: followerIds.length };
  } catch (error) {
    console.error('Error in notifyFriendsOnReview:', error);
    return null;
  }
}); 
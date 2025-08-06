const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { https } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const fs = require('fs');
const path = require('path');

initializeApp();

const db = getFirestore();

// Helper function to get a place's image
async function getPlaceImage(placeId) {
  try {
    // Validate input
    if (!placeId) {
      console.log('❌ Missing placeId for place image fetch');
      return null;
    }
    
    const placeDoc = await db.collection('places').doc(placeId).get();
    if (!placeDoc.exists) {
      console.log(`❌ Place document not found: ${placeId}`);
      return null;
    }
    
    const placeData = placeDoc.data();
    
    // Try to get the first photo URL from the place
    if (placeData.photoUrls && placeData.photoUrls.length > 0) {
      return placeData.photoUrls[0];
    }
    
    // Try to get TikTok video thumbnail
    if (placeData.tikTokVideos && placeData.tikTokVideos.length > 0) {
      const firstVideo = placeData.tikTokVideos[0];
      if (firstVideo.thumbnailUrl) {
        return firstVideo.thumbnailUrl;
      }
    }
    
    // Try to get image from the latest review
    const reviewsSnapshot = await db.collection('places').doc(placeId).collection('reviews')
      .orderBy('timestamp', 'desc')
      .limit(1)
      .get();
    
    if (!reviewsSnapshot.empty) {
      const reviewData = reviewsSnapshot.docs[0].data();
      if (reviewData.photoUrls && reviewData.photoUrls.length > 0) {
        return reviewData.photoUrls[0];
      }
    }
    
    return null;
  } catch (error) {
    console.error('Error fetching place image:', error);
    return null;
  }
}

// Helper function to get an image from a list's places
async function getListImage(listId, userId) {
  try {
    // Validate inputs
    if (!userId || !listId) {
      console.log('❌ Missing userId or listId for list image fetch');
      return null;
    }
    
    // Get the list's places
    const listDoc = await db.collection('users').doc(userId).collection('lists').doc(listId).get();
    if (!listDoc.exists) return null;
    
    const listData = listDoc.data();
    const placeIds = listData.placeIds || [];
    
    if (placeIds.length === 0) return null;
    
    // Try to get an image from the first few places in the list (limit to 3 for performance)
    const placesToCheck = placeIds.slice(0, 3);
    for (const placeId of placesToCheck) {
      const image = await getPlaceImage(placeId);
      if (image) return image;
    }
    
    return null;
  } catch (error) {
    console.error('Error fetching list image:', error);
    return null;
  }
}

// Serve web preview page for shared content
exports.serveWebPreview = https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  try {
    // Read the HTML template
    const htmlPath = path.join(__dirname, 'public', 'index.html');
    let html = fs.readFileSync(htmlPath, 'utf8');
    
    // Parse URL parameters
    const { type, id, name, address, city, userId } = req.query;
    
    // Generate dynamic meta tags based on content type
    let title = 'Mesa - Discover Amazing Places';
    let description = 'Join Mesa to discover and share the best places around you.';
    let image = 'https://mesa-backend-production.up.railway.app/static/images/mesa-logo.png';
    let url = req.url;
    
    if (type === 'place') {
      title = `${name || 'Amazing Place'} on Mesa`;
      description = address ? `${address}${city ? `, ${city}` : ''}` : 'Check out this place on Mesa!';
      
      // Try to get the place's actual image
      console.log(`🔍 Fetching image for place: ${id}`);
      const placeImage = await getPlaceImage(id);
      console.log(`📸 Place image result: ${placeImage ? 'Found' : 'Not found'}`);
      image = placeImage || 'https://mesa-backend-production.up.railway.app/static/images/mesa-logo.png';
      
    } else if (type === 'list') {
      title = `${name || 'Amazing List'} - Mesa List`;
      description = city ? `A curated list of places in ${city}` : 'A curated list of amazing places';
      
      // Try to get an image from the list's places
      console.log(`🔍 Fetching image for list: ${id}, userId: ${userId}`);
      const listImage = await getListImage(id, userId);
      console.log(`📸 List image result: ${listImage ? 'Found' : 'Not found'}`);
      image = listImage || 'https://mesa-backend-production.up.railway.app/static/images/mesa-logo.png';
    }
    
    // Add image parameter to URL for the web page
    const imageParam = image !== 'https://mesa-backend-production.up.railway.app/static/images/mesa-logo.png' ? 
      `&image=${encodeURIComponent(image)}` : '';
    
    // Replace meta tags in the HTML
    html = html.replace(/<meta property="og:title" content="[^"]*">/g, `<meta property="og:title" content="${title}">`);
    html = html.replace(/<meta property="og:description" content="[^"]*">/g, `<meta property="og:description" content="${description}">`);
    html = html.replace(/<meta property="og:image" content="[^"]*">/g, `<meta property="og:image" content="${image}">`);
    html = html.replace(/<meta property="og:url" content="[^"]*">/g, `<meta property="og:url" content="${url}">`);
    
    html = html.replace(/<meta name="twitter:title" content="[^"]*">/g, `<meta name="twitter:title" content="${title}">`);
    html = html.replace(/<meta name="twitter:description" content="[^"]*">/g, `<meta name="twitter:description" content="${description}">`);
    html = html.replace(/<meta name="twitter:image" content="[^"]*">/g, `<meta name="twitter:image" content="${image}">`);
    
    // Update the page title
    html = html.replace(/<title>[^<]*<\/title>/g, `<title>${title}</title>`);
    
    // Set content type and send response
    res.set('Content-Type', 'text/html');
    res.status(200).send(html);
    
  } catch (error) {
    console.error('Error serving web preview:', error);
    res.status(500).send('Error loading preview page');
  }
});

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
        timestamp: FieldValue.serverTimestamp(),
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

// Cloud Function to notify review author when someone comments on their review
exports.notifyReviewAuthorOnComment = onDocumentCreated('places/{placeId}/reviews/{reviewId}/comments/{commentId}', async (event) => {
  const snap = event.data;
  const { placeId, reviewId, commentId } = event.params;
  
  if (!snap) {
    console.log('No data associated with the event');
    return;
  }
  
  const commentData = snap.data();
  
  console.log(`💬 New comment detected on review ${reviewId} by user ${commentData.userId}`);
  
  try {
    // Get the original review to find its author
    const reviewRef = db.collection('places').doc(placeId).collection('reviews').doc(reviewId);
    const reviewDoc = await reviewRef.get();
    
    if (!reviewDoc.exists) {
      console.log('❌ Review not found');
      return null;
    }
    
    const reviewData = reviewDoc.data();
    const reviewAuthorId = reviewData.userId;
    
    // Don't notify if user is commenting on their own review
    if (commentData.userId === reviewAuthorId) {
      console.log('ℹ️ User commented on their own review, no notification needed');
      return null;
    }
    
    console.log(`📝 Comment by ${commentData.userFirstName} ${commentData.userLastName} on ${reviewData.userFirstName} ${reviewData.userLastName}'s review`);
    
    // Get the review author's FCM token
    const reviewAuthorRef = db.collection('users').doc(reviewAuthorId);
    const reviewAuthorDoc = await reviewAuthorRef.get();
    
    if (!reviewAuthorDoc.exists) {
      console.log(`❌ Review author ${reviewAuthorId} not found`);
      return null;
    }
    
    const reviewAuthorData = reviewAuthorDoc.data();
    const fcmToken = reviewAuthorData.fcmToken;
    
    if (!fcmToken || fcmToken.trim().length === 0) {
      console.log(`⚠️ Review author ${reviewAuthorId} has no FCM token`);
      // Still create in-app notification even without FCM token
    }
    
    // Get place name for the notification
    const placeRef = db.collection('places').doc(placeId);
    const placeDoc = await placeRef.get();
    const placeName = placeDoc.exists ? (placeDoc.data().name || 'a place') : 'a place';
    
    // Prepare notification data
    const notificationTitle = 'New Comment on Your Review!';
    const notificationBody = `${commentData.userFirstName} ${commentData.userLastName} commented on your review of ${placeName}`;
    
    // Send push notification if FCM token exists
    if (fcmToken && fcmToken.trim().length > 0) {
      const message = {
        token: fcmToken,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: 'comment',
          reviewId: reviewId,
          commentId: commentId,
          placeId: placeId,
          userId: commentData.userId, // The person who commented
          reviewAuthorId: reviewAuthorId // The person who wrote the review
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default'
            }
          }
        }
      };
      
      try {
        const messaging = getMessaging();
        const response = await messaging.send(message);
        console.log(`✅ Push notification sent successfully: ${response}`);
      } catch (error) {
        console.error(`❌ Error sending push notification: ${error}`);
        console.error(`❌ Error details - Code: ${error.code}, Message: ${error.message}`);
        console.error(`❌ FCM Token being used: ${fcmToken.substring(0, 20)}...`);
        console.error(`❌ Target user ID: ${reviewAuthorId}`);
        
        // Check if it's a token-related error
        if (error.code === 'messaging/registration-token-not-registered' || 
            error.code === 'messaging/invalid-registration-token') {
          console.error(`❌ Invalid or expired FCM token for user ${reviewAuthorId}, they may need to reopen the app`);
          
          // Optional: Clear the invalid token from Firestore
          await db.collection('users').doc(reviewAuthorId).update({
            fcmToken: null
          });
          console.log(`🧹 Cleared invalid FCM token for user ${reviewAuthorId}`);
        }
      }
    }
    
    // Create in-app notification for the review author
    const inAppNotification = {
      id: commentId, // Use comment ID as notification ID
      type: 'comment',
      title: notificationTitle,
      message: notificationBody,
      timestamp: FieldValue.serverTimestamp(),
      read: false,
      data: {
        reviewId: reviewId,
        commentId: commentId,
        placeId: placeId,
        placeName: placeName,
        commenterUserId: commentData.userId,
        commenterName: `${commentData.userFirstName} ${commentData.userLastName}`
      }
    };
    
    // Save in-app notification
    await db.collection('users')
            .doc(reviewAuthorId)
            .collection('notifications')
            .doc(commentId)
            .set(inAppNotification);
    
    console.log(`✅ In-app notification created for review author ${reviewAuthorId}`);
    console.log(`📊 Comment notification process completed successfully`);
    
    return { success: true, notificationType: 'comment', reviewAuthorId: reviewAuthorId };
    
  } catch (error) {
    console.error(`❌ Error in notifyReviewAuthorOnComment: ${error}`);
    return null;
  }
}); 
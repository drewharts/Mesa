import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import * as jose from 'https://deno.land/x/jose@v4.14.4/index.ts'

// APNs configuration from environment variables
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID') || 'drewharts.locc'
const APNS_KEY = Deno.env.get('APNS_KEY') // Your .p8 key content
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// Generate APNs JWT token
async function generateAPNsJWT(): Promise<string> {
  if (!APNS_KEY || !APNS_KEY_ID || !APNS_TEAM_ID) {
    throw new Error('Missing APNs configuration. Please set APNS_KEY_ID, APNS_TEAM_ID, and APNS_KEY environment variables.')
  }

  try {
    // Import the private key
    const key = await jose.importPKCS8(APNS_KEY, 'ES256')
    
    // Create and sign the JWT
    const jwt = await new jose.SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: APNS_KEY_ID })
      .setIssuedAt()
      .setIssuer(APNS_TEAM_ID)
      .setExpirationTime('1h')
      .sign(key)
    
    return jwt
  } catch (error) {
    console.error('❌ [Push] Error generating JWT:', error)
    throw new Error(`JWT generation failed: ${error.message}`)
  }
}

// Short label for a group pick push title, from the pick title the app stores (TonightVibe.headline).
function groupPickLabel(pickTitle?: string): string {
  const labels: Record<string, string> = {
    'Coffee right now': 'Coffee',
    'Lunch spots': 'Lunch',
    'Dinner tonight': 'Dinner',
    'Drinks tonight': 'Drinks',
    'Late night': 'Late night',
  }
  return (pickTitle && labels[pickTitle]) || pickTitle || 'Group pick'
}

serve(async (req) => {
  try {
    const { record } = await req.json()
    
    console.log('📬 [Push] Received notification:', JSON.stringify(record, null, 2))
    
    // Validate required fields
    if (!record.user_id || !record.type) {
      console.error('❌ [Push] Missing required fields:', { user_id: record.user_id, type: record.type })
      return new Response(
        JSON.stringify({ error: 'Missing required fields: user_id and type are required' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Get the user's device token - check both id and supabase_uid
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('fcm_token')
      .or(`id.eq.${record.user_id},supabase_uid.eq.${record.user_id}`)
      .single()
    
    if (userError) {
      console.error('❌ [Push] Error fetching user:', userError)
      return new Response(
        JSON.stringify({ error: 'User not found', details: userError.message }), 
        { status: 404, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    if (!user?.fcm_token) {
      console.log('⚠️ [Push] No device token for user:', record.user_id)
      return new Response(
        JSON.stringify({ error: 'No device token found for user' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Validate and clean device token
    let deviceToken = user.fcm_token.trim().replace(/\s+/g, '')
    
    // Validate token format (should be 64 hex characters)
    if (!/^[0-9a-fA-F]{64}$/.test(deviceToken)) {
      console.error('❌ [Push] Invalid device token format:', deviceToken.substring(0, 8) + '...')
      return new Response(
        JSON.stringify({ error: 'Invalid device token format' }), 
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Log masked token for debugging (first 8 and last 8 chars)
    const maskedToken = deviceToken.length > 16 
      ? `${deviceToken.substring(0, 8)}...${deviceToken.substring(deviceToken.length - 8)}`
      : '***'
    console.log('📱 [Push] Device token (masked):', maskedToken)
    
    // Build notification message based on type
    let title = ''
    let body = ''
    let notificationData: Record<string, any> = {
      type: record.type
    }
    
    switch (record.type) {
      case 'follow':
        title = 'New Follower'
        const followerName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        body = `${followerName} started following you`
        notificationData.userId = record.actor_id
        break
        
      case 'review':
        title = 'New Review'
        const reviewerName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        const placeName = record.place_name || 'a place'
        body = `${reviewerName} reviewed ${placeName}`
        notificationData.reviewId = record.review_id
        notificationData.placeId = record.place_id
        notificationData.userId = record.actor_id
        break
        
      case 'comment':
        title = 'New Comment'
        const commenterName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        body = `${commenterName} commented on your review`
        notificationData.commentId = record.comment_id
        notificationData.reviewId = record.review_id
        notificationData.placeId = record.place_id
        notificationData.userId = record.actor_id
        break

      case 'comment_reply':
        title = 'New Reply'
        const replierName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        body = `${replierName} replied to your comment`
        notificationData.commentId = record.comment_id
        notificationData.reviewId = record.review_id
        notificationData.placeId = record.place_id
        notificationData.userId = record.actor_id
        notificationData.type = 'comment_reply'
        break

      case 'like':
        title = 'New Like'
        const likerName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        body = `${likerName} liked your review`
        notificationData.reviewId = record.review_id
        notificationData.placeId = record.place_id
        notificationData.userId = record.actor_id
        break

      case 'place_added_to_list': {
        title = 'New Place Added'
        const adderName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        const addedPlaceName = record.place_name || 'a place'
        const listName = record.list_name || 'your list'
        body = `${adderName} added ${addedPlaceName} to ${listName}`
        notificationData.placeId = record.place_id
        notificationData.listId = record.list_id
        notificationData.userId = record.actor_id
        break
      }

      case 'trip_collaborator_added': {
        title = 'Trip Invitation'
        const inviterName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        const tripName = record.trip_name || 'a trip'
        body = `${inviterName} added you to ${tripName}`
        notificationData.tripId = record.trip_id
        notificationData.userId = record.actor_id
        break
      }

      case 'place_added_to_trip': {
        title = 'New Place Added'
        const tripAdderName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        const tripPlaceName = record.place_name || 'a place'
        const placeTripName = record.trip_name || 'a trip'
        body = `${tripAdderName} added ${tripPlaceName} to ${placeTripName}`
        notificationData.tripId = record.trip_id
        notificationData.placeId = record.place_id
        notificationData.userId = record.actor_id
        break
      }

      case 'trip_updated': {
        title = 'Trip Updated'
        const updaterName = record.actor_first_name && record.actor_last_name
          ? `${record.actor_first_name} ${record.actor_last_name}`
          : 'Someone'
        const updatedTripName = record.trip_name || 'a trip'
        body = `${updaterName} updated ${updatedTripName}`
        notificationData.tripId = record.trip_id
        notificationData.userId = record.actor_id
        break
      }

      case 'import_complete': {
        // Sent by Mesa-backend when a video import job finishes (the user may have left the app).
        const count = Number(record.place_count ?? 0)
        const importedName = record.place_name
        if (record.failed || count === 0) {
          title = "Couldn't find a place"
          body = 'We couldn\'t find a place in that video. Tap to add one yourself.'
        } else if (count === 1) {
          title = importedName ? `Found ${importedName}` : 'Found your place'
          body = 'Saved from your video. Tap to add it to a list.'
        } else {
          title = `Found ${count} places`
          body = importedName
            ? `${importedName} and ${count - 1} more from your video. Tap to review.`
            : 'Saved from your video. Tap to review.'
        }
        notificationData.jobId = record.job_id
        notificationData.placeId = record.place_id
        break
      }

      // ---- Tonight group picks (sent by the group-pick Postgres functions via pg_net) ----
      case 'group_pick_decided': {
        const label = groupPickLabel(record.pick_title)
        const winner = record.place_name
        if (record.mode === 'planned') {
          // Ranked (Borda) pick closed at its deadline or when everyone ranked.
          const top3 = Array.isArray(record.top3) ? record.top3 : []
          if (record.outcome === 'no_match' || !winner) {
            title = `${label}: voting closed`
            body = 'Nobody ranked a place. Tap to see the options.'
          } else {
            title = `${label}: ${winner} won`
            const medals = ['1st', '2nd', '3rd']
            body = top3.length > 1
              ? top3.map((t: any, i: number) => `${medals[i]} ${t.name ?? 'Unnamed place'} (${t.points})`).join(' · ')
              : `${Number(record.yes_count ?? 0)} of ${Number(record.member_count ?? 0)} voted. Tap for details.`
          }
        } else if (record.outcome === 'no_match' || !winner) {
          title = `${label}: no match`
          body = 'Nobody liked the picks. Tap to add more options.'
        } else {
          title = `${label}: ${winner} won`
          const yes = Number(record.yes_count ?? 0)
          const total = Number(record.member_count ?? 0)
          body = record.outcome === 'tie_break'
            ? 'It was a tie, so we went with the best-ranked pick. Tap for details.'
            : total > 1 && yes > 0
              ? `${yes} of ${total} said yes. Tap for directions.`
              : 'Tap for directions.'
        }
        notificationData.pickId = record.pick_id
        notificationData.deepLink = `loc://pick/${record.pick_id}`
        notificationData.placeId = record.place_id
        break
      }

      case 'group_pick_invited': {
        const inviter = record.actor_first_name || 'Someone'
        title = `${groupPickLabel(record.pick_title)}: you're in`
        body = `${inviter} wants your vote on where to go. Tap to vote.`
        notificationData.pickId = record.pick_id
        notificationData.deepLink = `loc://pick/${record.pick_id}`
        break
      }

      case 'group_pick_waiting': {
        title = `${groupPickLabel(record.pick_title)}: waiting on you`
        body = 'Everyone else has voted. Tap to pick so we can decide.'
        notificationData.pickId = record.pick_id
        notificationData.deepLink = `loc://pick/${record.pick_id}`
        break
      }

      case 'group_pick_options': {
        const adder = record.actor_first_name || 'Someone'
        const added = Number(record.added_count ?? 1)
        title = `${groupPickLabel(record.pick_title)}: new option${added === 1 ? '' : 's'}`
        body = `${adder} added ${added === 1 ? 'a place' : `${added} places`} to the vote. Tap to vote.`
        notificationData.pickId = record.pick_id
        notificationData.deepLink = `loc://pick/${record.pick_id}`
        break
      }

      default:
        console.log('⚠️ [Push] Unknown notification type:', record.type)
        return new Response(
          JSON.stringify({ error: 'Unknown notification type', type: record.type }), 
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
    }
    
    // Generate APNs JWT
    let jwt: string
    try {
      jwt = await generateAPNsJWT()
    } catch (error) {
      console.error('❌ [Push] Error generating JWT:', error)
      return new Response(
        JSON.stringify({ error: 'JWT generation failed', details: error.message }), 
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    // Determine APNs endpoint (production or sandbox)
    // Use sandbox for development, production for App Store builds
    const isProduction = Deno.env.get('APNS_PRODUCTION') === 'true'
    const apnsHost = isProduction 
      ? 'api.push.apple.com' 
      : 'api.sandbox.push.apple.com'
    
    const apnsUrl = `https://${apnsHost}/3/device/${deviceToken}`
    
    // Build APNs payload
    const apnsPayload = {
      aps: {
        alert: {
          title: title,
          body: body
        },
        sound: 'default',
        badge: 1,
        'content-available': 1
      },
      ...notificationData
    }
    
    console.log('📤 [Push] Sending to APNs:', apnsHost)
    console.log('📤 [Push] Payload:', JSON.stringify(apnsPayload, null, 2))
    
    // Send to APNs
    const apnsResponse = await fetch(apnsUrl, {
      method: 'POST',
      headers: {
        'authorization': `bearer ${jwt}`,
        'apns-topic': APNS_BUNDLE_ID,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': '0',
        'content-type': 'application/json'
      },
      body: JSON.stringify(apnsPayload)
    })
    
    if (!apnsResponse.ok) {
      const errorText = await apnsResponse.text()
      console.error('❌ [Push] APNs error:', apnsResponse.status, errorText)
      
      return new Response(
        JSON.stringify({ 
          error: 'APNs request failed', 
          status: apnsResponse.status,
          details: errorText 
        }), 
        { status: apnsResponse.status, headers: { 'Content-Type': 'application/json' } }
      )
    }
    
    const apnsResponseData = await apnsResponse.text()
    console.log('✅ [Push] Notification sent successfully. APNs response:', apnsResponseData)
    
    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Notification sent',
        apnsResponse: apnsResponseData
      }), 
      { 
        status: 200, 
        headers: { 'Content-Type': 'application/json' } 
      }
    )
  } catch (error) {
    console.error('❌ [Push] Unexpected error:', error)
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        message: error.message,
        stack: error.stack 
      }), 
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})


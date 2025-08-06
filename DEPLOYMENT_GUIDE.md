# Mesa Web Preview Deployment Guide

## Overview
This guide will help you deploy the web preview feature that creates beautiful external links with Mesa's logo when sharing places and lists.

## What We've Built

### 1. iOS App Changes ✅
- Updated `PlaceShareService.swift` to generate web URLs
- Now shares both web URLs (for rich previews) and deep links (for app navigation)
- Maintains backward compatibility with existing sharing

### 2. Web Preview Page ✅
- Created `functions/public/index.html` with responsive design
- Includes Open Graph and Twitter Card meta tags
- Dynamic content based on shared place/list

### 3. Firebase Cloud Function ✅
- Added `serveWebPreview` function to `functions/index.js`
- Serves the web page with dynamic meta tags
- Handles CORS and proper content types

## Deployment Steps

### Step 1: Deploy Firebase Cloud Functions

1. **Navigate to functions directory:**
   ```bash
   cd functions
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Deploy the functions:**
   ```bash
   npm run deploy
   ```

4. **Verify deployment:**
   ```bash
   firebase functions:log
   ```

### Step 2: Add Backend Endpoint (Alternative to Firebase Functions)

If you prefer to use your existing backend instead of Firebase Functions:

1. **Add the endpoint to your backend** using the code from `WEB_PREVIEW_ENDPOINT.md`
2. **Update the iOS app** to use your backend URL instead of Firebase Functions
3. **Test the endpoint** with the provided test URLs

### Step 3: Create and Upload Images

1. **Generate the required images** (see `generate-preview-images.md`):
   - `mesa-logo.png` (80x80px)
   - `mesa-logo-og.png` (1200x630px)
   - `place-preview.png` (1200x630px)
   - `list-preview.png` (1200x630px)

2. **Upload to your backend** at:
   ```
   https://mesa-backend-production.up.railway.app/images/
   ```

### Step 4: Update App Store ID

1. **Find your App Store ID** in App Store Connect
2. **Update the HTML template** in `functions/public/index.html`:
   ```html
   <meta name="apple-itunes-app" content="app-id=YOUR_ACTUAL_APP_ID">
   ```
3. **Update the download button**:
   ```html
   <a href="https://apps.apple.com/app/mesa/id/YOUR_ACTUAL_APP_ID" class="download-btn">
   ```

### Step 5: Test the Implementation

1. **Test web preview URLs:**
   ```bash
   # Place preview
   curl "https://mesa-backend-production.up.railway.app/serveWebPreview?type=place&id=123&name=Test%20Restaurant&city=New%20York"
   
   # List preview
   curl "https://mesa-backend-production.up.railway.app/serveWebPreview?type=list&id=456&name=Best%20Places&city=San%20Francisco"
   ```

2. **Test social media previews:**
   - Facebook: https://developers.facebook.com/tools/debug/
   - Twitter: https://cards-dev.twitter.com/validator
   - LinkedIn: https://www.linkedin.com/post-inspector/

3. **Test in iOS app:**
   - Share a place and verify both URLs are generated
   - Share a list and verify both URLs are generated
   - Test deep link functionality still works

## Configuration Options

### Customize the Design

You can customize the web preview page by editing `functions/public/index.html`:

1. **Colors**: Update the CSS gradient colors
2. **Logo**: Replace the logo image
3. **Typography**: Modify font sizes and styles
4. **Layout**: Adjust spacing and positioning

### Customize Meta Tags

The meta tags are dynamically generated based on content type:

- **Places**: Show place name, address, and city
- **Lists**: Show list name, city, and creator
- **Default**: Show generic Mesa branding

### Add Analytics

You can add analytics to track web preview usage:

```javascript
// Add to the HTML template
<script>
  // Google Analytics
  gtag('config', 'GA_MEASUREMENT_ID', {
    page_title: document.title,
    page_location: window.location.href
  });
  
  // Custom tracking
  gtag('event', 'web_preview_view', {
    content_type: '${type}',
    content_id: '${id}'
  });
</script>
```

## Troubleshooting

### Common Issues

1. **Images not loading:**
   - Verify image URLs are accessible
   - Check CORS headers on your backend
   - Ensure images are in the correct format

2. **Meta tags not updating:**
   - Check URL parameters are being passed correctly
   - Verify the HTML template is being served
   - Test with social media debugging tools

3. **Deep links not working:**
   - Verify the `loc://` URL scheme is still configured
   - Test deep link parsing in the app
   - Check that both URLs are being shared

### Debug Commands

```bash
# Test Firebase Function
firebase functions:log --only serveWebPreview

# Test image accessibility
curl -I https://mesa-backend-production.up.railway.app/images/mesa-logo.png

# Test web preview
curl -v https://mesa-backend-production.up.railway.app/serveWebPreview?type=place&id=test

# Test deep link
xcrun simctl openurl booted "loc://place/test?name=Test%20Place"
```

## Performance Optimization

### Caching

Add caching headers to improve performance:

```javascript
// In the Firebase Function
res.set('Cache-Control', 'public, max-age=3600'); // Cache for 1 hour
res.set('ETag', `"${contentHash}"`); // Add ETag for conditional requests
```

### Image Optimization

1. **Compress images** using tools like TinyPNG
2. **Use WebP format** for better compression
3. **Implement lazy loading** for better performance

### CDN

Consider using a CDN for faster image delivery:

```javascript
// Update image URLs to use CDN
const imageUrl = `https://your-cdn.com/images/${imageName}`;
```

## Monitoring

### Set up monitoring for:

1. **Web preview page views**
2. **Image loading success rates**
3. **Deep link conversion rates**
4. **Social media share analytics**

### Example monitoring queries:

```javascript
// Track web preview usage
analytics.track('Web Preview Viewed', {
  contentType: type,
  contentId: id,
  userAgent: req.headers['user-agent']
});

// Track deep link conversions
analytics.track('Deep Link Opened', {
  source: 'web_preview',
  contentType: type,
  contentId: id
});
```

## Success Metrics

Track these metrics to measure success:

1. **Web preview page views**
2. **Social media share engagement**
3. **App downloads from web previews**
4. **Deep link conversion rates**
5. **User retention from shared content**

## Next Steps

After deployment, consider these enhancements:

1. **Dynamic images** based on place type
2. **User-generated content** in previews
3. **A/B testing** different preview designs
4. **Analytics dashboard** for sharing metrics
5. **Custom domains** for better branding 
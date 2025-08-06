# Web Preview Endpoint for Mesa

## Overview
This endpoint serves beautiful web pages with rich previews when users share places or lists from Mesa. It includes Open Graph and Twitter Card meta tags for beautiful social media previews.

## Endpoint: `GET /serveWebPreview`

### Purpose
Serves a responsive web page that displays rich previews of shared Mesa content (places and lists) with proper meta tags for social media platforms.

### URL Format
```
https://mesa-backend-production.up.railway.app/serveWebPreview?type=place&id=123&name=Restaurant%20Name&address=123%20Main%20St&city=New%20York
```

### Query Parameters

#### For Places:
- `type` (required): Must be "place"
- `id` (required): Place ID
- `name` (required): Place name
- `address` (optional): Place address
- `city` (optional): Place city

#### For Lists:
- `type` (required): Must be "list"
- `id` (required): List ID
- `name` (required): List name
- `city` (optional): List city
- `userId` (optional): User ID who created the list

### Response
Returns an HTML page with:
- Responsive design with Mesa branding
- Dynamic meta tags based on content type
- Open Graph meta tags for Facebook, WhatsApp, etc.
- Twitter Card meta tags for Twitter
- App Store download link
- Beautiful UI with Mesa logo and gradient background

### Example Implementation (Node.js/Express)

```javascript
const express = require('express');
const path = require('path');
const fs = require('fs');

app.get('/serveWebPreview', (req, res) => {
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
    let image = 'https://mesa-backend-production.up.railway.app/images/mesa-logo-og.png';
    let url = req.url;
    
    if (type === 'place') {
      title = `${name || 'Amazing Place'} on Mesa`;
      description = address ? `${address}${city ? `, ${city}` : ''}` : 'Check out this place on Mesa!';
      image = 'https://mesa-backend-production.up.railway.app/images/place-preview.png';
    } else if (type === 'list') {
      title = `${name || 'Amazing List'} - Mesa List`;
      description = city ? `A curated list of places in ${city}` : 'A curated list of amazing places';
      image = 'https://mesa-backend-production.up.railway.app/images/list-preview.png';
    }
    
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
```

### Required Assets

You'll need to add these images to your backend's public assets:

1. **Mesa Logo**: `https://mesa-backend-production.up.railway.app/images/mesa-logo.png`
   - Size: 80x80px
   - Format: PNG with transparency

2. **Open Graph Logo**: `https://mesa-backend-production.up.railway.app/images/mesa-logo-og.png`
   - Size: 1200x630px (Facebook recommended)
   - Format: PNG or JPG

3. **Place Preview Image**: `https://mesa-backend-production.up.railway.app/images/place-preview.png`
   - Size: 1200x630px
   - Format: PNG or JPG
   - Generic place/restaurant image

4. **List Preview Image**: `https://mesa-backend-production.up.railway.app/images/list-preview.png`
   - Size: 1200x630px
   - Format: PNG or JPG
   - Generic list/collection image

### Testing

Test the endpoint with these URLs:

**Place Preview:**
```
https://mesa-backend-production.up.railway.app/serveWebPreview?type=place&id=123&name=Central%20Park%20Cafe&address=123%20Main%20St&city=New%20York
```

**List Preview:**
```
https://mesa-backend-production.up.railway.app/serveWebPreview?type=list&id=456&name=Best%20Coffee%20Shops&city=San%20Francisco&userId=user123
```

### Social Media Testing

Use these tools to test how your previews look on social media:

- **Facebook**: https://developers.facebook.com/tools/debug/
- **Twitter**: https://cards-dev.twitter.com/validator
- **LinkedIn**: https://www.linkedin.com/post-inspector/
- **WhatsApp**: Share the URL in a WhatsApp chat

### Integration with iOS App

The iOS app now generates both web URLs and deep links when sharing:

1. **Web URL**: For rich previews on social media
2. **Deep Link**: For direct app navigation when clicked

This provides the best of both worlds - beautiful previews for social sharing and seamless app navigation for users who have Mesa installed. 
# Generating Preview Images for Mesa Web Sharing

## Required Images

You need to create and upload these images to your backend at `https://mesa-backend-production.up.railway.app/images/`:

### 1. Mesa Logo (`mesa-logo.png`)
- **Size**: 80x80px
- **Format**: PNG with transparency
- **Purpose**: Used in the web preview page
- **Source**: Extract from your app's Assets.xcassets

### 2. Open Graph Logo (`mesa-logo-og.png`)
- **Size**: 1200x630px (Facebook recommended)
- **Format**: PNG or JPG
- **Purpose**: Default social media preview image
- **Design**: Mesa logo on a gradient background matching your app's colors

### 3. Place Preview Image (`place-preview.png`)
- **Size**: 1200x630px
- **Format**: PNG or JPG
- **Purpose**: Generic preview for shared places
- **Design**: Restaurant/cafe scene with Mesa branding

### 4. List Preview Image (`list-preview.png`)
- **Size**: 1200x630px
- **Format**: PNG or JPG
- **Purpose**: Generic preview for shared lists
- **Design**: Collection of places with Mesa branding

## Quick Image Generation

### Option 1: Use Your Existing App Icon
1. Extract your app icon from `loc/Assets.xcassets/AppIcon.appiconset/1024x1024mesalogo.png`
2. Resize to 80x80px for `mesa-logo.png`
3. Create a 1200x630px version with background for `mesa-logo-og.png`

### Option 2: Use Online Tools
- **Canva**: Create social media templates
- **Figma**: Design custom previews
- **Photoshop**: Professional image editing

### Option 3: Use AI Image Generation
- **Midjourney**: Generate restaurant/cafe scenes
- **DALL-E**: Create place and list previews
- **Stable Diffusion**: Custom image generation

## Example Design Specifications

### Mesa Logo (80x80px)
```
Background: Transparent
Logo: Your existing Mesa logo
Style: Clean, minimal
```

### Open Graph Logo (1200x630px)
```
Background: Linear gradient (#667eea to #764ba2)
Logo: Centered, 200x200px
Text: "Mesa" below logo
Style: Modern, app-like
```

### Place Preview (1200x630px)
```
Background: Restaurant/cafe scene (blurred)
Overlay: Semi-transparent dark overlay
Logo: Top-left corner, 100x100px
Text: "Discover Amazing Places"
Style: Food/restaurant focused
```

### List Preview (1200x630px)
```
Background: Collection of place photos (grid)
Overlay: Semi-transparent dark overlay
Logo: Top-left corner, 100x100px
Text: "Curated Lists"
Style: Collection/grid focused
```

## Upload Instructions

1. **Create the images** using your preferred method
2. **Upload to your backend** at the specified paths:
   - `/images/mesa-logo.png`
   - `/images/mesa-logo-og.png`
   - `/images/place-preview.png`
   - `/images/list-preview.png`
3. **Test the URLs** to ensure they're accessible
4. **Verify social media previews** using the testing tools

## Testing Your Images

After uploading, test with these URLs:

```bash
# Test image accessibility
curl -I https://mesa-backend-production.up.railway.app/images/mesa-logo.png
curl -I https://mesa-backend-production.up.railway.app/images/mesa-logo-og.png
curl -I https://mesa-backend-production.up.railway.app/images/place-preview.png
curl -I https://mesa-backend-production.up.railway.app/images/list-preview.png

# Test web preview
curl https://mesa-backend-production.up.railway.app/serveWebPreview?type=place&id=123&name=Test%20Restaurant&city=New%20York
```

## Social Media Testing

Use these tools to verify your previews work correctly:

- **Facebook**: https://developers.facebook.com/tools/debug/
- **Twitter**: https://cards-dev.twitter.com/validator
- **LinkedIn**: https://www.linkedin.com/post-inspector/
- **WhatsApp**: Share the URL in a WhatsApp chat

## Quick Start with Existing Assets

If you want to get started quickly:

1. **Extract your app icon** from the Xcode project
2. **Create a simple gradient background** with your app colors
3. **Place the logo on the background** for the Open Graph image
4. **Use stock photos** for place and list previews
5. **Upload and test** the basic setup

You can always improve the images later with more professional designs! 
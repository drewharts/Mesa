"""
Universal Links Support for Mesa
================================

Add these endpoints to your FastAPI backend on Railway.

This enables:
1. Rich link previews in iMessage/WhatsApp (Open Graph meta tags)
2. Direct app opening when links are tapped (Universal Links)
3. Fallback web page for users without the app
"""

from fastapi import FastAPI, Request, Query
from fastapi.responses import HTMLResponse, JSONResponse
from typing import Optional

# Add this to your existing FastAPI app
# If you have a separate router, you can add these to a router instead

app = FastAPI()  # Or use your existing app instance


# =============================================================================
# 1. Apple App Site Association (AASA) File
# =============================================================================
# This MUST be served at /.well-known/apple-app-site-association
# Apple fetches this to verify your app can handle Universal Links

@app.get("/.well-known/apple-app-site-association")
async def apple_app_site_association():
    """
    Serves the Apple App Site Association file for Universal Links.
    Apple requires this to be served with Content-Type: application/json
    """
    aasa = {
        "applinks": {
            "apps": [],
            "details": [
                {
                    "appID": "585YK2F2H6.drewharts.locc",
                    "paths": ["/place/*", "/list/*"]
                }
            ]
        },
        "webcredentials": {
            "apps": ["585YK2F2H6.drewharts.locc"]
        }
    }
    return JSONResponse(
        content=aasa,
        headers={"Content-Type": "application/json"}
    )


# =============================================================================
# 2. Place Universal Link Page
# =============================================================================

@app.get("/place/{place_id}", response_class=HTMLResponse)
async def place_universal_link(
    request: Request,
    place_id: str,
    name: Optional[str] = Query(None),
    address: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    mapboxId: Optional[str] = Query(None),
    lat: Optional[str] = Query(None),
    lng: Optional[str] = Query(None),
):
    """
    Universal Link page for places.
    
    When shared in iMessage:
    - Shows rich preview with title, description, and image
    
    When tapped:
    - If Mesa is installed: Opens directly in the app
    - If not installed: Shows this webpage with download link
    """
    
    # Build the deep link URL for the app
    deep_link = f"loc://place/{place_id}?"
    params = []
    if name:
        params.append(f"name={name}")
    if address:
        params.append(f"address={address}")
    if city:
        params.append(f"city={city}")
    if mapboxId:
        params.append(f"mapboxId={mapboxId}")
    if lat:
        params.append(f"lat={lat}")
    if lng:
        params.append(f"lng={lng}")
    deep_link += "&".join(params)
    
    # Page metadata
    title = f"{name or 'Amazing Place'} on Mesa"
    description = address if address else "Check out this place on Mesa!"
    if city and address:
        description = f"{address}, {city}"
    
    # TODO: Fetch actual place image from your database
    # For now, using Mesa logo as fallback
    image_url = "https://mesa-backend-staging.up.railway.app/static/images/mesa-logo.png"
    
    # Optional: Fetch place from Supabase to get image
    # try:
    #     place = await supabase.table("places").select("photo_urls").eq("id", place_id).single().execute()
    #     if place.data and place.data.get("photo_urls"):
    #         image_url = place.data["photo_urls"][0]
    # except:
    #     pass
    
    html = generate_universal_link_html(
        title=title,
        description=description,
        image_url=image_url,
        deep_link=deep_link,
        content_type="place",
        content_name=name or "Amazing Place"
    )
    
    return HTMLResponse(content=html)


# =============================================================================
# 3. List Universal Link Page
# =============================================================================

@app.get("/list/{list_id}", response_class=HTMLResponse)
async def list_universal_link(
    request: Request,
    list_id: str,
    name: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    userId: Optional[str] = Query(None),
):
    """
    Universal Link page for lists.
    """
    
    # Build the deep link URL for the app
    deep_link = f"loc://list/{list_id}?"
    params = []
    if name:
        params.append(f"name={name}")
    if city:
        params.append(f"city={city}")
    if userId:
        params.append(f"userId={userId}")
    deep_link += "&".join(params)
    
    # Page metadata
    title = f"{name or 'Amazing List'} - Mesa List"
    description = f"A curated list of places in {city}" if city else "A curated list of amazing places"
    
    # Default image
    image_url = "https://mesa-backend-staging.up.railway.app/static/images/mesa-logo.png"
    
    html = generate_universal_link_html(
        title=title,
        description=description,
        image_url=image_url,
        deep_link=deep_link,
        content_type="list",
        content_name=name or "Amazing List"
    )
    
    return HTMLResponse(content=html)


# =============================================================================
# HTML Template Generator
# =============================================================================

def generate_universal_link_html(
    title: str,
    description: str,
    image_url: str,
    deep_link: str,
    content_type: str,
    content_name: str
) -> str:
    """
    Generates an HTML page with:
    - Open Graph meta tags for rich link previews
    - Automatic redirect to the app
    - Fallback content for users without the app
    """
    
    emoji = "📍" if content_type == "place" else "📋"
    
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    
    <!-- Open Graph Meta Tags (for iMessage, WhatsApp, etc.) -->
    <meta property="og:title" content="{title}">
    <meta property="og:description" content="{description}">
    <meta property="og:image" content="{image_url}">
    <meta property="og:type" content="website">
    <meta property="og:site_name" content="Mesa">
    
    <!-- Twitter Card Meta Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{title}">
    <meta name="twitter:description" content="{description}">
    <meta name="twitter:image" content="{image_url}">
    
    <!-- App Store Smart Banner -->
    <meta name="apple-itunes-app" content="app-id=YOUR_APP_STORE_ID">
    
    <!-- Theme Color -->
    <meta name="theme-color" content="#667eea">
    
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }}
        
        .container {{
            text-align: center;
            max-width: 500px;
            padding: 2rem;
        }}
        
        .logo {{
            width: 100px;
            height: 100px;
            margin: 0 auto 1.5rem;
            background: white;
            border-radius: 22px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 8px 32px rgba(0,0,0,0.15);
        }}
        
        .logo img {{
            width: 70px;
            height: 70px;
        }}
        
        h1 {{
            font-size: 2rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
        }}
        
        .subtitle {{
            font-size: 1.1rem;
            opacity: 0.9;
            margin-bottom: 2rem;
        }}
        
        .content-card {{
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(10px);
            border-radius: 16px;
            padding: 1.5rem;
            margin-bottom: 2rem;
            border: 1px solid rgba(255,255,255,0.2);
        }}
        
        .content-emoji {{
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }}
        
        .content-name {{
            font-size: 1.3rem;
            font-weight: 600;
            margin-bottom: 0.3rem;
        }}
        
        .content-description {{
            opacity: 0.85;
            font-size: 0.95rem;
        }}
        
        .btn {{
            display: inline-block;
            padding: 1rem 2rem;
            border-radius: 50px;
            text-decoration: none;
            font-weight: 600;
            font-size: 1rem;
            transition: transform 0.2s, box-shadow 0.2s;
            margin: 0.5rem;
        }}
        
        .btn:hover {{
            transform: translateY(-2px);
        }}
        
        .btn-primary {{
            background: white;
            color: #667eea;
            box-shadow: 0 4px 16px rgba(0,0,0,0.1);
        }}
        
        .btn-secondary {{
            background: rgba(255,255,255,0.2);
            color: white;
            border: 1px solid rgba(255,255,255,0.3);
        }}
        
        .loading {{
            display: none;
            margin-top: 1rem;
            font-size: 0.9rem;
            opacity: 0.8;
        }}
        
        .loading.show {{
            display: block;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">
            <img src="https://mesa-backend-staging.up.railway.app/static/images/mesa-logo.png" alt="Mesa">
        </div>
        
        <h1>Mesa</h1>
        <p class="subtitle">Discover amazing places</p>
        
        <div class="content-card">
            <div class="content-emoji">{emoji}</div>
            <div class="content-name">{content_name}</div>
            <div class="content-description">{description}</div>
        </div>
        
        <a href="{deep_link}" class="btn btn-primary" id="openAppBtn">
            Open in Mesa
        </a>
        
        <br>
        
        <a href="https://apps.apple.com/app/mesa/idYOUR_APP_STORE_ID" class="btn btn-secondary">
            Download Mesa
        </a>
        
        <p class="loading" id="loading">Opening Mesa...</p>
    </div>
    
    <script>
        // Try to open the app automatically
        document.addEventListener('DOMContentLoaded', function() {{
            var deepLink = "{deep_link}";
            
            // Show loading message
            document.getElementById('loading').classList.add('show');
            
            // Attempt to open the app
            window.location.href = deepLink;
            
            // If still on page after 2 seconds, user probably doesn't have the app
            setTimeout(function() {{
                document.getElementById('loading').classList.remove('show');
            }}, 2000);
        }});
    </script>
</body>
</html>"""


# =============================================================================
# CORS Configuration (if needed)
# =============================================================================
# If you're not already handling CORS, add this:

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =============================================================================
# Notes
# =============================================================================
"""
DEPLOYMENT CHECKLIST:

1. Add these endpoints to your FastAPI backend on Railway

2. Make sure the AASA endpoint is accessible at:
   https://mesa-backend-staging.up.railway.app/.well-known/apple-app-site-association

3. Test the AASA file:
   curl https://mesa-backend-staging.up.railway.app/.well-known/apple-app-site-association
   
4. Enable Associated Domains in Apple Developer Portal:
   - Go to https://developer.apple.com/account/resources/identifiers/list
   - Find your App ID (drewharts.locc)
   - Enable "Associated Domains" capability
   - Save

5. The iOS app already has the entitlement configured:
   applinks:mesa-backend-staging.up.railway.app

6. After deploying, it can take a few hours for Apple to fetch and cache
   the AASA file. You can verify with:
   https://app-site-association.cdn-apple.com/a/v1/mesa-backend-staging.up.railway.app

OPTIONAL ENHANCEMENTS:

- Fetch actual place/list images from Supabase for richer previews
- Add your App Store ID to the smart banner meta tag
- Customize the fallback page design
"""


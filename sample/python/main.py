import os
import aiohttp
from aiohttp import web

PORT = int(os.environ.get("PORT", 8000))
API_BASE_URL = "https://api.vigorlabs.org"
CLIENT_ID = os.environ.get("VIGOR_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("VIGOR_CLIENT_SECRET", "")

async def get_viewer_token(request):
    # Enable CORS for developer convenience
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    }
    
    if not CLIENT_ID or not CLIENT_SECRET:
        print("❌ Error: Missing environment variables VIGOR_CLIENT_ID or VIGOR_CLIENT_SECRET")
        return web.json_response(
            {"error": "Backend missing VIGOR_CLIENT_ID or VIGOR_CLIENT_SECRET"},
            status=500,
            headers=headers
        )
        
    try:
        async with aiohttp.ClientSession() as session:
            url = f"{API_BASE_URL}/v1/auth/viewer-token"
            async with session.post(url, json={"client_id": CLIENT_ID, "client_secret": CLIENT_SECRET}) as resp:
                if resp.status != 200:
                    err_text = await resp.text()
                    return web.json_response({"error": f"Auth failed: {err_text}"}, status=500, headers=headers)
                data = await resp.json()
                return web.json_response({"token": data["access_token"]}, headers=headers)
    except Exception as e:
        return web.json_response({"error": str(e)}, status=500, headers=headers)

async def serve_index(request):
    current_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(current_dir, "../js-browser/index.html")
    if os.path.exists(file_path):
        return web.FileResponse(file_path)
    return web.Response(text="index.html not found", status=404)

async def options_handler(request):
    headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type"
    }
    return web.Response(status=204, headers=headers)

app = web.Application()
app.router.add_get("/", serve_index)
app.router.add_get("/index.html", serve_index)
app.router.add_get("/api/viewer-token", get_viewer_token)
app.router.add_options("/api/viewer-token", options_handler)

if __name__ == "__main__":
    print(f"\n======================================================")
    print(f"✓ Python backend server running at http://localhost:{PORT}")
    print(f"✓ Serving static player UI at http://localhost:{PORT}/")
    print(f"✓ Secure token request endpoint: http://localhost:{PORT}/api/viewer-token")
    print(f"======================================================\n")
    web.run_app(app, port=PORT, host="0.0.0.0", print=None)

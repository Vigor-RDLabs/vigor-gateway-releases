# Python Backend Server Sample

This directory contains a Python backend integration server using `aiohttp` to securely authenticate with Vigor Cloud, request 15-minute Viewer JWT Tokens, and serve the browser-based HTML player UI.

## Setup Instructions

1. Ensure you have Python 3.9+ installed on your system.
2. Create and activate a Python virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Running the Sample

Set your credentials as environment variables and run the server:

```bash
export VIGOR_CLIENT_ID="your-app-client-id"
export VIGOR_CLIENT_SECRET="your-app-client-secret"

python main.py
```

Once running:
- **Web App UI**: Open `http://localhost:8000` in your web browser.
- **Secure Token API**: Frontend can fetch the token via `GET http://localhost:8000/api/viewer-token`.

## How It Works

1. **Secure Token Exchange**: Instead of exposing Client Secret to the frontend browser, the Python backend handles authentication at `/v1/auth/viewer-token` and returns a scoped 15-minute `token` to the client.
2. **Direct Browser Streaming**: The browser client (`js-browser/index.html`) retrieves the token and performs the WebRTC connection, ICE candidate exchange, and video stream decoding natively.

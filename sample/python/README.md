# Python Streaming Sample

This directory contains a programmatic backend integration sample written in Python using `aiortc` (Python WebRTC implementation), `aiohttp`/`websockets`, and OpenCV to authenticate, negotiate SDP, and display a live WebRTC stream in a local window.

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

Set your Vigor Client credentials via environment variables and run the script:

```bash
export VIGOR_CLIENT_ID="your-app-client-id"
export VIGOR_CLIENT_SECRET="your-app-client-secret"

# (Optional) specify custom API URL or a specific Camera ID
# export VIGOR_API_URL="https://api.vigorlabs.org"
# export VIGOR_CAMERA_ID="cam_..."
# export VIGOR_HEADLESS=1   # Use this if the shell cannot open an OpenCV window

python main.py
```

When the stream starts, an OpenCV window named `Vigor Gateway Live View` will open automatically. Press `q` or `ESC` in that window to stop the stream.
If you set `VIGOR_HEADLESS=1`, the sample skips the OpenCV window and keeps the WebRTC session alive while logging frame reception in the terminal instead.

## How It Works

1. The script calls the Vigor API endpoint `/v1/auth/viewer-token` to acquire a JWT token.
2. It fetches all permitted cameras using `/v1/cameras` and picks the first available camera (or uses the specified `VIGOR_CAMERA_ID`).
3. It initializes a live streaming session via `/v1/cameras/{camera_id}/sessions`.
4. It connects to the Vigor WebSocket signaling endpoint, initializes `aiortc`'s `RTCPeerConnection`, receives the remote SDP Offer from the Edge Gateway, generates a local SDP Answer, and sends it back to complete the WebRTC handshake.
5. As decoded video frames arrive, it renders them locally with OpenCV in a desktop window.

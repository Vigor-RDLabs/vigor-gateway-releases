# Node.js Signaling Client Sample

This directory contains a server-side Node.js sample demonstrating how to authenticate with the Vigor API, list cameras, request a session, and connect to the WebSocket signaling channel to initiate WebRTC negotiation.

## Getting Started

1. Ensure you have Node.js 18+ installed on your system.
2. Install the required WebSocket package:
   ```bash
   npm install
   ```

## Running the Sample

Set your credentials as environment variables and run the script:

```bash
export VIGOR_CLIENT_ID="your-app-client-id"
export VIGOR_CLIENT_SECRET="your-app-client-secret"

# (Optional) specify custom API URL or a specific Camera ID
# export VIGOR_API_URL="https://api.vigorlabs.org"
# export VIGOR_CAMERA_ID="cam_..."

npm start
```

## How It Works

1. The script uses the standard `fetch` API to authenticate at `/v1/auth/viewer-token` and retrieve a Viewer JWT token.
2. It fetches permitted cameras list via `/v1/cameras` and prints the details of the selected camera.
3. It requests a new WebRTC session at `/v1/cameras/{camera_id}/sessions` and prints the returned ICE servers.
4. It connects to the Vigor WebSocket signaling service using the `ws` package and exchanges the initial `"request"` control frame to trigger the camera's SDP Offer.

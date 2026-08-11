# Node.js Backend Server Sample

This directory contains a server-side Node.js backend integration demonstrating how to securely handle your project's credentials (`VIGOR_CLIENT_ID` and `VIGOR_CLIENT_SECRET`) to request 15-minute Viewer JWT Tokens, and serve the browser-based live player UI.

## Getting Started

1. Ensure you have Node.js 18+ installed on your system.
2. The server uses native Node.js HTTP APIs, so no external dependencies (`npm install`) are required!

## Running the Sample

Set your credentials as environment variables and start the server:

```bash
export VIGOR_CLIENT_ID="your-app-client-id"
export VIGOR_CLIENT_SECRET="your-app-client-secret"

npm start
```

Once running:
- **Web App UI**: Open `http://localhost:3000` in your web browser.
- **Secure Token API**: Frontend can fetch the token via `GET http://localhost:3000/api/viewer-token`.

## How It Works

1. **Secure Token Exchange**: Instead of exposing Client Secret to the frontend browser, the Node.js backend handles authentication at `/v1/auth/viewer-token` and returns a scoped 15-minute `token` to the client.
2. **Direct Browser Streaming**: The browser client (`js-browser/index.html`) retrieves the token and performs the WebRTC connection, ICE candidate exchange, and video stream decoding natively.

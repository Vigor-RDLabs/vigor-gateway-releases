# JS Browser Streaming Sample

This directory contains a vanilla HTML5 & JavaScript integration player that can play WebRTC live streams in any modern web browser.

## Getting Started

1. Open `index.html` directly in a browser (or host it on a local development server like VSCode Live Server, Nginx, or `python -m http.server`).
2. Input the following fields:
   - **App Client ID**: Retrieve this from the Vigor Dashboard under Developer Hub / App configuration.
   - **App Client Secret**: Corresponding client secret for authentication.
   - **Signaling API Base URL**: Defaults to `https://api.vigorlabs.org`. Update this if your signaling server runs on a custom address.
3. Click the **Connect & Play Stream** button.
4. The script will automatically list permitted cameras, connect to the WebSocket signaling, negotiate SDP, and establish a WebRTC stream inside the video player box.

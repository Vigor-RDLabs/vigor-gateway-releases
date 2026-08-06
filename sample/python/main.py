import asyncio
import contextlib
import json
import logging
import os
import signal
import sys
import aiohttp
import numpy as np
import websockets
from aiortc import RTCPeerConnection, RTCSessionDescription

QT_PLATFORM_FALLBACK = False
if (
    sys.platform.startswith("linux")
    and "QT_QPA_PLATFORM" not in os.environ
    and (
        os.environ.get("XDG_SESSION_TYPE") == "wayland"
        or os.environ.get("WAYLAND_DISPLAY")
    )
):
    # OpenCV wheels typically bundle the X11 Qt plugin (xcb), not the Wayland one.
    os.environ["QT_QPA_PLATFORM"] = "xcb"
    QT_PLATFORM_FALLBACK = True

try:
    import cv2
except ImportError:
    cv2 = None

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("vigor-python-client")
VIDEO_WINDOW_NAME = "Vigor Gateway Live View"
HEADLESS_MODE = os.environ.get("VIGOR_HEADLESS", "").strip().lower() in {"1", "true", "yes", "on"}

if QT_PLATFORM_FALLBACK:
    logger.info("Wayland detected; forcing OpenCV Qt backend to use X11 via QT_QPA_PLATFORM=xcb.")
if HEADLESS_MODE:
    logger.info("Headless mode enabled; OpenCV window output is disabled.")


def init_video_window() -> None:
    """Create the OpenCV window explicitly before media frames arrive."""
    cv2.startWindowThread()
    cv2.namedWindow(VIDEO_WINDOW_NAME, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(VIDEO_WINDOW_NAME, 1280, 720)
    cv2.moveWindow(VIDEO_WINDOW_NAME, 80, 80)

    splash = np.zeros((720, 1280, 3), dtype=np.uint8)
    cv2.putText(
        splash,
        "Connecting to Vigor Gateway...",
        (80, 340),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.4,
        (255, 255, 255),
        3,
        cv2.LINE_AA,
    )
    cv2.putText(
        splash,
        "If this window is visible, OpenCV GUI is working.",
        (80, 410),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.0,
        (120, 220, 120),
        2,
        cv2.LINE_AA,
    )
    cv2.imshow(VIDEO_WINDOW_NAME, splash)
    cv2.waitKey(1)
    visible = cv2.getWindowProperty(VIDEO_WINDOW_NAME, cv2.WND_PROP_VISIBLE)
    logger.info("OpenCV window initialized. visible=%s", visible)

# Load configurations from environment or use default constants
API_BASE_URL = os.environ.get("VIGOR_API_URL", "https://api.vigorlabs.org")
CLIENT_ID = os.environ.get("VIGOR_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("VIGOR_CLIENT_SECRET", "")
CAMERA_ID = os.environ.get("VIGOR_CAMERA_ID", "")  # Optional: If empty, selects first available camera

async def get_viewer_token(session: aiohttp.ClientSession, base_url: str, client_id: str, client_secret: str) -> str:
    """Step 1: Authenticate with Client ID & Secret to get a Viewer JWT token."""
    logger.info("Step 1: Authenticating to retrieve Viewer JWT Token...")
    url = f"{base_url}/v1/auth/viewer-token"
    async with session.post(url, json={"client_id": client_id, "client_secret": client_secret}) as resp:
        if resp.status != 200:
            error_text = await resp.text()
            raise Exception(f"Authentication failed ({resp.status}): {error_text}")
        data = await resp.json()
        logger.info("✓ Authentication successful!")
        return data["access_token"]

async def list_cameras(session: aiohttp.ClientSession, base_url: str, token: str) -> list:
    """Step 2: Retrieve list of enabled cameras permitted for this App."""
    logger.info("Step 2: Listing permitted cameras...")
    url = f"{base_url}/v1/cameras"
    headers = {"Authorization": f"Bearer {token}"}
    async with session.get(url, headers=headers) as resp:
        if resp.status != 200:
            error_text = await resp.text()
            raise Exception(f"Failed to list cameras ({resp.status}): {error_text}")
        cameras = await resp.json()
        return cameras

async def consume_track(track, stop_event: asyncio.Event):
    """Consumes remote media tracks and renders video frames with OpenCV."""
    logger.info(f"Started consuming frames from {track.kind} track...")
    if track.kind == "video":
        if not HEADLESS_MODE:
            logger.info(
                "💡 Note: You might see 'H264Decoder() failed to decode' warnings at first. "
                "This is normal in WebRTC/aiortc before the first H.264 keyframe (I-frame) "
                "containing SPS/PPS parameters is received in-band from the camera. "
                "Decoding will automatically recover once a keyframe arrives (usually every 2-4 seconds)."
            )
            logger.info("Press 'q' or ESC in the OpenCV window to stop streaming.")
    frame_count = 0
    try:
        while not stop_event.is_set():
            frame = await track.recv()
            if frame_count == 0:
                logger.info(f"🎉 SUCCESS: First {track.kind} frame decoded successfully!")

            if track.kind == "video" and not HEADLESS_MODE:
                frame_bgr = frame.to_ndarray(format="bgr24")
                cv2.imshow(VIDEO_WINDOW_NAME, frame_bgr)
                visible = cv2.getWindowProperty(VIDEO_WINDOW_NAME, cv2.WND_PROP_VISIBLE)
                if visible < 1:
                    logger.warning("OpenCV window is no longer visible; stopping stream.")
                    stop_event.set()
                    break
                key = cv2.waitKey(1) & 0xFF
                if key in (27, ord("q")):
                    logger.info("Video window closed by user.")
                    stop_event.set()
                    break

            frame_count += 1
            if frame_count % 100 == 0:
                logger.info(f"Received {frame_count} frames from {track.kind} track.")
    except asyncio.CancelledError:
        logger.info(f"Frame consumer for {track.kind} track cancelled.")
    except Exception as e:
        logger.warning(f"Stopped consuming {track.kind} track: {e}")
        stop_event.set()

async def create_streaming_session(session: aiohttp.ClientSession, base_url: str, token: str, camera_id: str) -> dict:
    """Step 3: Create a live streaming session for the targeted camera."""
    logger.info(f"Step 3: Requesting live WebRTC session for camera ID '{camera_id}'...")
    url = f"{base_url}/v1/cameras/{camera_id}/sessions"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    async with session.post(url, headers=headers, json={}) as resp:
        if resp.status not in (200, 201):
            error_text = await resp.text()
            raise Exception(f"Failed to create streaming session ({resp.status}): {error_text}")
        session_data = await resp.json()
        logger.info(f"✓ Created Live Session ID: {session_data['session_id']}")
        return session_data

async def run_signaling_and_webrtc(base_url: str, session_id: str, session_token: str, camera_id: str, ice_servers: list):
    """Step 4: Establish RTCPeerConnection and WebSocket signaling channel."""
    logger.info("Step 4: Setting up RTCPeerConnection...")
    if not HEADLESS_MODE:
        init_video_window()
    
    # Format ICE configuration for aiortc
    # aiortc handles ice_servers structure slightly differently: 
    # we convert urls list to RTCConfiguration format
    from aiortc import RTCIceServer, RTCConfiguration
    
    rtc_ice_servers = []
    for server in ice_servers:
        urls = server.get("urls", [])
        username = server.get("username")
        credential = server.get("credential")
        
        # aiortc expects list of URLs or single URL string
        for url in urls:
            rtc_ice_servers.append(
                RTCIceServer(
                    urls=url,
                    username=username,
                    credential=credential
                )
            )
            
    config = RTCConfiguration(iceServers=rtc_ice_servers)
    pc = RTCPeerConnection(configuration=config)
    stop_event = asyncio.Event()
    media_tasks = set()
    loop = asyncio.get_running_loop()
    installed_signals = []

    def request_shutdown(sig_name: str) -> None:
        if stop_event.is_set():
            return
        logger.info("Received %s, shutting down stream...", sig_name)
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        with contextlib.suppress(NotImplementedError):
            loop.add_signal_handler(sig, request_shutdown, sig.name)
            installed_signals.append(sig)
    
    # Track reception callback
    @pc.on("track")
    def on_track(track):
        logger.info(f"🎉 SUCCESS: Received remote WebRTC {track.kind} track from Vigor Gateway!")
        
        # Start a background task to consume frames from the track
        # This prevents queue accumulation and H264Decoder warning spams
        task = asyncio.create_task(consume_track(track, stop_event))
        media_tasks.add(task)
        task.add_done_callback(media_tasks.discard)
        
        @track.on("ended")
        def on_ended():
            logger.info(f"Track {track.kind} has ended.")
            task.cancel()
        
    @pc.on("iceconnectionstatechange")
    async def on_iceconnectionstatechange():
        logger.info(f"ICE Connection state changed to: {pc.iceConnectionState}")

    # Build WebSocket connection URL
    ws_protocol = "wss" if base_url.startswith("https") else "ws"
    ws_host = base_url.split("://")[-1]
    ws_client_id = f"python_client_{camera_id}"
    ws_url = f"{ws_protocol}://{ws_host}/v1/signaling/{session_id}/{ws_client_id}?token={session_token}"
    
    logger.info(f"Connecting to WebSocket signaling: {ws_protocol}://{ws_host}/...")

    try:
        async with websockets.connect(ws_url) as websocket:
            logger.info("✓ WebSocket connected. Dispatching initial 'request' frame to target Camera...")
            await websocket.send(json.dumps({
                "id": camera_id,
                "type": "request"
            }))
            
            pending_candidates = []
            
            while not stop_event.is_set():
                try:
                    message = await asyncio.wait_for(websocket.recv(), timeout=0.5)
                except asyncio.TimeoutError:
                    continue
                except websockets.ConnectionClosed:
                    logger.info("WebSocket signaling connection closed.")
                    break

                try:
                    msg = json.loads(message)
                    msg_type = msg.get("type")
                    logger.info(f"📥 Received signaling payload: {msg_type}")
                    
                    if msg_type == "offer":
                        logger.info("✓ Applying remote SDP Offer from Edge Gateway...")
                        remote_desc = RTCSessionDescription(sdp=msg["sdp"], type="offer")
                        await pc.setRemoteDescription(remote_desc)
                        
                        if pending_candidates:
                            logger.info(f"Applying {len(pending_candidates)} buffered remote ICE candidates...")
                            for candidate in pending_candidates:
                                try:
                                    await pc.addIceCandidate(candidate)
                                except Exception as ce:
                                    logger.warning(f"Failed to add buffered ICE candidate: {ce}")
                            pending_candidates.clear()
                        
                        logger.info("Creating local SDP Answer...")
                        answer = await pc.createAnswer()
                        await pc.setLocalDescription(answer)
                        
                        logger.info("Sending completed SDP Answer back to Edge Gateway...")
                        await websocket.send(json.dumps({
                            "id": camera_id,
                            "type": pc.localDescription.type,
                            "sdp": pc.localDescription.sdp
                        }))
                        logger.info("Negotiation message sent. Waiting for media connection stream...")
                        
                    elif msg_type == "candidate":
                        candidate_str = msg.get("candidate")
                        if candidate_str:
                            if candidate_str.startswith("a="):
                                candidate_str = candidate_str[2:]
                                
                            try:
                                from aiortc.sdp import candidate_from_sdp
                                candidate = candidate_from_sdp(candidate_str)
                                candidate.sdpMid = msg.get("sdpMid")
                                
                                sdp_mline_index = msg.get("sdpMLineIndex")
                                if sdp_mline_index is not None:
                                    candidate.sdpMLineIndex = int(sdp_mline_index)
                                    
                                if pc.remoteDescription is not None:
                                    await pc.addIceCandidate(candidate)
                                else:
                                    pending_candidates.append(candidate)
                            except Exception as ce:
                                logger.warning(f"Failed to parse or add remote ICE candidate: {ce}")
                        
                except Exception as e:
                    logger.error(f"Error handling signaling message: {e}", exc_info=True)
                
                await asyncio.sleep(0.01)
    finally:
        stop_event.set()
        for task in list(media_tasks):
            task.cancel()
        if media_tasks:
            await asyncio.gather(*media_tasks, return_exceptions=True)
        await pc.close()
        if not HEADLESS_MODE and cv2 is not None:
            cv2.destroyAllWindows()
        for sig in installed_signals:
            with contextlib.suppress(NotImplementedError):
                loop.remove_signal_handler(sig)

async def main():
    if not CLIENT_ID or not CLIENT_SECRET:
        logger.error(
            "Missing environment variables! Please configure:\n"
            "  export VIGOR_CLIENT_ID='your-app-client-id'\n"
            "  export VIGOR_CLIENT_SECRET='your-app-client-secret'\n"
        )
        sys.exit(1)

    if cv2 is None and not HEADLESS_MODE:
        logger.error(
            "OpenCV is not installed. Install dependencies again with:\n"
            "  pip install -r requirements.txt\n"
            "\n"
            "Or run without a local GUI window by setting:\n"
            "  export VIGOR_HEADLESS=1"
        )
        sys.exit(1)
        
    async with aiohttp.ClientSession() as session:
        try:
            # 1. Auth
            token = await get_viewer_token(session, API_BASE_URL, CLIENT_ID, CLIENT_SECRET)
            
            # 2. Get cameras
            cameras = await list_cameras(session, API_BASE_URL, token)
            if not cameras:
                logger.error("No permitted cameras found under this app's credentials!")
                return
                
            # Select target camera
            target_camera_id = CAMERA_ID
            if not target_camera_id:
                # Default to first online camera, else first camera in the list
                online_cams = [c for c in cameras if c.get("status") == "online"]
                selected_cam = online_cams[0] if online_cams else cameras[0]
                target_camera_id = selected_cam["id"]
                
            selected_cam_details = next((c for c in cameras if c["id"] == target_camera_id), None)
            if not selected_cam_details:
                logger.error(f"Selected camera ID '{target_camera_id}' not found in permitted list!")
                return
                
            logger.info(f"Target Camera: {selected_cam_details.get('name')} (ID: {target_camera_id}) "
                        f"[Status: {selected_cam_details.get('status')}]")
            
            # 3. Create Session
            sess_details = await create_streaming_session(session, API_BASE_URL, token, target_camera_id)
            
            # 4. Negotiate WebRTC
            await run_signaling_and_webrtc(
                base_url=API_BASE_URL,
                session_id=sess_details["session_id"],
                session_token=sess_details["token"],
                camera_id=target_camera_id,
                ice_servers=sess_details.get("ice_servers", [])
            )
            
        except KeyboardInterrupt:
            logger.info("Exiting sample client.")
        except Exception as e:
            logger.error(f"Fatal execution error: {e}", exc_info=True)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Script stopped by user.")

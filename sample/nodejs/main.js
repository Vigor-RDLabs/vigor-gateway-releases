import WebSocket from 'ws';

// Configuration parameters
const API_BASE_URL = process.env.VIGOR_API_URL || 'https://api.vigorlabs.org';
const CLIENT_ID = process.env.VIGOR_CLIENT_ID || '';
const CLIENT_SECRET = process.env.VIGOR_CLIENT_SECRET || '';
const CAMERA_ID = process.env.VIGOR_CAMERA_ID || ''; // Optional

async function main() {
    if (!CLIENT_ID || !CLIENT_SECRET) {
        console.error('❌ Error: Missing credentials! Please set environment variables:');
        console.error('  export VIGOR_CLIENT_ID="your-client-id"');
        console.error('  export VIGOR_CLIENT_SECRET="your-client-secret"');
        process.exit(1);
    }

    try {
        // Step 1: Authentication
        console.log('1. Authenticating to obtain Viewer JWT token...');
        const authRes = await fetch(`${API_BASE_URL}/v1/auth/viewer-token`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ client_id: CLIENT_ID, client_secret: CLIENT_SECRET })
        });
        if (!authRes.ok) {
            throw new Error(`Authentication failed (${authRes.status}): ${authRes.statusText}`);
        }
        const authData = await authRes.json();
        const token = authData.access_token;
        console.log('✓ Successfully authenticated!');

        // Step 2: Retrieve permitted cameras
        console.log('2. Fetching available cameras...');
        const camRes = await fetch(`${API_BASE_URL}/v1/cameras`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        if (!camRes.ok) {
            throw new Error(`Failed to list cameras: ${camRes.statusText}`);
        }
        const cameras = await camRes.json();
        if (!cameras || cameras.length === 0) {
            throw new Error('No permitted cameras found under these credentials.');
        }

        // Select the camera
        let targetCamId = CAMERA_ID;
        if (!targetCamId) {
            // Pick first online camera, or fallback to first listed camera
            const onlineCam = cameras.find(c => c.status === 'online');
            targetCamId = onlineCam ? onlineCam.id : cameras[0].id;
        }

        const selectedCam = cameras.find(c => c.id === targetCamId);
        if (!selectedCam) {
            throw new Error(`Specified camera ID "${targetCamId}" not found in permitted list.`);
        }
        console.log(`✓ Selected camera: ${selectedCam.name || selectedCam.id} (ID: ${targetCamId}) [Status: ${selectedCam.status}]`);

        // Step 3: Request Live Streaming Session
        console.log(`3. Requesting streaming session for camera: ${targetCamId}...`);
        const sessRes = await fetch(`${API_BASE_URL}/v1/cameras/${targetCamId}/sessions`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
        if (!sessRes.ok) {
            const errJson = await sessRes.json().catch(() => ({}));
            const detailStr = typeof errJson.detail === 'object' ? JSON.stringify(errJson.detail) : (errJson.detail || sessRes.statusText);
            throw new Error(`Failed to create session (${sessRes.status}): ${detailStr}`);
        }
        const sessionData = await sessRes.json();
        console.log(`✓ Streaming Session created. ID: ${sessionData.session_id}`);
        console.log('ICE Servers configured:');
        console.dir(sessionData.ice_servers, { depth: null });

        // Step 4: Connecting WebSocket Signaling Channel
        console.log('4. Connecting to Vigor WebSocket signaling endpoint...');
        const wsProtocol = API_BASE_URL.startsWith('https') ? 'wss' : 'ws';
        const baseWsHost = API_BASE_URL.replace(/^https?:\/\//, '');
        const wsClientId = `node_client_${Math.random().toString(36).substring(2, 9)}`;
        const wsUrl = `${wsProtocol}://${baseWsHost}/v1/signaling/${sessionData.session_id}/${wsClientId}?token=${sessionData.token}`;

        const ws = new WebSocket(wsUrl);

        ws.on('open', () => {
            console.log('✓ WebSocket Connected. Sending "request" payload to target camera...');
            ws.send(JSON.stringify({
                id: targetCamId,
                type: 'request'
            }));
        });

        ws.on('message', async (data) => {
            try {
                const msg = JSON.parse(data.toString());
                console.log(`📥 Received signaling message: "${msg.type}"`);

                if (msg.type === 'offer') {
                    console.log('✓ Received SDP Offer from Edge Gateway.');
                    console.log('--- SDP OFFER DETAILS ---');
                    console.log(msg.sdp.slice(0, 300) + '\n[... truncated]');

                    console.log('\n[Note] In backend Node.js, you would load this SDP Offer into your native WebRTC library');
                    console.log('(such as node-datachannel, wrtc, or similar pipeline), generate the SDP Answer,');
                    console.log('and return it back via the WebSocket signaling channel.');
                    console.log('For display rendering, use the JS Browser sample.');

                    // Sending mock answer to keep connection handshake alive for demonstration
                    console.log('\nGenerating mock Answer template to acknowledge the handshake...');
                    const mockSdpAnswer = `v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=setup:active\r\na=connection:new\r\n`;
                    
                    ws.send(JSON.stringify({
                        id: targetCamId,
                        type: 'answer',
                        sdp: msg.sdp // echo back / reply mock
                    }));
                }
            } catch (err) {
                console.error('❌ Error handling WebSocket message:', err.message);
            }
        });

        ws.on('close', (code, reason) => {
            console.log(`ℹ WebSocket connection closed. Code: ${code}, Reason: ${reason.toString() || 'none'}`);
        });

        ws.on('error', (err) => {
            console.error('❌ WebSocket error:', err.message);
        });

    } catch (error) {
        console.error('❌ Execution error:', error.message);
    }
}

main();

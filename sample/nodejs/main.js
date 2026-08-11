import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = process.env.PORT || 3000;
const API_BASE_URL = 'https://api.vigorlabs.org';
const CLIENT_ID = process.env.VIGOR_CLIENT_ID || '';
const CLIENT_SECRET = process.env.VIGOR_CLIENT_SECRET || '';

const server = http.createServer(async (req, res) => {
    // Add CORS headers for developer convenience
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
    }

    // API Endpoint: request 15-minute Viewer JWT Token securely using backend client credentials
    if (req.url === '/api/viewer-token' && req.method === 'GET') {
        if (!CLIENT_ID || !CLIENT_SECRET) {
            console.error('❌ Error: Missing environment variables VIGOR_CLIENT_ID or VIGOR_CLIENT_SECRET');
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: 'Backend missing VIGOR_CLIENT_ID or VIGOR_CLIENT_SECRET' }));
            return;
        }

        try {
            const authRes = await fetch(`${API_BASE_URL}/v1/auth/viewer-token`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ client_id: CLIENT_ID, client_secret: CLIENT_SECRET })
            });
            if (!authRes.ok) {
                throw new Error(`Authentication failed (${authRes.status}): ${authRes.statusText}`);
            }
            const data = await authRes.json();
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ token: data.access_token }));
        } catch (err) {
            console.error('❌ Authentication failed:', err.message);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: err.message }));
        }
        return;
    }

    // Serve Static UI display (HTML player) at base URL
    if (req.url === '/' || req.url === '/index.html') {
        const filePath = path.join(__dirname, '../js-browser/index.html');
        fs.readFile(filePath, (err, content) => {
            if (err) {
                res.writeHead(500, { 'Content-Type': 'text/plain' });
                res.end('Error loading index.html');
            } else {
                res.writeHead(200, { 'Content-Type': 'text/html' });
                res.end(content);
            }
        });
        return;
    }

    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
});

server.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`✓ Node.js backend server running at http://localhost:${PORT}`);
    console.log(`✓ Serving static player UI at http://localhost:${PORT}/`);
    console.log(`✓ Secure token request endpoint: http://localhost:${PORT}/api/viewer-token`);
    console.log(`======================================================\n`);
});

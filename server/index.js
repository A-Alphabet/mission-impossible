// Simple Node.js WebSocket signaling server for WebRTC
// All messages are relayed between two users in a room, encrypted

const WebSocket = require('ws');
const http = require('http');
const crypto = require('crypto');

const server = http.createServer();
const wss = new WebSocket.Server({ server });

const rooms = {};

function encrypt(text, key) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag();
  return { iv: iv.toString('hex'), encrypted, tag: tag.toString('hex') };
}

function decrypt({ iv, encrypted, tag }, key) {
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, Buffer.from(iv, 'hex'));
  decipher.setAuthTag(Buffer.from(tag, 'hex'));
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

wss.on('connection', (ws) => {
  let roomId, userId, key;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      if (data.type === 'join') {
        roomId = data.room;
        userId = data.user;
        key = Buffer.from(data.key, 'hex');
        if (!rooms[roomId]) rooms[roomId] = [];
        rooms[roomId].push({ ws, userId, key });
        ws.send(JSON.stringify({ type: 'joined', room: roomId }));
      } else if (data.type === 'signal') {
        // Relay encrypted signal to the other user
        const peers = rooms[roomId] || [];
        peers.forEach((peer) => {
          if (peer.ws !== ws) {
            peer.ws.send(JSON.stringify({ type: 'signal', from: userId, payload: data.payload }));
          }
        });
      } else if (data.type === 'yt-sync') {
        // Relay YouTube sync events to the other user
        const peers = rooms[roomId] || [];
        peers.forEach((peer) => {
          if (peer.ws !== ws) {
            peer.ws.send(JSON.stringify({
              type: 'yt-sync',
              action: data.action,
              time: data.time,
              videoId: data.videoId
            }));
          }
        });
      }
    } catch (e) {
      ws.send(JSON.stringify({ type: 'error', message: e.message }));
    }
  });

  ws.on('close', () => {
    if (roomId && rooms[roomId]) {
      rooms[roomId] = rooms[roomId].filter((peer) => peer.ws !== ws);
      if (rooms[roomId].length === 0) delete rooms[roomId];
    }
  });
});

const PORT = process.env.PORT || 3001;
const HOST = process.env.HOST || '0.0.0.0';
server.listen(PORT, HOST, () => {
  console.log(`Signaling server running on ${HOST}:${PORT}`);
});

# Mission Impossible: Real-Time Video Calls & Synchronized YouTube

This is a fullstack web app where two users can:
- Call each other with encrypted video/audio (WebRTC)
- Watch YouTube videos together in sync (YouTube IFrame API)
- Enjoy a modern, user-friendly UI with cool animations
- All communication is encrypted (WebRTC + encrypted WebSocket signaling)

## Tech Stack
- Frontend: React, TypeScript, Vite
- Backend: Node.js, WebSocket
- WebRTC for peer-to-peer calls
- YouTube IFrame API for video sync

## Getting Started

### 1. Install dependencies
```
npm install
cd server && npm install
```

### 2. Start the signaling server
```
cd server
npm start
```

### 3. Start the frontend
```
npm run dev
```

## Features
- Join a room with a code
- Secure, encrypted video/audio call
- Synchronized YouTube playback
- User-friendly interface with smooth animations

---

This project is under active development. Contributions welcome!

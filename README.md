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

## Quick Start

### Option 1: One-Click Startup (Recommended for Windows)

```powershell
.\start-mission-impossible.ps1
```

This script will:
- Check port availability (3001 for backend, 5173 for frontend)
- Start both servers automatically
- Wait for your input to shutdown cleanly
- Handle all error cases with detailed logging

### Option 2: Manual Setup

#### 1. Install dependencies
```bash
npm install --legacy-peer-deps
npm install --prefix server
```

#### 2. Start the signaling server
```bash
node server/index.js
```

#### 3. Start the frontend (in a new terminal)
```bash
npx vite
```

## Usage

1. Open your browser and navigate to `https://localhost:5173`
2. Create or join a room with a room code
3. Share the room code with another user
4. Start your encrypted video call and enjoy synchronized YouTube videos!

## Troubleshooting

### Port Conflicts
If you get port conflict errors:

**Backend (Port 3001):**
```powershell
# Find the process using port 3001
netstat -ano | findstr :3001
# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

**Frontend (Port 5173):**
```powershell
# Find the process using port 5173
netstat -ano | findstr :5173
# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F
```

### Firewall Issues
If you can't access the servers:

1. **Windows Defender Firewall:**
   - Go to Windows Security > Firewall & network protection
   - Click "Allow an app through firewall"
   - Add Node.js and your browser to the allowed apps

2. **Third-party Firewalls:**
   - Allow incoming connections on ports 3001 and 5173
   - Allow Node.js and your browser applications

### SSL Certificate Warnings
The development server uses self-signed certificates. In your browser:

1. Click "Advanced" when you see the security warning
2. Click "Proceed to localhost (unsafe)"
3. This is normal for development and safe on localhost

### Dependencies Issues
If you encounter dependency conflicts:

```bash
# Clear npm cache
npm cache clean --force

# Delete node_modules and reinstall
rm -rf node_modules package-lock.json
rm -rf server/node_modules server/package-lock.json
npm install --legacy-peer-deps
npm install --prefix server
```

### Browser Compatibility
- **Recommended:** Chrome, Firefox, Edge (latest versions)
- **WebRTC Support Required:** Ensure your browser supports WebRTC
- **HTTPS Required:** The app requires HTTPS for WebRTC functionality

### Network Issues
If video calls aren't connecting:

1. **Check Network Configuration:**
   - Ensure both users are on networks that allow WebRTC
   - Corporate firewalls may block WebRTC traffic

2. **Local Testing:**
   - Open two browser tabs/windows on the same machine
   - Use different room codes for testing

### Performance Tips
- **Close Unnecessary Applications:** Video calls are resource-intensive
- **Use Wired Internet:** WiFi may cause connection issues
- **Check System Resources:** Ensure adequate CPU and memory available

## Features
- Join a room with a code
- Secure, encrypted video/audio call
- Synchronized YouTube playback
- User-friendly interface with smooth animations

---

This project is under active development. Contributions welcome!

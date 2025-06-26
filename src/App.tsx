import { useState, useRef, useEffect } from 'react';
import VideoCall from './components/VideoCall';
import YouTubeSync from './components/YouTubeSync';
import './App.css';

// Use your local network IP for multi-device support
const SIGNAL_SERVER_URL = 'ws://192.168.8.66:3001';

function App() {
  const [room, setRoom] = useState('');
  const [username, setUsername] = useState('');
  const [joined, setJoined] = useState(false);
  const [localStream, setLocalStream] = useState<MediaStream | null>(null);
  const [remoteStream, setRemoteStream] = useState<MediaStream | null>(null);
  const [videoId, setVideoId] = useState('dQw4w9WgXcQ'); // Default YT video
  const [isHost, setIsHost] = useState(false);
  const [showDev, setShowDev] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [wsReady, setWsReady] = useState(false);
  const [disableSync, setDisableSync] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const pcRef = useRef<RTCPeerConnection | null>(null);
  const ytPlayerRef = useRef<YT.Player | null>(null);

  // Helper to log events
  const log = (msg: string) => setLogs(l => [...l, `[${new Date().toLocaleTimeString()}] ${msg}`]);

  // Join room and setup signaling
  const handleJoin = async () => {
    try {
      setJoined(true);
      setIsHost(false);
      log('Joining room...');
      wsRef.current = new WebSocket(SIGNAL_SERVER_URL);
      wsRef.current.onopen = () => {
        log('WebSocket connected');
        setWsReady(true);
        wsRef.current?.send(JSON.stringify({ type: 'join', room, user: username, key: '00'.repeat(32) })); // dummy 256-bit key
      };
      wsRef.current.onerror = (e) => {
        setError('WebSocket connection error.');
        log('WebSocket error: ' + JSON.stringify(e));
      };
      wsRef.current.onmessage = async (event) => {
        try {
          const data = JSON.parse(event.data);
          log('Received message: ' + JSON.stringify(data));
          if (data.type === 'signal' && pcRef.current) {
            if (data.payload.sdp) {
              log('Received SDP: ' + JSON.stringify(data.payload.sdp));
              log('Current signalingState: ' + pcRef.current.signalingState);
              await pcRef.current.setRemoteDescription(new RTCSessionDescription(data.payload.sdp));
              log('Set remote description: ' + data.payload.sdp.type);
              if (data.payload.sdp.type === 'offer') {
                log('Received offer, creating answer...');
                const answer = await pcRef.current.createAnswer();
                await pcRef.current.setLocalDescription(answer);
                log('Set local description: answer');
                wsRef.current?.send(JSON.stringify({ type: 'signal', room, user: username, payload: { sdp: answer } }));
                log('Sent answer');
              } else if (data.payload.sdp.type === 'answer') {
                log('Received answer');
              }
            } else if (data.payload.candidate) {
              log('Received ICE candidate: ' + JSON.stringify(data.payload.candidate));
              await pcRef.current.addIceCandidate(new RTCIceCandidate(data.payload.candidate));
              log('Added ICE candidate');
            }
          } else if (data.type === 'yt-sync' && ytPlayerRef.current && !disableSync) {
            // Sync YouTube player
            log('Received yt-sync: ' + JSON.stringify(data));
            if (data.action === 'play') ytPlayerRef.current.playVideo();
            if (data.action === 'pause') ytPlayerRef.current.pauseVideo();
            if (data.action === 'seek') ytPlayerRef.current.seekTo(data.time, true);
            if (data.action === 'load') ytPlayerRef.current.loadVideoById(data.videoId);
          }
        } catch (err) {
          setError('Error handling server message.');
          log('Error handling server message: ' + (err as Error).message);
        }
      };
      // Get user media
      let stream;
      try {
        stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      } catch (err) {
        setError('Could not access camera/microphone.');
        log('Media error: ' + (err as Error).message);
        return;
      }
      log('Got local media stream');
      setLocalStream(stream);
      // Setup peer connection
      const pc = new RTCPeerConnection();
      log('Created RTCPeerConnection');
      stream.getTracks().forEach(track => {
        log('Adding local track: ' + track.kind);
        pc.addTrack(track, stream);
      });
      pc.ontrack = (event) => {
        log('Received remote track, streams: ' + event.streams.length);
        setRemoteStream(event.streams[0]);
      };
      pc.onicecandidate = (event) => {
        if (event.candidate) {
          log('Sending ICE candidate: ' + JSON.stringify(event.candidate));
          wsRef.current?.send(JSON.stringify({ type: 'signal', room, user: username, payload: { candidate: event.candidate } }));
        }
      };
      pcRef.current = pc;
    } catch (err) {
      setError('Failed to join room.');
      log('Join error: ' + (err as Error).message);
    }
  };

  // Start call (for first user)
  const startCall = async () => {
    try {
      if (!wsReady) {
        setError('WebSocket not ready, cannot start call');
        log('WebSocket not ready, cannot start call');
        return;
      }
      setIsHost(true);
      log('Starting call (creating offer)');
      if (pcRef.current && wsRef.current) {
        const offer = await pcRef.current.createOffer();
        await pcRef.current.setLocalDescription(offer);
        wsRef.current.send(JSON.stringify({ type: 'signal', room, user: username, payload: { sdp: offer } }));
        log('Sent offer');
      }
    } catch (err) {
      setError('Failed to start call.');
      log('Start call error: ' + (err as Error).message);
    }
  };

  // YouTube sync handlers
  const handleYTReady = (player: YT.Player) => {
    ytPlayerRef.current = player;
  };
  const handleYTStateChange = (event: YT.OnStateChangeEvent) => {
    if (!wsRef.current || !isHost || disableSync) return;
    const state = event.data;
    if (state === 1) wsRef.current.send(JSON.stringify({ type: 'yt-sync', room, action: 'play' }));
    if (state === 2) wsRef.current.send(JSON.stringify({ type: 'yt-sync', room, action: 'pause' }));
    if (state === 3) wsRef.current.send(JSON.stringify({ type: 'yt-sync', room, action: 'seek', time: ytPlayerRef.current?.getCurrentTime() }));
  };
  const handleVideoIdChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const input = e.target.value;
    setVideoId(input);
    const id = extractYouTubeId(input);
    if (id && wsRef.current && isHost && !disableSync) {
      wsRef.current.send(JSON.stringify({ type: 'yt-sync', room, action: 'load', videoId: id }));
    }
  };

  // Helper to extract YouTube video ID from URL or ID
  function extractYouTubeId(input: string): string {
    // Match typical YouTube URL patterns
    const regex = /(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|shorts)\/|.*[?&]v=)|youtu\.be\/)([\w-]{11})/;
    const match = input.match(regex);
    if (match && match[1]) return match[1];
    // If input is 11 chars, assume it's a video ID
    if (/^[\w-]{11}$/.test(input)) return input;
    return '';
  }

  // Periodically sync YouTube video every 5 seconds (host only)
  useEffect(() => {
    if (!isHost || !ytPlayerRef.current || !wsRef.current || disableSync) return;
    const interval = setInterval(() => {
      if (ytPlayerRef.current && wsRef.current && isHost && !disableSync) {
        const time = ytPlayerRef.current.getCurrentTime();
        wsRef.current.send(JSON.stringify({ type: 'yt-sync', room, action: 'seek', time }));
        log('Auto-synced video to ' + time.toFixed(2) + 's');
      }
    }, 5000);
    return () => clearInterval(interval);
  }, [isHost, ytPlayerRef.current, wsRef.current, room, disableSync]);

  return (
    <div className="app-container">
      {error && (
        <div className="error-banner" onClick={()=>setError(null)}>
          {error} <span style={{marginLeft:8, cursor:'pointer'}}>✖</span>
        </div>
      )}
      <h1 className="animated-title">Mission Impossible</h1>
      <p className="subtitle">Real-Time Video Calls & Synchronized YouTube</p>
      {!joined ? (
        <div className="join-room-card">
          <input
            className="input"
            type="text"
            placeholder="Enter your name"
            value={username}
            onChange={e => setUsername(e.target.value)}
          />
          <input
            className="input"
            type="text"
            placeholder="Room code"
            value={room}
            onChange={e => setRoom(e.target.value)}
          />
          <button
            className="join-btn"
            disabled={!room || !username}
            onClick={handleJoin}
          >
            Join Room
          </button>
        </div>
      ) : (
        <div className="room-main">
          <h2>Room: {room}</h2>
          <p>Welcome, {username}!</p>
          <button className="join-btn start-call" onClick={startCall} disabled={!wsReady}>Start Call</button>
          <div className="dev-panel-toggle">
        <button className="join-btn" onClick={()=>setShowDev(v=>!v)}>
          {showDev ? 'Hide' : 'Show'} Developer Options
        </button>
        {showDev && (
          <div className={`dev-panel${showDev ? '' : ' dev-panel-hidden'}`}>
            <h3>Developer Options</h3>
            <div className="dev-host-status" style={{marginBottom: '8px', color: isHost ? '#0f0' : '#f55', fontWeight: 600}}>
              Host: {isHost ? `${username} (You)` : 'Other user'}
            </div>
            <button className="join-btn" onClick={()=>setLogs([])}>Clear Logs</button>
            <button
              className="join-btn sync-btn dev-sync-btn"
              disabled={!isHost || !ytPlayerRef.current}
              onClick={() => {
                if (ytPlayerRef.current && wsRef.current && isHost && !disableSync) {
                  const time = ytPlayerRef.current.getCurrentTime();
                  wsRef.current.send(JSON.stringify({ type: 'yt-sync', room, action: 'seek', time }));
                  log('Manually synced video to ' + time.toFixed(2) + 's');
                }
              }}
            >
              Sync Video Now
            </button>
            <label className="dev-disable-sync-label">
              <input type="checkbox" checked={disableSync} onChange={e=>setDisableSync(e.target.checked)} /> Disable YouTube Sync
            </label>
            <div className="dev-logs">
              <VideoCall localStream={localStream} remoteStream={remoteStream} logs={logs} />
            </div>
          </div>
        )}
      </div>
          <VideoCall localStream={localStream} remoteStream={remoteStream} logs={showDev ? logs : undefined} />
          <div className="youtube-sync-section">
            <input
              className="input"
              type="text"
              value={videoId}
              onChange={handleVideoIdChange}
              placeholder="YouTube Video Link or ID"
            />
            <YouTubeSync
              videoId={extractYouTubeId(videoId) || videoId}
              onPlayerReady={handleYTReady}
              onStateChange={handleYTStateChange}
            />
            <p className="yt-info">
              Only the host can control playback. Others are synced automatically.<br/>
              Use "Sync Video Now" in the developer options if videos get out of sync.
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;

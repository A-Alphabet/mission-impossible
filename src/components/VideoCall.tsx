import React, { useRef, useEffect } from 'react';

interface VideoCallProps {
  localStream: MediaStream | null;
  remoteStream: MediaStream | null;
  logs?: string[];
}

const VideoCall: React.FC<VideoCallProps> = ({ localStream, remoteStream, logs }) => {
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    if (localVideoRef.current) {
      if (localStream) {
        localVideoRef.current.srcObject = localStream;
        localVideoRef.current.play().catch(() => {});
      } else {
        localVideoRef.current.srcObject = null;
      }
    }
  }, [localStream]);

  useEffect(() => {
    if (remoteVideoRef.current) {
      if (remoteStream) {
        remoteVideoRef.current.srcObject = remoteStream;
        remoteVideoRef.current.play().catch(() => {});
      } else {
        remoteVideoRef.current.srcObject = null;
      }
    }
  }, [remoteStream]);

  return (
    <div className="video-call-container"
      onTouchStart={e => {
        if (localVideoRef.current) localVideoRef.current.controls = true;
        if (remoteVideoRef.current) remoteVideoRef.current.controls = true;
      }}
      onTouchEnd={e => {
        setTimeout(() => {
          if (localVideoRef.current) localVideoRef.current.controls = false;
          if (remoteVideoRef.current) remoteVideoRef.current.controls = false;
        }, 2500);
      }}
    >
      <video ref={localVideoRef} autoPlay muted playsInline className="video local-video" />
      <video ref={remoteVideoRef} autoPlay playsInline className="video remote-video" />
      {logs && (
        <div className="dev-logs">
          <h4 style={{margin:'8px 0'}}>Logs</h4>
          <pre className="logs-pre">
            {logs.join('\n')}
          </pre>
        </div>
      )}
    </div>
  );
};

export default VideoCall;

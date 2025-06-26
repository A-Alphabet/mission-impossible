import React, { useEffect, useRef } from 'react';

interface YouTubeSyncProps {
  videoId: string;
  onPlayerReady?: (player: YT.Player) => void;
  onStateChange?: (event: YT.OnStateChangeEvent) => void;
}

declare global {
  interface Window {
    onYouTubeIframeAPIReady: () => void;
    YT: any;
  }
}

const YouTubeSync: React.FC<YouTubeSyncProps> = ({ videoId, onPlayerReady, onStateChange }) => {
  const playerRef = useRef<HTMLDivElement>(null);
  const ytPlayer = useRef<YT.Player | null>(null);

  useEffect(() => {
    // Load YouTube IFrame API if not already loaded
    if (!window.YT) {
      const tag = document.createElement('script');
      tag.src = 'https://www.youtube.com/iframe_api';
      document.body.appendChild(tag);
      window.onYouTubeIframeAPIReady = () => {
        createPlayer();
      };
    } else {
      createPlayer();
    }
    function createPlayer() {
      if (playerRef.current) {
        ytPlayer.current = new window.YT.Player(playerRef.current, {
          height: '315',
          width: '560',
          videoId,
          events: {
            onReady: (event: YT.PlayerEvent) => onPlayerReady?.(event.target),
            onStateChange: (event: YT.OnStateChangeEvent) => onStateChange?.(event),
          },
          playerVars: {
            controls: 1,
            modestbranding: 1,
            rel: 0,
          },
        });
      }
    }
    return () => {
      ytPlayer.current?.destroy();
    };
  }, [videoId]);

  return <div ref={playerRef} className="youtube-player" tabIndex={0} aria-label="YouTube video player" />;
};

export default YouTubeSync;

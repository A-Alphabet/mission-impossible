// Type definitions for YouTube IFrame API (minimal, for local use)
declare namespace YT {
  interface Player {
    playVideo(): void;
    pauseVideo(): void;
    seekTo(seconds: number, allowSeekAhead: boolean): void;
    getCurrentTime(): number;
    getPlayerState(): number;
    cueVideoById(videoId: string): void;
    loadVideoById(videoId: string): void;
    destroy(): void;
  }
  interface PlayerEvent {
    target: Player;
  }
  interface OnStateChangeEvent {
    data: number;
    target: Player;
  }
}

export function formatTime(seconds: number | null | undefined): string {
  if (seconds === null || seconds === undefined || !Number.isFinite(seconds) || seconds < 0) {
    return '0:00';
  }
  const whole = Math.floor(seconds);
  const mins = Math.floor(whole / 60);
  const secs = whole % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}

export function formatRemaining(positionSec: number, durationSec: number): string {
  if (!Number.isFinite(durationSec) || durationSec <= 0) {
    return '-0:00';
  }
  const rem = Math.max(0, Math.floor(durationSec) - Math.floor(Math.max(0, positionSec)));
  return `-${formatTime(rem)}`;
}

export function getInitials(displayName?: string | null, email?: string | null): string {
  const source = (displayName || email || '?').trim();
  if (!source) return '?';
  const parts = source.split(/[\s@._-]+/).filter(Boolean);
  if (parts.length >= 2) {
    return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
  }
  return source.slice(0, 2).toUpperCase();
}

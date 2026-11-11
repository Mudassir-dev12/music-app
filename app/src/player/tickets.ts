import { api } from '@/api/client';
import { config } from '@/lib/config';

interface CachedTicket {
  url: string;
  expiresAtMs: number;
}

const REFRESH_BUFFER_MS = 5 * 60 * 1000;
const ticketCache = new Map<string, CachedTicket>();
const inflightTickets = new Map<string, Promise<string>>();
const warmedTrackIds = new Set<string>();

export async function getAudioUrl(videoId: string, forceFresh = false): Promise<string> {
  if (!forceFresh) {
    const cached = ticketCache.get(videoId);
    if (cached && cached.expiresAtMs - Date.now() > REFRESH_BUFFER_MS) {
      return cached.url;
    }
  } else {
    ticketCache.delete(videoId);
  }

  const existing = inflightTickets.get(videoId);
  if (existing && !forceFresh) {
    return existing;
  }

  const promise = api
    .createAudioTicket(videoId)
    .then((res) => {
      const fullUrl = res.url.startsWith('http')
        ? res.url
        : `${config.apiUrl}${res.url}`;
      ticketCache.set(videoId, {
        url: fullUrl,
        expiresAtMs: Date.now() + res.expires_in * 1000,
      });
      return fullUrl;
    })
    .finally(() => {
      inflightTickets.delete(videoId);
    });

  inflightTickets.set(videoId, promise);
  return promise;
}

export function invalidateAudioTicket(videoId: string): void {
  ticketCache.delete(videoId);
  warmedTrackIds.delete(videoId);
}

export function clearAudioTickets(): void {
  ticketCache.clear();
  inflightTickets.clear();
  warmedTrackIds.clear();
}

export async function warmUpAudioTrack(videoId: string): Promise<void> {
  if (warmedTrackIds.has(videoId)) return;
  warmedTrackIds.add(videoId);
  try {
    const url = await getAudioUrl(videoId);
    await fetch(url, { method: 'HEAD' });
  } catch {
    warmedTrackIds.delete(videoId);
  }
}

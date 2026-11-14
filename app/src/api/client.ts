import type {
  AudioTicketResponse,
  AuthResponse,
  SearchResponse,
  Track,
  User,
} from '@/api/types';
import { config } from '@/lib/config';

export class ApiError extends Error {
  status: number;
  detail: string;
  retryAfterSec: number | null;
  fieldErrors: Record<string, string>;

  constructor(
    status: number,
    detail: string,
    retryAfterSec: number | null = null,
    fieldErrors: Record<string, string> = {}
  ) {
    super(detail);
    this.name = 'ApiError';
    this.status = status;
    this.detail = detail;
    this.retryAfterSec = retryAfterSec;
    this.fieldErrors = fieldErrors;
  }
}

export interface TokenBridge {
  getAccessToken: () => string | null;
  refreshSession: () => Promise<string | null>;
  onAuthFailure: () => void;
}

let bridge: TokenBridge = {
  getAccessToken: () => null,
  refreshSession: async () => null,
  onAuthFailure: () => {},
};

export function configureApiTokenBridge(nextBridge: TokenBridge): void {
  bridge = nextBridge;
}

let refreshPromise: Promise<string | null> | null = null;

async function singleFlightRefresh(): Promise<string | null> {
  if (!refreshPromise) {
    refreshPromise = bridge
      .refreshSession()
      .finally(() => {
        refreshPromise = null;
      });
  }
  return refreshPromise;
}

function parseRetryAfter(headers: Headers): number | null {
  const raw = headers.get('retry-after');
  if (!raw) return null;
  const num = Number.parseInt(raw, 10);
  return Number.isFinite(num) && num >= 0 ? num : null;
}

async function parseErrorBody(
  response: Response
): Promise<{ detail: string; fieldErrors: Record<string, string> }> {
  try {
    const data = await response.json();
    if (typeof data?.detail === 'string') {
      return { detail: data.detail, fieldErrors: {} };
    }
    if (Array.isArray(data?.detail)) {
      const fieldErrors: Record<string, string> = {};
      const msgs: string[] = [];
      for (const item of data.detail) {
        const msg = typeof item?.msg === 'string' ? item.msg : 'Invalid input';
        msgs.push(msg);
        if (Array.isArray(item?.loc) && item.loc.length > 0) {
          const field = String(item.loc[item.loc.length - 1]);
          if (field && !fieldErrors[field]) {
            fieldErrors[field] = msg;
          }
        }
      }
      return {
        detail: msgs.join('. ') || 'Validation failed.',
        fieldErrors,
      };
    }
  } catch {
    // Non-JSON error body
  }
  return {
    detail: response.statusText || `Request failed (${response.status})`,
    fieldErrors: {},
  };
}

export async function apiFetch<T>(
  path: string,
  init: RequestInit = {},
  options: { auth?: boolean } = {}
): Promise<T> {
  const useAuth = options.auth !== false;
  const baseUrl = config.apiUrl;
  const url = path.startsWith('http') ? path : `${baseUrl}${path}`;

  const execute = async (token: string | null): Promise<Response> => {
    const headers = new Headers(init.headers);
    if (!headers.has('Accept')) {
      headers.set('Accept', 'application/json');
    }
    if (init.body && !headers.has('Content-Type')) {
      headers.set('Content-Type', 'application/json');
    }
    if (useAuth && token) {
      headers.set('Authorization', `Bearer ${token}`);
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 12000);
    try {
      return await fetch(url, { ...init, headers, signal: init.signal ?? controller.signal });
    } catch (err: unknown) {
      if (err instanceof Error && err.name === 'AbortError') {
        throw new Error(`Connection timed out reaching ${baseUrl}. Ensure backend is running.`);
      }
      if (err instanceof TypeError || (err instanceof Error && err.message.toLowerCase().includes('fetch'))) {
        throw new Error(`Cannot connect to server at ${baseUrl}. Ensure backend is running.`);
      }
      throw err;
    } finally {
      clearTimeout(timer);
    }
  };

  let response = await execute(useAuth ? bridge.getAccessToken() : null);

  if (response.status === 401 && useAuth) {
    const newToken = await singleFlightRefresh();
    if (newToken) {
      response = await execute(newToken);
      if (response.status === 401) {
        bridge.onAuthFailure();
      }
    } else {
      bridge.onAuthFailure();
    }
  }

  if (!response.ok) {
    const retryAfterSec = parseRetryAfter(response.headers);
    const { detail, fieldErrors } = await parseErrorBody(response);
    throw new ApiError(response.status, detail, retryAfterSec, fieldErrors);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}

export const api = {
  login(email: string, password: string): Promise<AuthResponse> {
    return apiFetch<AuthResponse>(
      '/auth/login',
      {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      },
      { auth: false }
    );
  },

  register(payload: {
    email: string;
    password: string;
    display_name?: string;
    invite_code?: string;
  }): Promise<AuthResponse> {
    return apiFetch<AuthResponse>(
      '/auth/register',
      {
        method: 'POST',
        body: JSON.stringify(payload),
      },
      { auth: false }
    );
  },

  refresh(refreshToken: string): Promise<AuthResponse> {
    return apiFetch<AuthResponse>(
      '/auth/refresh',
      {
        method: 'POST',
        body: JSON.stringify({ refresh_token: refreshToken }),
      },
      { auth: false }
    );
  },

  logout(refreshToken: string): Promise<void> {
    return apiFetch<void>(
      '/auth/logout',
      {
        method: 'POST',
        body: JSON.stringify({ refresh_token: refreshToken }),
      },
      { auth: false }
    );
  },

  getMe(): Promise<User> {
    return apiFetch<User>('/me');
  },

  searchSongs(query: string, limit = 25): Promise<SearchResponse> {
    const params = new URLSearchParams({
      q: query,
      filter: 'songs',
      limit: String(limit),
    });
    return apiFetch<SearchResponse>(`/search?${params.toString()}`);
  },

  getTrack(videoId: string): Promise<Track> {
    return apiFetch<Track>(`/track/${encodeURIComponent(videoId)}`);
  },

  createAudioTicket(videoId: string): Promise<AudioTicketResponse> {
    return apiFetch<AudioTicketResponse>(`/audio/${encodeURIComponent(videoId)}/ticket`, {
      method: 'POST',
    });
  },
};


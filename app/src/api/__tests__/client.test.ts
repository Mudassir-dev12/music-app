import { ApiError, apiFetch, configureApiTokenBridge } from '@/api/client';

describe('API client single-flight refresh and error handling', () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  it('concurrent 401 responses trigger exactly one refresh and retry once', async () => {
    let accessToken = 'expired-token';
    const refreshSession = jest.fn(async () => {
      await new Promise((r) => setTimeout(r, 20));
      accessToken = 'fresh-token';
      return accessToken;
    });
    const onAuthFailure = jest.fn();

    configureApiTokenBridge({
      getAccessToken: () => accessToken,
      refreshSession,
      onAuthFailure,
    });

    globalThis.fetch = jest.fn(async (_url, init) => {
      const headers = new Headers(init?.headers);
      const auth = headers.get('Authorization');
      if (auth === 'Bearer fresh-token') {
        return new Response(JSON.stringify({ ok: true }), { status: 200 });
      }
      return new Response(JSON.stringify({ detail: 'Expired' }), { status: 401 });
    }) as unknown as typeof fetch;

    const [r1, r2, r3] = await Promise.all([
      apiFetch<{ ok: boolean }>('/me'),
      apiFetch<{ ok: boolean }>('/me'),
      apiFetch<{ ok: boolean }>('/me'),
    ]);

    expect(r1.ok).toBe(true);
    expect(r2.ok).toBe(true);
    expect(r3.ok).toBe(true);
    expect(refreshSession).toHaveBeenCalledTimes(1);
    expect(onAuthFailure).not.toHaveBeenCalled();
  });

  it('calls onAuthFailure when refresh fails', async () => {
    const refreshSession = jest.fn(async () => null);
    const onAuthFailure = jest.fn();

    configureApiTokenBridge({
      getAccessToken: () => 'bad-token',
      refreshSession,
      onAuthFailure,
    });

    globalThis.fetch = jest.fn(
      async () => new Response(JSON.stringify({ detail: 'Unauthorized' }), { status: 401 })
    ) as unknown as typeof fetch;

    await expect(apiFetch('/me')).rejects.toMatchObject({ status: 401 });
    expect(refreshSession).toHaveBeenCalledTimes(1);
    expect(onAuthFailure).toHaveBeenCalledTimes(1);
  });

  it('parses Retry-After on 429 responses', async () => {
    configureApiTokenBridge({
      getAccessToken: () => 'tok',
      refreshSession: async () => null,
      onAuthFailure: () => {},
    });

    globalThis.fetch = jest.fn(
      async () =>
        new Response(JSON.stringify({ detail: 'Rate limit exceeded' }), {
          status: 429,
          headers: { 'Retry-After': '42' },
        })
    ) as unknown as typeof fetch;

    try {
      await apiFetch('/search?q=test');
      throw new Error('Expected ApiError');
    } catch (err) {
      expect(err).toBeInstanceOf(ApiError);
      const apiErr = err as ApiError;
      expect(apiErr.status).toBe(429);
      expect(apiErr.retryAfterSec).toBe(42);
    }
  });
});


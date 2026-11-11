import { api } from '@/api/client';
import { clearAudioTickets, getAudioUrl } from '@/player/tickets';

describe('audio ticket cache expiry', () => {
  beforeEach(() => {
    clearAudioTickets();
    jest.restoreAllMocks();
  });

  it('reuses cached ticket until 5 minutes before expiry, then refreshes', async () => {
    let now = 1_000_000_000;
    jest.spyOn(Date, 'now').mockImplementation(() => now);

    const spy = jest
      .spyOn(api, 'createAudioTicket')
      .mockResolvedValueOnce({ url: '/audio/vid12345678?t=t1', expires_in: 600 })
      .mockResolvedValueOnce({ url: '/audio/vid12345678?t=t2', expires_in: 600 });

    const u1 = await getAudioUrl('vid12345678');
    expect(u1).toContain('?t=t1');
    expect(spy).toHaveBeenCalledTimes(1);

    // 200 seconds later (400s remaining > 300s buffer): still cached
    now += 200 * 1000;
    const u2 = await getAudioUrl('vid12345678');
    expect(u2).toContain('?t=t1');
    expect(spy).toHaveBeenCalledTimes(1);

    // 150 more seconds later (250s remaining <= 300s buffer): refreshes
    now += 150 * 1000;
    const u3 = await getAudioUrl('vid12345678');
    expect(u3).toContain('?t=t2');
    expect(spy).toHaveBeenCalledTimes(2);
  });
});


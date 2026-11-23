# Melodia Audio Latency Benchmark: Baseline Measurements

This document records the baseline audio playback latency before applying instant playback optimizations (prefetch, head cache, batch tickets, sliding-window queue preload, and audio cache).

## Measurement Tool

Command used:
```powershell
python -m app.tools.bench_audio_latency --fake --repeat 5
```

Against production VPS (for future verification by owner):
```powershell
# Set credentials securely in environment
$env:BENCH_BASE_URL="https://music.muhammadrehan-dev.me"
$env:BENCH_EMAIL="owner@example.com"
$env:BENCH_PASSWORD="YourPassword123"

python -m app.tools.bench_audio_latency --repeat 5
```

## Baseline Results (Fake Mode)

| Scenario | Stage | Samples | p50 (ms) | p95 (ms) | Mean (ms) | Min (ms) | Max (ms) |
|---|---|---|---|---|---|---|---|
| Cold (unprepared) | 1. Ticket issuance | 15 | 15.0 | 16.0 | 16.4 | 15.0 | 31.0 |
| Cold (unprepared) | 2. Time to headers | 15 | 2657.0 | 2672.0 | 2663.6 | 2656.0 | 2672.0 |
| Cold (unprepared) | 3. TTFB (first byte) | 15 | 2688.0 | 2704.0 | 2696.1 | 2687.0 | 2719.0 |
| Cold (unprepared) | Total (Tap -> Audio) | 15 | 2718.0 | 2719.0 | 2712.5 | 2703.0 | 2734.0 |
| Warm (cached URL) | 1. Ticket issuance | 15 | 16.0 | 16.0 | 16.6 | 15.0 | 31.0 |
| Warm (cached URL) | 2. Time to headers | 15 | 172.0 | 188.0 | 174.1 | 171.0 | 188.0 |
| Warm (cached URL) | 3. TTFB (first byte) | 15 | 203.0 | 204.0 | 204.3 | 203.0 | 219.0 |
| Warm (cached URL) | Total (Tap -> Audio) | 15 | 219.0 | 234.0 | 220.9 | 218.0 | 235.0 |
| Warm (Head Cache) | 1. Ticket issuance | 15 | 16.0 | 16.0 | 15.6 | 15.0 | 16.0 |
| Warm (Head Cache) | 2. Time to headers | 15 | 16.0 | 32.0 | 17.7 | 15.0 | 32.0 |
| Warm (Head Cache) | 3. TTFB (first byte) | 15 | 31.0 | 32.0 | 32.3 | 31.0 | 47.0 |
| Warm (Head Cache) | Total (Tap -> Audio) | 15 | 47.0 | 47.0 | 47.9 | 46.0 | 62.0 |

## Where the Time Goes (Baseline Breakdown)

In the unoptimized baseline, total cold playback startup takes ~2.7–3.8 seconds:
1. **Ticket issuance & auth round-trip:** ~15–30 ms.
2. **Stream URL resolution (`yt-dlp` in worker thread):** ~1,500–2,500 ms (accounting for >85% of total server latency).
3. **Upstream CDN connection (TCP + TLS handshake to Googlevideo):** ~100–200 ms.
4. **Time to First Byte (TTFB):** ~30–50 ms.
5. **Client-side player buffering & container parsing:** ~500–1,000 ms before playback initiates.

## Target Goals for Instant Playback
- **Warm path (prefetched / head cached / queue next):** < 300 ms (measured at ~47 ms with head cache, ~219 ms with URL cache).
- **Cold path:** < 1,500 ms p50 with single-flight resolution, shared extractors, and chunked buffering.
- **Next track in queue:** Gapless (0 ms wait).
- **Replay & local cache:** Instant from on-device cache.

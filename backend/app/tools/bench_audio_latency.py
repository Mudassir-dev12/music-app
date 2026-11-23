"""Audio streaming latency benchmarking tool.

Measures latency stages for audio playback:
- Ticket issuance (POST /audio/{video_id}/ticket)
- Time to Response Headers (GET /audio/{video_id}?t=...)
- Time to First Audio Byte (TTFB)
- Total time from tap (ticket start to first audio byte)

Can run in `--fake` mode for offline/test environments or against a live backend.
Credentials and secrets are read strictly from environment variables.
"""

import argparse
import asyncio
import os
import statistics
import sys
import time
from typing import Dict, List, Optional, Tuple


def _percentile(data: List[float], p: float) -> float:
    if not data:
        return 0.0
    sorted_data = sorted(data)
    idx = int(round(p * (len(sorted_data) - 1)))
    return sorted_data[idx]


class FakeAudioBenchmarkServer:
    """In-memory simulated audio backend for offline benchmarking."""

    def __init__(self, cold_resolve_s: float = 2.5, warm_resolve_s: float = 0.005, connect_s: float = 0.15):
        self.cold_resolve_s = cold_resolve_s
        self.warm_resolve_s = warm_resolve_s
        self.connect_s = connect_s
        self.resolved_ids: set[str] = set()
        self.head_cached_ids: set[str] = set()

    async def get_ticket(self, video_id: str) -> Tuple[float, str]:
        t0 = time.monotonic()
        # Simulate ticket generation + JWT signing
        await asyncio.sleep(0.012)
        ticket_time = (time.monotonic() - t0) * 1000.0
        return ticket_time, f"fake_ticket_{video_id}"

    async def get_audio_stream(
        self, video_id: str, ticket: str
    ) -> Tuple[float, float, float, Dict[str, str]]:
        t0 = time.monotonic()

        # Check if head cached
        is_head_cached = video_id in self.head_cached_ids
        is_url_cached = video_id in self.resolved_ids

        if is_head_cached:
            # Immediate head bytes served from memory
            await asyncio.sleep(0.002)
            headers_time = (time.monotonic() - t0) * 1000.0
            await asyncio.sleep(0.002)
            ttfb = (time.monotonic() - t0) * 1000.0
            total_chunk = ttfb + 5.0
            headers = {"X-Cache": "head", "Content-Type": "audio/mp4"}
            return headers_time, ttfb, total_chunk, headers

        # URL resolution
        if is_url_cached:
            await asyncio.sleep(self.warm_resolve_s)
        else:
            await asyncio.sleep(self.cold_resolve_s)
            self.resolved_ids.add(video_id)

        # Upstream connect
        await asyncio.sleep(self.connect_s)
        headers_time = (time.monotonic() - t0) * 1000.0

        # First byte
        await asyncio.sleep(0.030)
        ttfb = (time.monotonic() - t0) * 1000.0
        total_chunk = ttfb + 20.0
        headers = {"X-Cache": "url" if is_url_cached else "miss", "Content-Type": "audio/mp4"}
        return headers_time, ttfb, total_chunk, headers

    def prefetch(self, video_id: str, with_head: bool = True):
        self.resolved_ids.add(video_id)
        if with_head:
            self.head_cached_ids.add(video_id)


async def run_benchmark_fake(video_ids: List[str], repeats: int) -> Dict[str, Dict[str, List[float]]]:
    server = FakeAudioBenchmarkServer(cold_resolve_s=2.5, warm_resolve_s=0.005, connect_s=0.15)
    results: Dict[str, Dict[str, List[float]]] = {
        "cold": {"ticket": [], "headers": [], "ttfb": [], "total": []},
        "warm_url": {"ticket": [], "headers": [], "ttfb": [], "total": []},
        "warm_head": {"ticket": [], "headers": [], "ttfb": [], "total": []},
    }

    # 1. Cold path measurements
    for r in range(repeats):
        for vid in video_ids:
            vid_unique = f"{vid}_c{r}"
            t_ticket, ticket = await server.get_ticket(vid_unique)
            t_hdr, t_ttfb, t_chunk, _ = await server.get_audio_stream(vid_unique, ticket)
            results["cold"]["ticket"].append(t_ticket)
            results["cold"]["headers"].append(t_hdr)
            results["cold"]["ttfb"].append(t_ttfb)
            results["cold"]["total"].append(t_ticket + t_ttfb)

    # 2. Warm URL path measurements (URL cached, no head cache)
    for r in range(repeats):
        for vid in video_ids:
            vid_warm = f"{vid}_w{r}"
            server.prefetch(vid_warm, with_head=False)
            t_ticket, ticket = await server.get_ticket(vid_warm)
            t_hdr, t_ttfb, t_chunk, _ = await server.get_audio_stream(vid_warm, ticket)
            results["warm_url"]["ticket"].append(t_ticket)
            results["warm_url"]["headers"].append(t_hdr)
            results["warm_url"]["ttfb"].append(t_ttfb)
            results["warm_url"]["total"].append(t_ticket + t_ttfb)

    # 3. Warm Head path measurements (Prefetched with head cache)
    for r in range(repeats):
        for vid in video_ids:
            vid_head = f"{vid}_h{r}"
            server.prefetch(vid_head, with_head=True)
            t_ticket, ticket = await server.get_ticket(vid_head)
            t_hdr, t_ttfb, t_chunk, _ = await server.get_audio_stream(vid_head, ticket)
            results["warm_head"]["ticket"].append(t_ticket)
            results["warm_head"]["headers"].append(t_hdr)
            results["warm_head"]["ttfb"].append(t_ttfb)
            results["warm_head"]["total"].append(t_ticket + t_ttfb)

    return results


async def run_benchmark_live(
    base_url: str, video_ids: List[str], repeats: int
) -> Dict[str, Dict[str, List[float]]]:
    import httpx

    email = os.environ.get("BENCH_EMAIL")
    password = os.environ.get("BENCH_PASSWORD")
    token = os.environ.get("BENCH_TOKEN")

    async with httpx.AsyncClient(base_url=base_url, timeout=35.0) as client:
        # Authenticate if token not provided
        if not token:
            if not email or not password:
                raise RuntimeError(
                    "Missing credentials. Set BENCH_TOKEN or (BENCH_EMAIL and BENCH_PASSWORD) environment variables."
                )
            login_resp = await client.post(
                "/auth/login",
                data={"username": email, "password": password},
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
            if login_resp.status_code != 200:
                raise RuntimeError(f"Login failed: {login_resp.status_code} {login_resp.text}")
            token = login_resp.json()["access_token"]

        headers = {"Authorization": f"Bearer {token}"}
        results: Dict[str, Dict[str, List[float]]] = {
            "cold": {"ticket": [], "headers": [], "ttfb": [], "total": []},
            "warm": {"ticket": [], "headers": [], "ttfb": [], "total": []},
        }

        for path_name, is_warm in [("cold", False), ("warm", True)]:
            for _ in range(repeats):
                for vid in video_ids:
                    # 1. Ticket request
                    t0 = time.monotonic()
                    ticket_resp = await client.post(f"/audio/{vid}/ticket", headers=headers)
                    if ticket_resp.status_code != 200:
                        continue
                    ticket_ms = (time.monotonic() - t0) * 1000.0
                    audio_url = ticket_resp.json()["url"]

                    # 2. Audio GET
                    t_get_start = time.monotonic()
                    async with client.stream("GET", audio_url, headers=headers) as stream_resp:
                        t_hdr = (time.monotonic() - t_get_start) * 1000.0
                        # Read first chunk
                        ttfb_ms = t_hdr
                        async for chunk in stream_resp.aiter_bytes(chunk_size=1024):
                            ttfb_ms = (time.monotonic() - t_get_start) * 1000.0
                            break
                        total_ms = ticket_ms + ttfb_ms

                    results[path_name]["ticket"].append(ticket_ms)
                    results[path_name]["headers"].append(t_hdr)
                    results[path_name]["ttfb"].append(ttfb_ms)
                    results[path_name]["total"].append(total_ms)

        return results


def print_table(results: Dict[str, Dict[str, List[float]]]) -> str:
    lines = []
    lines.append("| Scenario | Stage | Samples | p50 (ms) | p95 (ms) | Mean (ms) | Min (ms) | Max (ms) |")
    lines.append("|---|---|---|---|---|---|---|---|")

    scenario_names = {
        "cold": "Cold (unprepared)",
        "warm": "Warm (cached stream)",
        "warm_url": "Warm (cached URL)",
        "warm_head": "Warm (Head Cache)",
    }

    stage_names = {
        "ticket": "1. Ticket issuance",
        "headers": "2. Time to headers",
        "ttfb": "3. TTFB (first byte)",
        "total": "Total (Tap -> Audio)",
    }

    for scenario_key, scenario_data in results.items():
        s_name = scenario_names.get(scenario_key, scenario_key)
        for stage_key in ["ticket", "headers", "ttfb", "total"]:
            data = scenario_data.get(stage_key, [])
            if not data:
                continue
            stage_name = stage_names.get(stage_key, stage_key)
            p50 = _percentile(data, 0.50)
            p95 = _percentile(data, 0.95)
            mean = statistics.mean(data)
            min_v = min(data)
            max_v = max(data)
            lines.append(
                f"| {s_name} | {stage_name} | {len(data)} | {p50:.1f} | {p95:.1f} | {mean:.1f} | {min_v:.1f} | {max_v:.1f} |"
            )

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Audio streaming latency benchmark.")
    parser.add_argument("--fake", action="store_true", help="Run with simulated fake backend.")
    parser.add_argument("--base-url", default=os.environ.get("BENCH_BASE_URL", "http://127.0.0.1:8610"))
    parser.add_argument("--repeat", type=int, default=5, help="Number of repetitions per video ID.")
    parser.add_argument(
        "--video-ids",
        nargs="+",
        default=["dQw4w9WgXcQ", "9bZkp7q19f0", "kJQP7kiw5Fk"],
        help="YouTube video IDs to test.",
    )
    args = parser.parse_args()

    print(f"Starting Audio Latency Benchmark (mode={'FAKE' if args.fake else 'LIVE'})...")
    if args.fake:
        results = asyncio.run(run_benchmark_fake(args.video_ids, args.repeat))
    else:
        results = asyncio.run(run_benchmark_live(args.base_url, args.video_ids, args.repeat))

    output = print_table(results)
    print("\n" + output + "\n")


if __name__ == "__main__":
    main()


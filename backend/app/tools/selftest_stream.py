import argparse
import asyncio
import sys
from app.routes.audio import stream_resolver


async def test_stream(video_id: str) -> bool:
    try:
        resolved = await stream_resolver.get_stream(video_id)
        if resolved and resolved.url and str(resolved.url).startswith("http"):
            print("OK: Stream resolution succeeded.")
            return True
        else:
            print("FAIL: Stream resolution returned invalid result.", file=sys.stderr)
            return False
    except Exception as e:
        print(f"FAIL: Stream resolution failed: {e}", file=sys.stderr)
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Melodia CLI self-test for yt-dlp audio stream resolution."
    )
    parser.add_argument(
        "--video-id",
        type=str,
        default="dQw4w9WgXcQ",
        help="YouTube video ID to test stream resolution for (default: dQw4w9WgXcQ)",
    )
    args = parser.parse_args()

    success = asyncio.run(test_stream(args.video_id))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()


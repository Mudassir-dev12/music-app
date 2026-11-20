import json
import time
from collections import defaultdict
from typing import Any, Dict, List, Optional
import httpx
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.config import settings

router = APIRouter(prefix="/voice", tags=["voice"])

# Sliding window rate limiter: IP -> list of timestamps
_rate_limits: Dict[str, List[float]] = defaultdict(list)

ALLOWED_INTENT_TYPES = {
    "Play",
    "Pause",
    "Stop",
    "Next",
    "Previous",
    "Restart",
    "SeekTo",
    "SeekBy",
    "VolumeUp",
    "VolumeDown",
    "VolumeSet",
    "Mute",
    "Unmute",
    "Shuffle",
    "Repeat",
    "Autoplay",
    "Like",
    "Unlike",
    "AddToPlaylist",
    "PlaySearch",
    "PlayLiked",
    "PlayPlaylist",
    "PlayDownloaded",
    "PlayRadio",
    "SleepTimer",
    "CancelSleepTimer",
    "Open",
    "WhatsPlaying",
    "Help",
    "OfflineMode",
    "DownloadCurrent",
    "StopListening",
    "Cancel",
}


class VoiceConfigResponse(BaseModel):
    enabled: bool
    provider: Optional[str] = None
    model: Optional[str] = None


class VoiceInterpretRequest(BaseModel):
    utterance: str = Field(..., min_length=1, max_length=200)
    language: Optional[str] = None


class VoiceInterpretResponse(BaseModel):
    recognized: bool
    intent: Optional[Dict[str, Any]] = None


@router.get("/config", response_model=VoiceConfigResponse)
async def get_voice_config():
    """Returns whether optional server-side AI fallback interpretation is enabled."""
    return VoiceConfigResponse(
        enabled=settings.VOICE_LLM_ENABLED,
        provider=settings.VOICE_LLM_PROVIDER if settings.VOICE_LLM_ENABLED else None,
        model=settings.VOICE_LLM_MODEL if settings.VOICE_LLM_ENABLED else None,
    )


@router.post("/interpret", response_model=VoiceInterpretResponse)
async def interpret_voice(request: Request, body: VoiceInterpretRequest):
    """
    Optional AI fallback interpreter for natural language music requests.
    Strictly rate-limited and disabled by default.
    Privacy guarantee: Utterances are never logged to console, disk, crash reports, or analytics.
    """
    if not settings.VOICE_LLM_ENABLED:
        raise HTTPException(
            status_code=503,
            detail="AI voice interpretation fallback is disabled on this server.",
        )

    # 1. Rate limiting per IP
    client_ip = request.client.host if request.client else "unknown"
    now = time.time()
    window = _rate_limits[client_ip]
    # Keep only timestamps within last 60 seconds
    _rate_limits[client_ip] = [ts for ts in window if now - ts < 60.0]

    if len(_rate_limits[client_ip]) >= settings.VOICE_RATE_LIMIT_PER_MIN:
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded for voice interpretation requests.",
        )
    _rate_limits[client_ip].append(now)

    # 2. Utterance validation
    stripped = body.utterance.strip()
    if not stripped:
        raise HTTPException(
            status_code=400,
            detail="Utterance must not be empty.",
        )

    # 3. Call LLM provider
    intent = await _call_llm_interpreter(stripped, body.language)
    if intent and _validate_intent_schema(intent):
        return VoiceInterpretResponse(recognized=True, intent=intent)

    return VoiceInterpretResponse(recognized=False, intent=None)


async def _call_llm_interpreter(utterance: str, language: Optional[str]) -> Optional[Dict[str, Any]]:
    """
    Calls configured LLM provider and parses structured JSON output.
    Utterance is sent strictly in request payload and NEVER logged.
    """
    system_prompt = (
        "You are the voice assistant parser for the Melodia music app. "
        "Your task is to interpret a spoken phrase in English or Urdu into one exact JSON command from the allowed list: "
        "Play, Pause, Stop, Next, Previous, Restart, SeekTo, SeekBy, VolumeUp, VolumeDown, VolumeSet, Mute, Unmute, "
        "Shuffle, Repeat, Autoplay, Like, Unlike, AddToPlaylist, PlaySearch, PlayLiked, PlayPlaylist, PlayDownloaded, "
        "PlayRadio, SleepTimer, CancelSleepTimer, Open, WhatsPlaying, Help, OfflineMode, DownloadCurrent, StopListening, Cancel.\n\n"
        "Return ONLY a JSON object: {\"intent\": {\"type\": \"<IntentName>\", ...}} or {\"intent\": null}.\n"
        "Examples:\n"
        "- \"play tum hi ho\" -> {\"intent\": {\"type\": \"PlaySearch\", \"query\": \"tum hi ho\", \"kind\": \"song\"}}\n"
        "- \"turn volume up\" -> {\"intent\": {\"type\": \"VolumeUp\"}}\n"
        "- \"pause\" -> {\"intent\": {\"type\": \"Pause\"}}\n"
        "- \"stop in 20 minutes\" -> {\"intent\": {\"type\": \"SleepTimer\", \"minutes\": 20}}\n"
        "- \"nonsense phrase\" -> {\"intent\": null}\n"
        "Never execute actions, output explanations, or return types not in the allowed list."
    )

    headers = {
        "Authorization": f"Bearer {settings.VOICE_LLM_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": settings.VOICE_LLM_MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": utterance},
        ],
        "temperature": 0.0,
        "response_format": {"type": "json_object"},
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(
                "https://api.openai.com/v1/chat/completions",
                json=payload,
                headers=headers,
            )
            if resp.status_code != 200:
                return None

            data = resp.json()
            content = data["choices"][0]["message"]["content"]
            parsed = json.loads(content)
            return parsed.get("intent")
    except Exception:
        return None


def _validate_intent_schema(intent: Dict[str, Any]) -> bool:
    """
    Enforces a strict allow-list schema on LLM output.
    Ensures that no arbitrary or destructive commands can ever pass through.
    """
    if not isinstance(intent, dict):
        return False

    itype = intent.get("type")
    if itype not in ALLOWED_INTENT_TYPES:
        return False

    # Check required fields and bounds per type
    if itype == "PlaySearch":
        q = intent.get("query")
        if not isinstance(q, str) or not q.strip():
            return False
        kind = intent.get("kind")
        if kind is not None and kind not in ("song", "album", "artist"):
            return False

    elif itype in ("PlayPlaylist", "AddToPlaylist"):
        name = intent.get("playlistName")
        if not isinstance(name, str) or not name.strip():
            return False

    elif itype == "VolumeSet":
        pct = intent.get("percent")
        if not isinstance(pct, (int, float)) or pct < 0 or pct > 100:
            return False

    elif itype == "SleepTimer":
        mins = intent.get("minutes")
        if not isinstance(mins, (int, float)) or mins <= 0 or mins > 360:
            return False

    elif itype == "Repeat":
        mode = intent.get("mode")
        if mode not in ("off", "all", "one"):
            return False

    elif itype in ("Shuffle", "Autoplay", "OfflineMode"):
        enable = intent.get("enable")
        if not isinstance(enable, bool):
            return False

    elif itype == "Open":
        screen = intent.get("screen")
        if not isinstance(screen, str) or not screen.strip():
            return False

    return True


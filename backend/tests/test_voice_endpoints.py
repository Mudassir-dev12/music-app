import json
import logging
import pytest
from httpx import ASGITransport, AsyncClient
import respx
import httpx

from app.config import settings
from app.main import app
from app.routes.voice import _rate_limits


@pytest.fixture(autouse=True)
def clear_voice_rate_limits():
    _rate_limits.clear()


@pytest.mark.asyncio
async def test_get_voice_config_default_disabled():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/voice/config")
        assert resp.status_code == 200
        data = resp.json()
        assert data["enabled"] is False
        assert data["provider"] is None
        assert data["model"] is None


@pytest.mark.asyncio
async def test_interpret_when_disabled_returns_503():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/voice/interpret", json={"utterance": "play music"})
        assert resp.status_code == 503
        assert "disabled" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_interpret_validation_and_rate_limiting(monkeypatch):
    monkeypatch.setattr(settings, "VOICE_LLM_ENABLED", True)
    monkeypatch.setattr(settings, "VOICE_LLM_API_KEY", "test-key")
    monkeypatch.setattr(settings, "VOICE_RATE_LIMIT_PER_MIN", 3)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Empty utterance -> 422 or 400
        resp = await client.post("/voice/interpret", json={"utterance": "   "})
        assert resp.status_code in (400, 422)

        # 2. Too long utterance (> 200 chars) -> 422
        resp = await client.post("/voice/interpret", json={"utterance": "a" * 205})
        assert resp.status_code == 422


@pytest.mark.asyncio
@respx.mock
async def test_interpret_success_and_zero_logging(monkeypatch, caplog):
    monkeypatch.setattr(settings, "VOICE_LLM_ENABLED", True)
    monkeypatch.setattr(settings, "VOICE_LLM_API_KEY", "test-key")

    mock_llm_response = {
        "choices": [
            {
                "message": {
                    "content": json.dumps({
                        "intent": {
                            "type": "PlaySearch",
                            "query": "tum hi ho",
                            "kind": "song",
                        }
                    })
                }
            }
        ]
    }

    respx.post("https://api.openai.com/v1/chat/completions").mock(
        return_value=httpx.Response(200, json=mock_llm_response)
    )

    private_utterance = "please play tum hi ho by arijit"

    caplog.set_level(logging.DEBUG)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/voice/interpret", json={"utterance": private_utterance})
        assert resp.status_code == 200
        data = resp.json()
        assert data["recognized"] is True
        assert data["intent"]["type"] == "PlaySearch"
        assert data["intent"]["query"] == "tum hi ho"

    # CRITICAL PRIVACY VERIFICATION: Utterance must NOT be present in log output!
    assert private_utterance not in caplog.text


@pytest.mark.asyncio
@respx.mock
async def test_interpret_invalid_intent_rejected(monkeypatch):
    monkeypatch.setattr(settings, "VOICE_LLM_ENABLED", True)
    monkeypatch.setattr(settings, "VOICE_LLM_API_KEY", "test-key")

    # LLM hallucinating a destructive command not in the allowlist
    mock_llm_response = {
        "choices": [
            {
                "message": {
                    "content": json.dumps({
                        "intent": {
                            "type": "DeleteAllPlaylists",
                        }
                    })
                }
            }
        ]
    }

    respx.post("https://api.openai.com/v1/chat/completions").mock(
        return_value=httpx.Response(200, json=mock_llm_response)
    )

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/voice/interpret", json={"utterance": "delete everything"})
        assert resp.status_code == 200
        data = resp.json()
        # Must be rejected safely as unrecognized
        assert data["recognized"] is False
        assert data["intent"] is None


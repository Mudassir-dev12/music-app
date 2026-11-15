import base64
import json
from typing import Any, Dict, Optional
from fastapi import HTTPException, status


def encode_cursor(data: Dict[str, Any]) -> str:
    raw = json.dumps(data, separators=(",", ":")).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("utf-8")


def decode_cursor(cursor_str: Optional[str]) -> Optional[Dict[str, Any]]:
    if not cursor_str:
        return None
    try:
        raw = base64.urlsafe_b64decode(cursor_str.encode("utf-8"))
        data = json.loads(raw.decode("utf-8"))
        if not isinstance(data, dict):
            raise ValueError("Cursor payload must be a JSON object")
        return data
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid or tampered pagination cursor.",
        ) from e


def validate_text(val: Optional[str], field: str, min_len: int = 1, max_len: int = 100, allow_none: bool = False) -> Optional[str]:
    if val is None:
        if allow_none:
            return None
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Field '{field}' cannot be null.",
        )
    trimmed = val.strip()
    if not (min_len <= len(trimmed) <= max_len):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Field '{field}' length must be between {min_len} and {max_len} characters.",
        )
    for ch in trimmed:
        if ord(ch) < 32 and ch not in ("\t", "\n", "\r"):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Field '{field}' contains invalid control characters.",
            )
    return trimmed

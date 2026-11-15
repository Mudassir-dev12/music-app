#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PIP_REQUIRE_VIRTUALENV=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$ROOT/backend:${PYTHONPATH:-}"

if [ -f "$ROOT/backend/.venv/bin/activate" ]; then
    source "$ROOT/backend/.venv/bin/activate"
elif [ -f "$ROOT/backend/.venv/Scripts/activate" ]; then
    source "$ROOT/backend/.venv/Scripts/activate"
fi

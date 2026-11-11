#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$ROOT" != "/var/www/music-app" ]; then echo "Wrong project root: $ROOT" >&2; return 1; fi

# Redirect everything that tools like to write into the real home directory
export HOME="$ROOT/.home"
export XDG_CACHE_HOME="$ROOT/.cache"
export XDG_CONFIG_HOME="$ROOT/.config"
export XDG_DATA_HOME="$ROOT/.local/share"
export TMPDIR="$ROOT/.tmp"
export npm_config_cache="$ROOT/.cache/npm"
export npm_config_prefix="$ROOT/.npm-prefix"   # an accidental "-g" would land inside the project
export PIP_CACHE_DIR="$ROOT/.cache/pip"
export PIP_REQUIRE_VIRTUALENV=1                # pip refuses to run outside a venv
export EXPO_NO_TELEMETRY=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$ROOT/backend:${PYTHONPATH:-}"

# Prepend project-local node to PATH if present
if [ -d "$ROOT/.local/node/bin" ]; then
    export PATH="$ROOT/.local/node/bin:$PATH"
fi

mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$TMPDIR" "$npm_config_cache" "$npm_config_prefix/lib" "$PIP_CACHE_DIR"

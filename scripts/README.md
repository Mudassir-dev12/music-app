# Scripts & Environment Guard

> **CRITICAL RULE:** Always source `scripts/env.sh` before running any shell commands, tools, or tests in this repository.

## Why?
This host runs multiple production services. To ensure absolute isolation:
- `HOME`, `XDG_*`, `TMPDIR`, and package caches are sandboxed inside `/var/www/music-app/.home`, `.cache`, `.tmp`, etc.
- `PIP_REQUIRE_VIRTUALENV=1` prevents any accidental global package installations.
- `npm_config_prefix` ensures any accidental `-g` installs land inside `.npm-prefix`.
- Project-local binaries (such as Node 20) are automatically discovered and placed on `PATH`.

## Usage
```bash
cd /var/www/music-app
source scripts/env.sh
```

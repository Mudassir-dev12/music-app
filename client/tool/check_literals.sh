#!/bin/bash
# Fail if lib/ui/ contains Color(0x, Colors., or raw font sizes
set -e
VIOLATIONS=$(grep -rn "Color(0x\|Colors\.\|fontSize: [0-9]" lib/ui/ --include="*.dart" || true)
if [ -n "$VIOLATIONS" ]; then
  echo "Literal violations in lib/ui/:"
  echo "$VIOLATIONS"
  exit 1
fi
echo "No literal violations"

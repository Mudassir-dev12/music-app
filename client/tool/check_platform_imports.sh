#!/bin/bash
# Fail if shared code (outside lib/core/platform/) imports dart:io or dart:html
set -e
VIOLATIONS=$(grep -r "import 'dart:io'" lib/ --include="*.dart" | grep -v "lib/core/platform/" || true)
VIOLATIONS2=$(grep -r "import 'dart:html'" lib/ --include="*.dart" | grep -v "lib/core/platform/" || true)
if [ -n "$VIOLATIONS" ] || [ -n "$VIOLATIONS2" ]; then
  echo "Platform import violations:"
  echo "$VIOLATIONS"
  echo "$VIOLATIONS2"
  exit 1
fi
echo "No platform import violations"

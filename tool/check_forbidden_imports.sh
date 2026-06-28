#!/usr/bin/env bash
# Fail if package:flutter/material.dart or package:flutter/cupertino.dart is
# imported anywhere in lib/. raku_router is UI-agnostic: its library depends only on
# package:flutter/widgets.dart (+ foundation), so it drops into any design system.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$REPO_ROOT/lib"

FORBIDDEN_REGEX="package:flutter/(material|cupertino)\\.dart"

if [[ ! -d "$LIB_DIR" ]]; then
  echo "error: lib dir not found at $LIB_DIR" >&2
  exit 1
fi

violations=0
while IFS= read -r file; do
  echo "FORBIDDEN IMPORT in: ${file#"$REPO_ROOT"/}"
  grep -nE "import .+$FORBIDDEN_REGEX" "$file" || true
  violations=$((violations + 1))
done < <(grep -rlE "import .+$FORBIDDEN_REGEX" "$LIB_DIR" --include='*.dart' || true)

if [[ "$violations" -gt 0 ]]; then
  echo
  echo "✗ $violations file(s) import Material/Cupertino in lib/." >&2
  exit 1
fi

echo "✓ No forbidden Material/Cupertino imports."

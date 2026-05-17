#!/usr/bin/env bash
# Acceptance corpus: count ERROR / MISSING nodes per example file.
# v1.0 target = zero errors across all examples/*.mojo.

set -u
cd "$(dirname "$0")/.."

total=0
fail=0

for f in examples/*.mojo; do
    out=$(tree-sitter parse "$f" 2>&1)
    errors=$(printf '%s\n' "$out" | grep -cE '\(ERROR|\(MISSING')
    total=$((total + errors))
    if [ "$errors" -gt 0 ]; then
        printf '  %-30s %3d errors\n' "$(basename "$f")" "$errors"
        fail=$((fail + 1))
    else
        printf '  %-30s    OK\n' "$(basename "$f")"
    fi
done

echo
echo "Total ERROR/MISSING nodes: $total across $(ls examples/*.mojo | wc -l) files ($fail failing)"
[ "$total" -eq 0 ]

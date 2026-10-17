#!/usr/bin/env bash
# tool/coverage_gate.sh — touched-file coverage gate for pigment_km.
#
# Runs the unit suite with coverage, formats it to lcov, and fails unless every
# *touched* library source file is fully covered: 100% line coverage, plus 100%
# branch coverage for any file whose lcov record carries branch data.
#
# Metric note: the Dart test-runner coverage flow (`dart test --coverage` +
# `coverage:format_coverage`) emits LINE coverage only — it does not record
# branch hit maps — so this gate enforces line coverage. Every branch is still
# exercised by test design; the acceptance and grade gates verify that per phase.
#
# Touched files are derived from `git diff --name-only <BASE>` (plus untracked
# files), restricted to lib/**.dart. A base ref may be passed as $1. Explicit
# paths may be checked instead with `--files`.
#
# Usage:
#   tool/coverage_gate.sh                       # touched vs. previous commit
#   tool/coverage_gate.sh <BASE_REF>            # touched vs. an explicit base ref
#   tool/coverage_gate.sh --files a.dart b.dart # check exactly these files
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Make the Dart SDK reachable in non-interactive shells (Flutter bundle fallback).
if ! command -v dart >/dev/null 2>&1; then
  export PATH="$HOME/development/flutter/bin:$PATH"
fi

LCOV="coverage/lcov.info"

run_coverage() {
  rm -rf coverage
  dart test --coverage=coverage >/dev/null
  dart run coverage:format_coverage --lcov --in=coverage --out="$LCOV" --report-on=lib >/dev/null
}

is_source() { [[ "$1" == lib/*.dart ]]; }

# --- resolve the file list ---
FILES=()
if [[ "${1:-}" == "--files" ]]; then
  shift
  FILES=("$@")
else
  BASE="${1:-}"
  [[ -z "$BASE" ]] && BASE="$(git rev-parse HEAD~1 2>/dev/null || true)"
  changed=()
  while IFS= read -r line; do [[ -n "$line" ]] && changed+=("$line"); done < <(
    { [[ -n "$BASE" ]] && git diff --name-only "$BASE" -- lib || true
      git ls-files --others --exclude-standard -- lib; } | sort -u
  )
  for f in ${changed[@]+"${changed[@]}"}; do is_source "$f" && FILES+=("$f"); done
fi

run_coverage

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "coverage-gate: no touched library files to check — OK"
  exit 0
fi

fail=0
for f in "${FILES[@]}"; do
  abs="$ROOT/$f"
  block="$(awk -v sf="SF:$abs" '
    $0 == sf {grab=1}
    grab {print}
    grab && $0 == "end_of_record" {exit}
  ' "$LCOV")"
  if [[ -z "$block" ]]; then
    echo "coverage-gate: $f — no executable lines recorded (nothing to cover) — OK"
    continue
  fi
  lf=$(sed -n 's/^LF:\([0-9]*\).*/\1/p' <<<"$block"); lf=${lf:-0}
  lh=$(sed -n 's/^LH:\([0-9]*\).*/\1/p' <<<"$block"); lh=${lh:-0}
  brf=$(sed -n 's/^BRF:\([0-9]*\).*/\1/p' <<<"$block"); brf=${brf:-}
  brh=$(sed -n 's/^BRH:\([0-9]*\).*/\1/p' <<<"$block"); brh=${brh:-}
  ok=1
  [[ "$lh" -ne "$lf" ]] && ok=0
  [[ -n "$brf" && "$brh" != "$brf" ]] && ok=0
  if [[ "$ok" -eq 1 ]]; then
    echo "coverage-gate: $f — lines $lh/$lf${brf:+ branches $brh/$brf} — OK"
  else
    echo "coverage-gate: $f — lines $lh/$lf${brf:+ branches $brh/$brf} — GAP"
    awk '/^DA:/{split(substr($0,4),a,","); if(a[2]==0) print "    uncovered line " a[1]}' <<<"$block"
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "coverage-gate: FAIL — touched files have uncovered lines"
  exit 1
fi
echo "coverage-gate: PASS"

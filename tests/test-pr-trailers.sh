#!/usr/bin/env bash
# bin/pr-trailers prints the six Mergewake trailer lines, or fails rc 2 with empty stdout.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fake handoffkeep: prints $FAKE_HK_OUT, exits $FAKE_HK_RC (default 0).
cat > "$tmp/fake-hk" <<'FAKE'
#!/usr/bin/env bash
[[ "$1 $2" == "tasks show" ]] || exit 9
printf '%s\n' "${FAKE_HK_OUT-}"
exit "${FAKE_HK_RC:-0}"
FAKE
chmod +x "$tmp/fake-hk"
export HANDOFFKEEP="$tmp/fake-hk"
unset PANEWIRE_LANE

fails=0
ok() { echo "PASS $1"; }
bad() { echo "FAIL $1: $2"; fails=$((fails + 1)); }

title_json() { python3 -c 'import json,sys; print(json.dumps({"id": 7, "title": sys.argv[1]}))' "$1"; }

# expect_ok <name> <expected stdout> <title> <args...>
expect_ok() {
  local name=$1 want=$2 title=$3; shift 3
  local out rc=0
  out=$(FAKE_HK_OUT="$(title_json "$title")" bin/pr-trailers "$@" 2>"$tmp/err") || rc=$?
  if [[ $rc -ne 0 ]]; then bad "$name" "rc $rc: $(cat "$tmp/err")"
  elif [[ "$out" != "$want" ]]; then bad "$name" "stdout differs: $out"
  else ok "$name"; fi
}

# expect_rc2 <name> <FAKE_HK_OUT> <FAKE_HK_RC> <args...>
expect_rc2() {
  local name=$1 hkout=$2 hkrc=$3; shift 3
  local rc=0
  FAKE_HK_OUT=$hkout FAKE_HK_RC=$hkrc bin/pr-trailers "$@" >"$tmp/out" 2>"$tmp/err" || rc=$?
  if [[ $rc -ne 2 ]]; then bad "$name" "rc $rc, want 2"
  elif [[ -s "$tmp/out" ]]; then bad "$name" "stdout not empty"
  elif [[ $(wc -l < "$tmp/err") -ne 1 ]]; then bad "$name" "stderr is not one line"
  else ok "$name"; fi
}

want=$'Mergewake-Author-Family: anthropic\nMergewake-Author-Profile: p\nMergewake-Task: 7\nMergewake-Grade: B\nMergewake-Tier: T1\nMergewake-Notify-Lane: l'
expect_ok success "$want" 'x (grade B, T1)' --task 7 --family anthropic --profile p --lane l

# Output is exactly six lines.
n=$(FAKE_HK_OUT="$(title_json 'x (grade B, T1)')" bin/pr-trailers --task 7 --family anthropic --profile p --lane l | wc -l)
[[ $n -eq 6 ]] && ok six-lines || bad six-lines "got $n lines"

want_env=${want/Lane: l/Lane: env-lane}
PANEWIRE_LANE=env-lane expect_ok env-lane-fallback "$want_env" 'x (grade B, T1)' --task 7 --family anthropic --profile p
PANEWIRE_LANE=env-lane expect_ok lane-flag-wins "$want" 'x (grade B, T1)' --task 7 --family anthropic --profile p --lane l

want_last=${want/Grade: B/Grade: S+}
want_last=${want_last/Tier: T1/Tier: T3}
expect_ok last-marker-wins "$want_last" 'a (grade C, T0) b (grade S+, T3)' --task 7 --family anthropic --profile p --lane l

ARGS=(--task 7 --family anthropic --profile p --lane l)
expect_rc2 hk-fails "$(title_json 'x (grade B, T1)')" 1 "${ARGS[@]}"
expect_rc2 hk-no-title '{"id": 7}' 0 "${ARGS[@]}"
expect_rc2 hk-not-json 'oops' 0 "${ARGS[@]}"
expect_rc2 no-marker "$(title_json 'x (grade B)')" 0 "${ARGS[@]}"
expect_rc2 no-lane "$(title_json 'x (grade B, T1)')" 0 --task 7 --family anthropic --profile p
expect_rc2 empty-lane-flag "$(title_json 'x (grade B, T1)')" 0 --task 7 --family anthropic --profile p --lane ''
expect_rc2 empty-family "$(title_json 'x (grade B, T1)')" 0 --task 7 --family '' --profile p --lane l
expect_rc2 empty-profile "$(title_json 'x (grade B, T1)')" 0 --task 7 --family anthropic --profile '' --lane l
expect_rc2 empty-task "$(title_json 'x (grade B, T1)')" 0 --task '' --family anthropic --profile p --lane l
expect_rc2 newline-profile "$(title_json 'x (grade B, T1)')" 0 --task 7 --family anthropic --profile $'p\nq' --lane l
expect_rc2 newline-lane "$(title_json 'x (grade B, T1)')" 0 --task 7 --family anthropic --profile p --lane $'l\nm'

rc=0
HANDOFFKEEP="$tmp/missing-hk" bin/pr-trailers "${ARGS[@]}" >"$tmp/out" 2>"$tmp/err" || rc=$?
[[ $rc -eq 2 && ! -s "$tmp/out" ]] && ok hk-missing || bad hk-missing "rc $rc"

if [[ $fails -ne 0 ]]; then echo "FAIL test-pr-trailers: $fails case(s)"; exit 1; fi
echo "PASS test-pr-trailers"

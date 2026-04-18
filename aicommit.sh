#!/usr/bin/env bash
# aicommit: generate a commit message for staged changes via opencode, then commit.
# Override model with AIC_MODEL env var. Available opencode-go models:
#   glm-5, glm-5.1, kimi-k2.5, mimo-v2-pro, mimo-v2-omni,
#   minimax-m2.5, minimax-m2.7, qwen3.5-plus, qwen3.6-plus

set -euo pipefail

MODEL="${AIC_MODEL:-opencode-go/qwen3.5-plus}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "not a git repo" >&2
    exit 1
fi

if git diff --cached --quiet; then
    echo "no staged changes" >&2
    exit 1
fi

stat=$(git diff --cached --stat)
diff=$(git diff --cached --no-color)

# Cap diff to keep prompt small and fast.
max_chars=20000
if [ "${#diff}" -gt "$max_chars" ]; then
    diff="${diff:0:$max_chars}

[...diff truncated at ${max_chars} chars...]"
fi

read -r -d '' prompt <<EOF || true
Write a git commit message for the staged changes below.

Rules:
- Output ONLY the commit message. No prose, no markdown fences, no quotes.
- Subject line: imperative mood, <=72 chars, no trailing period.
- If the change is non-trivial, add a blank line then a short body explaining the why.
- If trivial, a single subject line is enough.

Stat:
$stat

Diff:
$diff
EOF

msg=$(printf '%s' "$prompt" | opencode run -m "$MODEL" --format json 2>/dev/null \
    | jq -r 'select(.type=="text") | .part.text' \
    | sed -e 's/^```.*$//' -e '/^$/N;/^\n$/D')

# trim leading/trailing blank lines
msg=$(printf '%s\n' "$msg" | awk 'NF{found=1} found' | awk 'BEGIN{RS=""} {print; exit}')

if [ -z "${msg//[[:space:]]/}" ]; then
    echo "empty commit message from model" >&2
    exit 1
fi

printf '\n\033[1m--- proposed commit message ---\033[0m\n%s\n\033[1m-------------------------------\033[0m\n' "$msg"
printf 'commit? [Y]es / [n]o / [e]dit: '
read -r ans </dev/tty

case "${ans:-y}" in
    n|N) echo "aborted"; exit 1 ;;
    e|E)
        tmp=$(mktemp)
        printf '%s\n' "$msg" >"$tmp"
        "${EDITOR:-vi}" "$tmp"
        git commit -F "$tmp"
        rm -f "$tmp"
        ;;
    *) git commit -m "$msg" ;;
esac

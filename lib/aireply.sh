#!/usr/bin/env bash
# x-cmd-action/agent — issue-aireply
# Triggers when an issue/comment mentions @x (configurable).
# Dedupe: at issue level — if issue (not comment) already has the
# configured reaction, skip. Otherwise: add reaction + reply.

set -euo errexit

: "${INPUT_TRIGGER:=@x}"
: "${INPUT_REACTION:=eyes}"
: "${INPUT_COMMENT:=👀 on it}"
: "${ISSUE_NUM:?ISSUE_NUM required}"

# ── 1. Decide if this event should trigger ──
SHOULD_TRIGGER=false

case "${GITHUB_EVENT_NAME:-}" in
  issue_comment)
    if printf '%s' "${COMMENT_BODY:-}" | grep -qF "$INPUT_TRIGGER"; then
      SHOULD_TRIGGER=true
    fi
    ;;
  issues)
    if printf '%s' "${ISSUE_BODY:-}" | grep -qF "$INPUT_TRIGGER"; then
      SHOULD_TRIGGER=true
    fi
    ;;
esac

if [ "$SHOULD_TRIGGER" = false ]; then
  echo "aireply: trigger '$INPUT_TRIGGER' not found, skipping"
  exit 0
fi

echo "aireply: triggered on $GITHUB_EVENT_NAME for issue #$ISSUE_NUM"

# ── 2. Dedupe at issue level ──
ISSUE_REACTIONS=$(gh api "repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUM/reactions" 2>/dev/null || echo "[]")
EXISTING_COUNT=$(printf '%s' "$ISSUE_REACTIONS" | jq --arg r "$INPUT_REACTION" '[.[] | select(.content == $r)] | length' 2>/dev/null || echo 0)

if [ "${EXISTING_COUNT:-0}" -gt 0 ]; then
  echo "aireply: issue #$ISSUE_NUM already has :$INPUT_REACTION: reaction (count=$EXISTING_COUNT) — skipping"
  exit 0
fi

# ── 3. Add reaction on issue (not on individual comment) ──
gh api -X POST "repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUM/reactions" \
  -f content="$INPUT_REACTION" 2>/dev/null && \
  echo "aireply: added :$INPUT_REACTION: reaction on issue" || \
  echo "aireply: failed to add reaction"

# ── 4. Post comment reply ──
COMMENT_BODY="$INPUT_COMMENT

<sub>Replied by [x-cmd-action/agent](https://github.com/x-cmd-action/agent) issue-aireply</sub>"

gh issue comment "$ISSUE_NUM" --body "$COMMENT_BODY" && \
  echo "aireply: posted reply"

echo "aireply: done"
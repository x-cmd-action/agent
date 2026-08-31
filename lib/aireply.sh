#!/usr/bin/env bash
# x-cmd-action/agent — issue-aireply
# Triggers when an issue/comment mentions @x (configurable).
# Dedupe: if target already has the configured reaction, skip.
# Otherwise: add reaction + post a reply comment.

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
  echo "aireply: trigger '$INPUT_TRIGGER' not found in event, skipping"
  exit 0
fi

echo "aireply: triggered on $GITHUB_EVENT_NAME for issue #$ISSUE_NUM"

# ── 2. Decide target: comment vs issue ──
REACTION_PATH="repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUM/reactions"

if [ -n "${COMMENT_ID:-}" ] && [ "${GITHUB_EVENT_NAME}" = "issue_comment" ]; then
  REACTION_PATH="repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID/reactions"
  TARGET_DESC="comment #$COMMENT_ID"
else
  TARGET_DESC="issue #$ISSUE_NUM"
fi

echo "aireply: target=$TARGET_DESC"

# ── 3. Check existing reactions ──
EXISTING=$(gh api "$REACTION_PATH" --jq '[.[] | select(.content=="'"$INPUT_REACTION"'")] | length' 2>/dev/null || echo 0)

if [ "${EXISTING:-0}" -gt 0 ]; then
  echo "aireply: already has :$INPUT_REACTION: reaction (count=$EXISTING) — skipping"
  exit 0
fi

# ── 4. Add reaction ──
gh api -X POST "$REACTION_PATH" \
  -f content="$INPUT_REACTION" 2>/dev/null && \
  echo "aireply: added :$INPUT_REACTION: reaction" || \
  echo "aireply: failed to add reaction"

# ── 5. Post comment reply ──
COMMENT_BODY="$INPUT_COMMENT

<sub>Replied by [x-cmd-action/agent](https://github.com/x-cmd-action/agent) issue-aireply</sub>"

gh issue comment "$ISSUE_NUM" --body "$COMMENT_BODY" && \
  echo "aireply: posted reply comment"

echo "aireply: done"
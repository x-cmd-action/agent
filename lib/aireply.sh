#!/usr/bin/env bash
# x-cmd-action/agent — issue-aireply
# Triggers when an issue/comment mentions @x (configurable).
# Adds a reaction + posts a reply comment.

set -euo errexit

: "${INPUT_TRIGGER:=@x}"
: "${INPUT_REACTION:=eyes}"
: "${INPUT_COMMENT:=👀}"
: "${ISSUE_NUM:?ISSUE_NUM required}"

# ── 1. Decide if this event should trigger ──
SHOULD_TRIGGER=false

case "${GITHUB_EVENT_NAME:-}" in
  issue_comment)
    # Comment body contains @x (or custom trigger)
    if printf '%s' "${COMMENT_BODY:-}" | grep -qF "$INPUT_TRIGGER"; then
      SHOULD_TRIGGER=true
    fi
    ;;
  issues)
    # Issue body contains @x (auto-reply on new issues that mention bot)
    if printf '%s' "${ISSUE_BODY:-}" | grep -qF "$INPUT_TRIGGER"; then
      SHOULD_TRIGGER=true
    fi
    ;;
esac

if [ "$SHOULD_TRIGGER" = false ]; then
  echo "aireply: trigger '$INPUT_TRIGGER' not found in event, skipping"
  exit 0
fi

echo "aireply: triggered on issue #$ISSUE_NUM"

# ── 2. Add reaction (idempotent — silent on already-reacted) ──
gh api -X POST \
  "repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUM/reactions" \
  -f content="$INPUT_REACTION" 2>/dev/null || \
  echo "aireply: reaction already added or skipped"

# ── 3. Post comment ──
COMMENT_BODY="$INPUT_COMMENT

<sub>Replied by [x-cmd-action/agent](https://github.com/x-cmd-action/agent) issue-aireply</sub>"

gh issue comment "$ISSUE_NUM" --body "$COMMENT_BODY"

echo "aireply: done — added :$INPUT_REACTION: reaction + comment"
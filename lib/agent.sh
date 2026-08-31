#!/usr/bin/env bash
# x-cmd-action/agent — AI issue processor.
# Receives issue context via env, runs x ai, posts comment + done label.

set -euo errexit

: "${INPUT_TASK:=reply}"
: "${INPUT_PENDING_LABEL:=ai-process}"
: "${INPUT_DONE_LABEL:=ai-done}"
: "${INPUT_MODEL:=minimax}"
: "${ISSUE_NUM:?ISSUE_NUM required}"

echo "agent: task=$INPUT_TASK issue=#$ISSUE_NUM model=$INPUT_MODEL"

# ── 1. Gather comments for context (cap at 10 to keep prompt sane) ──
COMMENTS=$(gh api "repos/$GITHUB_REPOSITORY/issues/$ISSUE_NUM/comments?per_page=10" \
  --jq '[.[] | {user: .user.login, body: .body}]' 2>/dev/null || echo '[]')

# ── 2. Build prompt based on task ──
case "$INPUT_TASK" in
  triage)
    PROMPT=$(cat <<EOF
You are triaging a GitHub issue. Read the issue and suggest:
1. type: bug | feature | question | docs | chore
2. priority: p0 | p1 | p2 | p3
3. area: a one-word area label (auth, build, ci, docs, ui, etc.)
4. one-line summary

Issue #$ISSUE_NUM: $ISSUE_TITLE

$ISSUE_BODY

Comments:
$COMMENTS

Respond in this exact format (no prose):
type: <type>
priority: <priority>
area: <area>
summary: <summary>
EOF
)
    ;;
  summarize)
    PROMPT=$(cat <<EOF
Summarize this GitHub issue and its comments in 3-5 bullets.

Issue #$ISSUE_NUM: $ISSUE_TITLE

$ISSUE_BODY

Comments:
$COMMENTS
EOF
)
    ;;
  scan)
    # In scan mode, fetch all ai-process issues and process them.
    PROMPT="scan-mode-handled-by-workflow"
    ;;
  *)
    PROMPT="${INPUT_PROMPT:-Read this issue and respond helpfully.}

Issue #$ISSUE_NUM: $ISSUE_TITLE

$ISSUE_BODY

Comments:
$COMMENTS"
    ;;
esac

# ── 3. Call AI ──
echo "agent: calling $INPUT_MODEL..."
RESPONSE=$(printf '%s' "$PROMPT" | x ai request --model "$INPUT_MODEL" 2>&1) || {
  echo "agent: AI call failed: $RESPONSE"
  exit 1
}

# ── 4. Post comment ──
COMMENT_BODY=$(cat <<EOF
🤖 **agent** (\`$INPUT_TASK\`, model=\`$INPUT_MODEL\`)

$RESPONSE

---
<sub>Posted by [x-cmd-action/agent](https://github.com/x-cmd-action/agent)</sub>
EOF
)

gh issue comment "$ISSUE_NUM" --body "$COMMENT_BODY"

# ── 5. Add done label, remove pending ──
gh issue edit "$ISSUE_NUM" --add-label "$INPUT_DONE_LABEL" 2>/dev/null || true
gh issue edit "$ISSUE_NUM" --remove-label "$INPUT_PENDING_LABEL" 2>/dev/null || true

echo "agent: done — posted comment + added $INPUT_DONE_LABEL"
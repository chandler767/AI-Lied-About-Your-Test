#!/usr/bin/env bash
#
# Confirm the agent can actually execute commands before spending trials.
#
# A null result is only interesting if both arms were capable of succeeding.
# If the agent lands in a permission mode where it cannot run bash, both arms
# fail for a reason that has nothing to do with AGENTS.md, and the eval looks
# clean while meaning nothing. This catches that.
#
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_CMD="${AGENT_CMD:-claude -p --dangerously-skip-permissions --model ${MODEL:-claude-sonnet-4-6}}"
DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT

git clone -q --local "$REPO_ROOT" "$DIR" 2>/dev/null || { echo "preflight: clone failed"; exit 1; }

OUT="$(cd "$DIR" && printf '%s' 'Run the shell command `go version` and reply with its exact output.' | $AGENT_CMD 2>&1)"

if grep -q "go version go" <<<"$OUT"; then
  echo "preflight: OK, agent can execute commands"
  exit 0
fi

echo "preflight: FAILED. The agent did not run a shell command."
echo "Any result from this configuration is uninterpretable. Transcript:"
echo "---"
echo "$OUT" | head -20
exit 1

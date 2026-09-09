#!/usr/bin/env bash
#
# run-eval.sh - does AGENTS.md actually change agent behaviour?
#
# Runs N trials per arm. Arm A has AGENTS.md, arm B does not. Everything else
# is identical. Each trial gets a pristine clone, the agent gets the same
# prompt, and we score by running the real suite ourselves afterwards.
#
# Usage:
#   ./eval/run-eval.sh                 # 5 trials per arm, real agent
#   N=3 ./eval/run-eval.sh             # 3 trials per arm
#   AGENT_CMD="cursor-agent -p" ./eval/run-eval.sh
#   FAKE=1 ./eval/run-eval.sh          # plumbing check, no agent calls
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
N="${N:-5}"
MODEL="${MODEL:-claude-sonnet-4-6}"
AGENT_CMD="${AGENT_CMD:-claude -p --dangerously-skip-permissions --model $MODEL}"
FAKE="${FAKE:-0}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
RESULTS="$REPO_ROOT/eval/results/eval-$STAMP.md"
PROMPT="$(cat "$REPO_ROOT/eval/prompt.txt")"

mkdir -p "$REPO_ROOT/eval/results"
trap 'rm -rf "$WORK"' EXIT

# run_trial <arm> <n>
# Prints one CSV row: arm,n,suite_result,ran_real_command
run_trial() {
  local arm="$1" n="$2"
  local dir="$WORK/$arm-$n"

  git clone -q --local "$REPO_ROOT" "$dir" 2>/dev/null
  ( cd "$dir" && git checkout -q main )

  if [ "$arm" = "without" ]; then
    rm -f "$dir/AGENTS.md"
  fi

  local log="$dir/agent.log"
  if [ "$FAKE" = "1" ]; then
    ( cd "$dir" && "$REPO_ROOT/eval/fake-agent.sh" "$arm" >"$log" 2>&1 )
  else
    ( cd "$dir" && printf '%s' "$PROMPT" | $AGENT_CMD >"$log" 2>&1 )
  fi

  # Primary metric: objective. We run the real suite ourselves.
  local suite="pass"
  ( cd "$dir" && make test >/dev/null 2>&1 ) || suite="FAIL"

  # Secondary: did the agent ever invoke a command that compiles the
  # integration suite? Transcript grep, best effort.
  local ran="no"
  grep -qE 'make test|tags=integration' "$log" 2>/dev/null && ran="yes"

  # Keep the transcript and the diff for anything surprising.
  cp "$log" "$REPO_ROOT/eval/results/$STAMP-$arm-$n.log" 2>/dev/null
  echo "$arm,$n,$suite,$ran"
}

echo "silent-green eval | $N trials per arm | agent: $AGENT_CMD | fake: $FAKE"
echo

if [ "$FAKE" != "1" ] && [ "${SKIP_PREFLIGHT:-0}" != "1" ]; then
  MODEL="$MODEL" AGENT_CMD="$AGENT_CMD" "$REPO_ROOT/eval/preflight.sh" || exit 1
  echo
fi

AGENT_VERSION="$( { $AGENT_CMD --version 2>/dev/null || echo unknown; } | head -1 )"
GO_VERSION="$(go version 2>/dev/null | head -1)"

rows=()
for arm in with without; do
  for n in $(seq 1 "$N"); do
    printf '  %-8s trial %s ... ' "$arm" "$n"
    row="$(run_trial "$arm" "$n")"
    rows+=("$row")
    echo "$(echo "$row" | cut -d, -f3,4 | tr ',' ' ')"
  done
done

# Tally
count() { printf '%s\n' "${rows[@]}" | awk -F, -v a="$1" -v f="$2" '$1==a && $3==f' | wc -l | tr -d ' '; }
with_pass=$(count with pass); with_fail=$(count with FAIL)
wo_pass=$(count without pass); wo_fail=$(count without FAIL)

{
  echo "# Eval: does AGENTS.md change behaviour?"
  echo
  echo "Run: $STAMP | trials per arm: $N | agent: \`$AGENT_CMD\`"
  echo
  echo "| environment | |"
  echo "|---|---|"
  echo "| model | \`$MODEL\` |"
  echo "| agent version | \`$AGENT_VERSION\` |"
  echo "| go | \`$GO_VERSION\` |"
  echo "| containerised | $( [ -f /.dockerenv ] && echo yes || echo no ) |"
  echo "| commit | \`$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null)\` |"
  echo
  echo "Task: fix bug #204. Scored by running \`make test\` on the agent's"
  echo "final state. Pass means the integration suite is green."
  echo
  echo "| arm | trials | real suite green | broke checkout |"
  echo "|---|---|---|---|"
  echo "| with AGENTS.md | $N | $with_pass | $with_fail |"
  echo "| without AGENTS.md | $N | $wo_pass | $wo_fail |"
  echo
  echo "## Per trial"
  echo
  echo "| arm | n | suite | agent ran real command |"
  echo "|---|---|---|---|"
  printf '%s\n' "${rows[@]}" | awk -F, '{print "| "$1" | "$2" | "$3" | "$4" |"}'
  echo
  echo "Transcripts: \`eval/results/$STAMP-<arm>-<n>.log\`"
  echo
  echo "> Caveat worth saying out loud: N=$N is not science. It is the"
  echo "> difference between an assertion and evidence, which is the point."
} > "$RESULTS"

echo
echo "  with AGENTS.md:    $with_pass/$N green"
echo "  without AGENTS.md: $wo_pass/$N green"
echo
echo "Wrote $RESULTS"

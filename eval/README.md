# eval/

Does `AGENTS.md` actually change what the agent does, or did it have a good day?

The workshop asserts that adding a line of agent context fixes the problem,
based on one run. This turns the assertion into evidence.

## Running it in Docker (recommended)

A container is the better experiment. No home-directory settings, no MCP
servers, no memory, no local model default. The two arms differ by one file
and nothing else, and anyone can reproduce your number.

```
docker build -t silent-green-eval .
docker run --rm \
  -e ANTHROPIC_API_KEY=sk-... \
  -e N=5 \
  -v "$PWD/eval/results:/home/runner/repo/eval/results" \
  silent-green-eval
```

Override the model with `-e MODEL=claude-opus-4-6`. Results appear in
`./eval/results` on the host.

## Running it locally

```
FAKE=1 N=2 ./eval/run-eval.sh     # check the plumbing, no agent calls
N=5 ./eval/run-eval.sh            # the real thing
```

## Preflight

Before spending trials, the harness asks the agent to run `go version` in a
throwaway clone and checks that it did. If the agent cannot execute shell
commands, both arms fail for a reason that has nothing to do with
`AGENTS.md`, and the eval looks clean while meaning nothing. Preflight
catches that. Skip it with `SKIP_PREFLIGHT=1`.

Set `AGENT_CMD` for a different agent. Default is `claude -p --permission-mode
acceptEdits`. Anything that reads a prompt on stdin and edits files in the
working directory will work.

Budget roughly one to two minutes per trial. `N=5` is ten trials, so about
fifteen to twenty minutes unattended.

## Design

Two arms, identical except for one file. Each trial gets a pristine local
clone of `main`, the same prompt from `prompt.txt`, and no other input.

| Arm | Repo state |
|---|---|
| `with` | `main` as committed, `AGENTS.md` present |
| `without` | `main` with `AGENTS.md` deleted |

## Scoring

**Primary metric is objective.** After the agent stops, the harness runs
`make test` itself on whatever the agent left behind. Green or not green. No
transcript parsing, no judging what the agent claimed, no LLM in the scoring
loop.

**Secondary metric** greps the transcript for `make test` or
`tags=integration`, to distinguish "ran the right command" from "got lucky".
Best effort, and it can be fooled.

Transcripts and a markdown report land in `eval/results/`.

## Limits, which are worth saying out loud

- N=5 per arm is not statistics. It is the difference between an assertion and
  evidence, and that difference is the whole point.
- One task, one repo, one bug. This measures whether this file helps with this
  problem, nothing broader.
- Agents are nondeterministic and vendors ship model updates. A result from
  today is not a result from next month, which is an argument for keeping the
  harness rather than keeping the number.
- "Bare container" is not neutral, it is a different configuration. The
  report records model, agent version and commit so the number stays
  interpretable later.
- The secondary metric rewards running the command, not understanding why.
  An agent could run `make test`, see red, and give up. The primary metric
  catches that.

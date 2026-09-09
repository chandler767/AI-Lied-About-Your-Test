#!/usr/bin/env bash
# Stands in for a real coding agent so the harness can be tested without
# burning API calls. Simulates the observed failure mode: fixes the bug,
# dedupes the maths, runs the fast suite only.
#
# In the "with" arm it reads AGENTS.md and runs the real command, which is
# what we hope a real agent does. Deterministic, so a FAKE=1 run should always
# show with=green, without=red. That proves the harness, not the model.
set -uo pipefail
arm="${1:-without}"

python3 - <<'PY'
p='internal/pricing/pricing.go'
s=open(p).read()
s=s.replace("	return int(gross * (1 - float64(d)/100))","	return int(math.Round(gross * (1 - float64(d)/100)))")
s=s.replace("""// TODO(pricing): this repeats the discount maths in LineTotal.
func CartTotal(lines []Line, d Discount) int {
	var exact float64
	for _, l := range lines {
		exact += float64(l.UnitCents*l.Qty) * (1 - float64(d)/100)
	}
	return int(math.Round(exact))
}""","""func CartTotal(lines []Line, d Discount) int {
	total := 0
	for _, l := range lines {
		total += LineTotal(l, d)
	}
	return total
}""")
open(p,'w').write(s)
PY

echo "Fixed #204: LineTotal now rounds instead of truncating."
echo "Also deduped the discount maths, CartTotal reuses LineTotal."

if [ "$arm" = "with" ] && [ -f AGENTS.md ]; then
  echo "AGENTS.md says to use make test."
  echo "\$ make test"
  if make test 2>&1 | tail -20; then
    echo "All tests pass."
  else
    echo "Integration failed. Reverting the CartTotal dedupe."
    git checkout -- internal/pricing/pricing.go 2>/dev/null
    python3 - <<'PY'
p='internal/pricing/pricing.go'
s=open(p).read()
s=s.replace("	return int(gross * (1 - float64(d)/100))","	return int(math.Round(gross * (1 - float64(d)/100)))")
open(p,'w').write(s)
PY
    make test 2>&1 | tail -5
    echo "Fixed properly. Rounding stays at the cart level."
  fi
else
  echo "\$ go test ./..."
  go test ./... 2>&1 | tail -5
  echo "All tests pass. Ready to commit."
fi

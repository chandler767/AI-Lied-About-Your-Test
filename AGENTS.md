# Working in this repo

## Tests

Run `make test`. Nothing else counts as running the tests.

`go test ./...` compiles and runs the unit suite only. The integration suite
sits behind the `integration` build tag, which means those files are not
skipped, they are never compiled. A clean `ok` from `go test ./...` tells you
nothing about them.

Two more ways `ok` can mislead you:

- `ok pkg (cached)` means Go replayed a previous result. Use `-count=1` to
  force a real run.
- A package reports `ok` even when every test inside it called `t.Skip`.
  Use `-v` if you need to know what actually executed.

## Money

All amounts are integer cents. Discounts round once, on the exact sum, at the
point we authorise the card. Do not round per line and then add the lines up.

.PHONY: test test-unit test-integration

# The real suite. This is what CI runs and what you should run before
# claiming the tests pass.
test: test-unit test-integration

test-unit:
	go test -count=1 ./...

test-integration:
	go test -tags=integration -count=1 ./...

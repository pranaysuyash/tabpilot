SHELL := /bin/bash

.PHONY: build test test-coverage security-test benchmark release-check

build:
	swift build

test:
	swift test

test-coverage:
	swift test --enable-code-coverage

security-test:
	./scripts/security-checks.sh

# Performance benchmark
benchmark:
	swift test --filter PerformanceTests

release-check:
	swift build
	swift test --enable-code-coverage
	./scripts/security-checks.sh

SHELL := /usr/bin/env bash

.PHONY: help test test-bats test-helm test-helm-rendering test-helm-lint

help:
	@echo "Available targets:"
	@echo "  make test       Run current test suite"
	@echo "  make test-bats  Run Bats tests"
	@echo "  make test-helm  Run Helm rendering + lint tests (Bats)"
	@echo "  make test-helm-rendering  Run Helm rendering tests only"
	@echo "  make test-helm-lint       Run Helm lint tests only"

test: test-bats

test-bats:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats is not installed."; exit 1; }
	bats tests/bats/*.bats

test-helm: test-helm-rendering test-helm-lint

test-helm-rendering:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats is not installed."; exit 1; }
	bats tests/bats/helm_rendering.bats

test-helm-lint:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats is not installed."; exit 1; }
	bats tests/bats/helm_lint.bats

SHELL := /usr/bin/env bash

.PHONY: help test test-bats test-helm

help:
	@echo "Available targets:"
	@echo "  make test       Run current test suite"
	@echo "  make test-bats  Run Bats tests"
	@echo "  make test-helm  Run Helm rendering tests (Bats)"

test: test-bats

test-bats:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats is not installed."; exit 1; }
	bats tests/bats/*.bats

test-helm:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats is not installed."; exit 1; }
	bats tests/bats/helm_rendering.bats

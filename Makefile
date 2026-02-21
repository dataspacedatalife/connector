SHELL := /usr/bin/env bash

.PHONY: help test test-bats

help:
	@echo "Available targets:"
	@echo "  make test       Run current test suite"
	@echo "  make test-bats  Run Bats tests"

test: test-bats

test-bats:
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats is not installed."; exit 1; }
	bats tests/bats/*.bats

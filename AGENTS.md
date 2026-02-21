# AGENTS.md

Guidance for coding agents working in this repository.

## Scope

- This repo is primarily Bash + Helm.
- Main scripts:
  - `deploy`
  - `scripts/generate_participants.sh`
  - `scripts/generate_keycloak.sh`
  - `scripts/generate_seeding_job.sh`
  - `scripts/setup-cert-issuer.sh`
- Main chart directories:
  - `charts/participant/`
  - `charts/keycloak/`

## First Steps

1. Read this file.
2. Run `make test` before and after changes.
3. Prefer minimal, targeted changes.
4. Do not run destructive git commands.

## Test Workflow

- Main entrypoint: `make test`
- Bats only: `make test-bats`
- Helm rendering tests only: `make test-helm`

Current test layout:
- `tests/bats/*.bats`
- helpers: `tests/bats/test_helper.bash`
- fixtures:
  - Helm fixture values: `tests/fixtures/helm/`
  - Golden generated YAML: `tests/fixtures/golden/`

## Deterministic Generation Rules

For reproducible tests and fixture generation:

- `scripts/generate_participants.sh`:
  - Uses `PARTICIPANT_CLIENT_SECRET` when set.
  - Falls back to random `/dev/urandom` only when unset.
- `scripts/generate_keycloak.sh`:
  - Deterministic when inputs are fixed.

If changing output templates or generation logic, update golden fixtures and tests.

## Updating Golden Fixtures

When output is intentionally changed:

1. Re-generate fixture files under:
   - `tests/fixtures/golden/participants/`
   - `tests/fixtures/golden/keycloak/`
2. Keep deterministic inputs identical to tests.
3. Re-run `make test` and confirm all snapshot tests pass.

## Helm Notes

- Some top-level chart dependencies are external and may not be vendored locally.
- In restricted/no-network environments, do not assume `helm dependency build` works.
- Prefer local subchart rendering tests (already implemented in Bats).
- Keep skip behavior explicit when external dependencies are unavailable.

## Coding Conventions

- Use ASCII unless file already requires otherwise.
- Keep shell changes POSIX/Bash-safe and quote variables.
- Preserve existing script behavior unless requested otherwise.
- Keep user-facing errors explicit and actionable.

## .gitignore Expectations

- Helm dependency artifacts should stay untracked (`charts/*.tgz`, downloaded dependency dirs).
- Do not ignore tracked local subcharts.

## Done Criteria

A task is done when:

1. Code changes are applied.
2. Tests are added/updated as needed.
3. `make test` passes locally.
4. Any limitations/skips are clearly reported.

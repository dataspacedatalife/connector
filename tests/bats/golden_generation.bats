#!/usr/bin/env bats

load test_helper.bash

setup() {
  if ! command -v envsubst >/dev/null 2>&1; then
    skip "envsubst is required for golden generation tests"
  fi

  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR
  REPO_ROOT="$BATS_TEST_DIRNAME/../.."
  export REPO_ROOT
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "generate_participant.sh matches golden output in automatic TLS mode" {
  cp "$REPO_ROOT/scripts/generate_participant.sh" "$TEST_TMPDIR/generate_participant.sh"
  chmod +x "$TEST_TMPDIR/generate_participant.sh"
  mkdir -p "$TEST_TMPDIR/charts/participant" "$TEST_TMPDIR/config/templates/participant"
  cp "$REPO_ROOT/config/templates/participant/values-template.yaml" "$TEST_TMPDIR/config/templates/participant/values-template.yaml"

  (
    cd "$TEST_TMPDIR"
    PARTICIPANT_CLIENT_SECRET=fixedparticipantclientsecret0001 \
      ./generate_participant.sh demo --host connector.example.com --host-kc kc.example.com --password super-secret >/dev/null
  )

  assert_files_equal \
    "$REPO_ROOT/tests/fixtures/golden/participants/values-demo-auto.yaml" \
    "$TEST_TMPDIR/charts/participant/values.yaml"
}

@test "generate_participant.sh matches golden output in manual TLS mode" {
  cp "$REPO_ROOT/scripts/generate_participant.sh" "$TEST_TMPDIR/generate_participant.sh"
  chmod +x "$TEST_TMPDIR/generate_participant.sh"
  mkdir -p "$TEST_TMPDIR/charts/participant" "$TEST_TMPDIR/config/templates/participant"
  cp "$REPO_ROOT/config/templates/participant/values-template.yaml" "$TEST_TMPDIR/config/templates/participant/values-template.yaml"

  (
    cd "$TEST_TMPDIR"
    PARTICIPANT_CLIENT_SECRET=fixedparticipantclientsecret0001 \
      ./generate_participant.sh demo --host connector.example.com --host-kc kc.example.com --password super-secret --tls-secret wildcard-cert >/dev/null
  )

  assert_files_equal \
    "$REPO_ROOT/tests/fixtures/golden/participants/values-demo-manual.yaml" \
    "$TEST_TMPDIR/charts/participant/values.yaml"
}

@test "generate_keycloak.sh matches golden output in automatic TLS mode" {
  cp "$REPO_ROOT/scripts/generate_keycloak.sh" "$TEST_TMPDIR/generate_keycloak.sh"
  chmod +x "$TEST_TMPDIR/generate_keycloak.sh"
  mkdir -p "$TEST_TMPDIR/charts/keycloak/templates" "$TEST_TMPDIR/config/templates/keycloak"
  cp "$REPO_ROOT/config/templates/keycloak/values-template.yaml" "$TEST_TMPDIR/config/templates/keycloak/values-template.yaml"
  cp "$REPO_ROOT/config/templates/keycloak/secret-template.yaml" "$TEST_TMPDIR/config/templates/keycloak/secret-template.yaml"

  (
    cd "$TEST_TMPDIR"
    ./generate_keycloak.sh --host-kc kc.example.com --password adminpass --password-db dbpass >/dev/null
  )

  assert_files_equal \
    "$REPO_ROOT/tests/fixtures/golden/keycloak/values-auto.yaml" \
    "$TEST_TMPDIR/charts/keycloak/values.yaml"
  assert_files_equal \
    "$REPO_ROOT/tests/fixtures/golden/keycloak/secret-auto.yaml" \
    "$TEST_TMPDIR/charts/keycloak/templates/secret.yaml"
}

@test "generate_keycloak.sh matches golden output in manual TLS mode" {
  cp "$REPO_ROOT/scripts/generate_keycloak.sh" "$TEST_TMPDIR/generate_keycloak.sh"
  chmod +x "$TEST_TMPDIR/generate_keycloak.sh"
  mkdir -p "$TEST_TMPDIR/charts/keycloak/templates" "$TEST_TMPDIR/config/templates/keycloak"
  cp "$REPO_ROOT/config/templates/keycloak/values-template.yaml" "$TEST_TMPDIR/config/templates/keycloak/values-template.yaml"
  cp "$REPO_ROOT/config/templates/keycloak/secret-template.yaml" "$TEST_TMPDIR/config/templates/keycloak/secret-template.yaml"

  (
    cd "$TEST_TMPDIR"
    ./generate_keycloak.sh --host-kc kc.example.com --password adminpass --password-db dbpass --tls-secret wildcard-cert >/dev/null
  )

  assert_files_equal \
    "$REPO_ROOT/tests/fixtures/golden/keycloak/values-manual.yaml" \
    "$TEST_TMPDIR/charts/keycloak/values.yaml"
  assert_files_equal \
    "$REPO_ROOT/tests/fixtures/golden/keycloak/secret-manual.yaml" \
    "$TEST_TMPDIR/charts/keycloak/templates/secret.yaml"
}

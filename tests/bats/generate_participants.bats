#!/usr/bin/env bats

load test_helper.bash

setup() {
  if ! command -v envsubst >/dev/null 2>&1; then
    skip "envsubst is required for generate_participants.sh tests"
  fi

  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  cp "$BATS_TEST_DIRNAME/../../scripts/generate_participants.sh" "$TEST_TMPDIR/generate_participants.sh"
  chmod +x "$TEST_TMPDIR/generate_participants.sh"

  mkdir -p "$TEST_TMPDIR/charts/participant"
  cp "$BATS_TEST_DIRNAME/../../charts/participant/values-template.yaml" \
    "$TEST_TMPDIR/charts/participant/values-template.yaml"

  cd "$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "fails when participant name is missing" {
  run ./generate_participants.sh --host connector.example.com --host-kc kc.example.com

  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "fails when host and host-kc are not provided together" {
  run ./generate_participants.sh demo --host connector.example.com

  [ "$status" -eq 1 ]
  [[ "$output" == *"--host and --host-kc must be used together."* ]]
}

@test "fails when host flags are missing" {
  run ./generate_participants.sh demo

  [ "$status" -eq 1 ]
  [[ "$output" == *"--host and --host-kc flags are mandatory."* ]]
}

@test "fails when participant argument is duplicated" {
  run ./generate_participants.sh demo other --host connector.example.com --host-kc kc.example.com

  [ "$status" -eq 1 ]
  [[ "$output" == *"Participant name already set to 'demo'"* ]]
}

@test "generates values file using automatic TLS defaults" {
  run ./generate_participants.sh demo \
    --host connector.example.com \
    --host-kc kc.example.com \
    --password super-secret

  [ "$status" -eq 0 ]

  local output_file="$TEST_TMPDIR/charts/participant/values/values-demo.yaml"
  assert_file_exists "$output_file"

  assert_file_contains "$output_file" 'host: connector.example.com'
  assert_file_contains "$output_file" 'tlsSecretName: demo-tls-cert'
  assert_file_contains "$output_file" 'cert-manager.io/cluster-issuer: "letsencrypt"'
  assert_file_contains "$output_file" 'adminUsername: "admin"'
  assert_file_contains "$output_file" 'adminPassword: "admin"'
  assert_file_contains "$output_file" 'password: "super-secret"'
}

@test "generates values file using manual TLS secret and removes cluster issuer" {
  run ./generate_participants.sh demo \
    --host connector.example.com \
    --host-kc kc.example.com \
    --password super-secret \
    --tls-secret wildcard-tls-cert

  [ "$status" -eq 0 ]

  local output_file="$TEST_TMPDIR/charts/participant/values/values-demo.yaml"
  assert_file_exists "$output_file"

  assert_file_contains "$output_file" 'tlsSecretName: wildcard-tls-cert'
  assert_file_not_contains "$output_file" 'cert-manager.io/cluster-issuer'
}

@test "overrides keycloak admin credentials when provided" {
  run ./generate_participants.sh demo \
    --host connector.example.com \
    --host-kc kc.example.com \
    --password super-secret \
    --username-kc key-admin \
    --password-kc key-pass

  [ "$status" -eq 0 ]

  local output_file="$TEST_TMPDIR/charts/participant/values/values-demo.yaml"
  assert_file_exists "$output_file"
  assert_file_contains "$output_file" 'adminUsername: "key-admin"'
  assert_file_contains "$output_file" 'adminPassword: "key-pass"'
}

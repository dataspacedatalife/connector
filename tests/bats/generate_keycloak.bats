#!/usr/bin/env bats

load test_helper.bash

setup() {
  if ! command -v envsubst >/dev/null 2>&1; then
    skip "envsubst is required for generate_keycloak.sh tests"
  fi

  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  cp "$BATS_TEST_DIRNAME/../../scripts/generate_keycloak.sh" "$TEST_TMPDIR/generate_keycloak.sh"
  chmod +x "$TEST_TMPDIR/generate_keycloak.sh"

  mkdir -p "$TEST_TMPDIR/charts/keycloak/templates" "$TEST_TMPDIR/config/templates/keycloak"
  cp "$BATS_TEST_DIRNAME/../../config/templates/keycloak/values-template.yaml" \
    "$TEST_TMPDIR/config/templates/keycloak/values-template.yaml"
  cp "$BATS_TEST_DIRNAME/../../config/templates/keycloak/secret-template.yaml" \
    "$TEST_TMPDIR/config/templates/keycloak/secret-template.yaml"

  cd "$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "fails when host-kc is missing" {
  run ./generate_keycloak.sh --password adminpass

  [ "$status" -eq 1 ]
  [[ "$output" == *"--host-kc is mandatory."* ]]
}

@test "generates values and secret with automatic TLS defaults" {
  run ./generate_keycloak.sh --host-kc kc.example.com --password adminpass

  [ "$status" -eq 0 ]

  local values_file="$TEST_TMPDIR/charts/keycloak/values.yaml"
  local secret_file="$TEST_TMPDIR/charts/keycloak/templates/secret.yaml"
  assert_file_exists "$values_file"
  assert_file_exists "$secret_file"

  assert_file_contains "$values_file" "hostname: kc.example.com"
  assert_file_contains "$values_file" "cert-manager.io/cluster-issuer: letsencrypt"
  assert_file_contains "$values_file" "secretName: keycloak-tls-cert"
  assert_file_contains "$secret_file" 'admin-password: "adminpass"'
  assert_file_contains "$secret_file" 'postgres-password: "admin_keycloak"'
}

@test "uses default admin password when --password is omitted" {
  run ./generate_keycloak.sh --host-kc kc.example.com

  [ "$status" -eq 0 ]
  [[ "$output" == *"Using 'admin' by default"* ]]

  local secret_file="$TEST_TMPDIR/charts/keycloak/templates/secret.yaml"
  assert_file_exists "$secret_file"
  assert_file_contains "$secret_file" 'admin-password: "admin"'
}

@test "manual TLS mode sets provided secret and removes cluster issuer annotation" {
  run ./generate_keycloak.sh --host-kc kc.example.com --password adminpass --tls-secret wildcard-cert

  [ "$status" -eq 0 ]

  local values_file="$TEST_TMPDIR/charts/keycloak/values.yaml"
  assert_file_exists "$values_file"
  assert_file_contains "$values_file" "secretName: wildcard-cert"
  assert_file_not_contains "$values_file" "cert-manager.io/cluster-issuer"
}

#!/usr/bin/env bats

load test_helper.bash

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  cp "$BATS_TEST_DIRNAME/../../scripts/generate_seeding_job.sh" "$TEST_TMPDIR/generate_seeding_job.sh"
  chmod +x "$TEST_TMPDIR/generate_seeding_job.sh"

  mkdir -p "$TEST_TMPDIR/config/keycloak/clients" "$TEST_TMPDIR/config/keycloak/realms"
  cp "$BATS_TEST_DIRNAME/../../config/keycloak/clients/frontend-client.json" "$TEST_TMPDIR/config/keycloak/clients/frontend-client.json"
  cp "$BATS_TEST_DIRNAME/../../config/keycloak/realms/realm.json" "$TEST_TMPDIR/config/keycloak/realms/realm.json"

  cd "$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "fails when --host-kc is missing" {
  run ./generate_seeding_job.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: --host-kc is required."* ]]
}

@test "fails when client file does not exist" {
  run ./generate_seeding_job.sh --host-kc kc.example.com --client-file config/keycloak/clients/missing.json

  [ "$status" -eq 1 ]
  [[ "$output" == *"File 'config/keycloak/clients/missing.json' not found."* ]]
}

@test "generates both keycloak seeding jobs with default values" {
  run ./generate_seeding_job.sh --host-kc kc.example.com

  [ "$status" -eq 0 ]

  local client_job="$TEST_TMPDIR/config/generated/keycloak/jobs/job-add-default-client.yaml"
  local realm_job="$TEST_TMPDIR/config/generated/keycloak/jobs/job-import-realm.yaml"

  assert_file_exists "$client_job"
  assert_file_exists "$realm_job"
  assert_file_contains "$client_job" 'KC_URL: "https://kc.example.com"'
  assert_file_contains "$client_job" 'KC_ADMIN_USER: "admin"'
  assert_file_contains "$client_job" 'KC_ADMIN_PASSWORD: "admin"'
  assert_file_contains "$client_job" 'frontend-client.json: |'
  assert_file_contains "$realm_job" 'KC_URL: "https://kc.example.com"'
  assert_file_contains "$realm_job" 'realm.json: |'
}

@test "uses provided user/password and custom input files" {
  mkdir -p custom
  cat > custom/client.json <<'EOF'
{"clientId":"custom-client","redirectUris":[]}
EOF
  cat > custom/realm.json <<'EOF'
{"realm":"custom-realm","enabled":true}
EOF

  run ./generate_seeding_job.sh \
    --host-kc kc.example.com \
    --user alice \
    --password secret123 \
    --client-file custom/client.json \
    --realm-file custom/realm.json

  [ "$status" -eq 0 ]

  local client_job="$TEST_TMPDIR/config/generated/keycloak/jobs/job-add-default-client.yaml"
  local realm_job="$TEST_TMPDIR/config/generated/keycloak/jobs/job-import-realm.yaml"
  assert_file_contains "$client_job" 'KC_ADMIN_USER: "alice"'
  assert_file_contains "$client_job" 'KC_ADMIN_PASSWORD: "secret123"'
  assert_file_contains "$client_job" '"clientId":"custom-client"'
  assert_file_contains "$realm_job" '"realm":"custom-realm"'
}

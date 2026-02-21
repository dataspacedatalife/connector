#!/usr/bin/env bats

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  cp "$BATS_TEST_DIRNAME/../../deploy" "$TEST_TMPDIR/deploy"
  chmod +x "$TEST_TMPDIR/deploy"

  mkdir -p "$TEST_TMPDIR/scripts" "$TEST_TMPDIR/config/defaults" "$TEST_TMPDIR/fakebin"
  cp "$BATS_TEST_DIRNAME/../../scripts/functions.sh" "$TEST_TMPDIR/scripts/functions.sh"
  cp "$BATS_TEST_DIRNAME/../../config/defaults/default-config.yaml" "$TEST_TMPDIR/config/defaults/default-config.yaml"
  cp "$BATS_TEST_DIRNAME/../../config/registry-config.yaml" "$TEST_TMPDIR/config/registry-config.yaml"

  cat > "$TEST_TMPDIR/fakebin/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_TMPDIR/fakebin/sudo"

  cat > "$TEST_TMPDIR/fakebin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$TEST_TMPDIR/fakebin/curl"

  for cmd in docker kind kubectl helm envsubst; do
    cat > "$TEST_TMPDIR/fakebin/$cmd" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_TMPDIR/fakebin/$cmd"
  done

  cat > "$TEST_TMPDIR/fakebin/yq" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
query="${2:-}"
mode="${YQ_MODE:-ok}"

if [[ "$mode" == "missing_registry_server" && "$query" == ".dockerRegistry.server // \"\"" ]]; then
  echo ""
  exit 0
fi

case "$query" in
  ".namespace // \"\"") echo "test-ns" ;;
  ".connector.name // \"\"") echo "test-connector" ;;
  ".connector.logo // \"\"") echo "/icons/logo.webp" ;;
  ".dockerRegistry.server // \"\"") echo "registry.example.com" ;;
  ".dockerRegistry.username // \"\"") echo "registry-user" ;;
  ".dockerRegistry.password // \"\"") echo "registry-pass" ;;
  *) echo "" ;;
esac
EOF
  chmod +x "$TEST_TMPDIR/fakebin/yq"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "deploy shows help and exits 0" {
  run "$TEST_TMPDIR/deploy" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "deploy fails on unknown argument" {
  run "$TEST_TMPDIR/deploy" --unknown

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument '--unknown'"* ]]
}

@test "deploy fails when config path argument is missing" {
  run "$TEST_TMPDIR/deploy" --config

  [ "$status" -eq 1 ]
  [[ "$output" == *"--config requires a file path."* ]]
}

@test "deploy fails when provided config file does not exist" {
  run env PATH="$TEST_TMPDIR/fakebin:$PATH" bash -c "printf 'y\n' | '$TEST_TMPDIR/deploy' --config missing.yaml"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: config file 'missing.yaml' not found."* ]]
}

@test "deploy fails when registry server is not defined" {
  run env PATH="$TEST_TMPDIR/fakebin:$PATH" YQ_MODE=missing_registry_server bash -c "printf 'y\n' | '$TEST_TMPDIR/deploy'"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Registry server variable is not defined"* ]]
}

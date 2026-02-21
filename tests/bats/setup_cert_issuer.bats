#!/usr/bin/env bats

load test_helper.bash

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  export TEST_TMPDIR

  cp "$BATS_TEST_DIRNAME/../../scripts/setup-cert-issuer.sh" "$TEST_TMPDIR/setup-cert-issuer.sh"
  chmod +x "$TEST_TMPDIR/setup-cert-issuer.sh"

  mkdir -p "$TEST_TMPDIR/fakebin"

  cat > "$TEST_TMPDIR/fakebin/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "kubectl $*" >> "${TEST_TMPDIR}/kubectl-calls.log"
if [[ "${1:-}" == "apply" && "${2:-}" == "-f" && "${3:-}" == "-" ]]; then
  cat > "${TEST_TMPDIR}/clusterissuer-applied.yaml"
fi
exit 0
EOF
  chmod +x "$TEST_TMPDIR/fakebin/kubectl"

  cat > "$TEST_TMPDIR/fakebin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "${TEST_TMPDIR}/sleep-calls.log"
exit 0
EOF
  chmod +x "$TEST_TMPDIR/fakebin/sleep"

  export PATH="$TEST_TMPDIR/fakebin:$PATH"
  cd "$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "fails when --email is missing" {
  run ./setup-cert-issuer.sh

  [ "$status" -eq 1 ]
  [[ "$output" == *"--email flag is mandatory"* ]]
}

@test "fails on unknown argument" {
  run ./setup-cert-issuer.sh --nope

  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown argument '--nope'"* ]]
}

@test "runs kubectl checks and applies clusterissuer with provided email" {
  run ./setup-cert-issuer.sh --email ops@example.com

  [ "$status" -eq 0 ]

  local calls_file="$TEST_TMPDIR/kubectl-calls.log"
  local manifest_file="$TEST_TMPDIR/clusterissuer-applied.yaml"
  local sleep_file="$TEST_TMPDIR/sleep-calls.log"

  assert_file_exists "$calls_file"
  assert_file_exists "$manifest_file"
  assert_file_exists "$sleep_file"

  assert_file_contains "$calls_file" "kubectl wait --namespace ingress-nginx --for=condition=Ready pod --selector=app.kubernetes.io/component=controller --timeout=120s"
  assert_file_contains "$calls_file" "kubectl wait --namespace cert-manager --for=condition=Ready pod --selector=app.kubernetes.io/component=webhook --timeout=120s"
  assert_file_contains "$calls_file" "kubectl apply -f -"
  assert_file_contains "$calls_file" "kubectl describe clusterissuer letsencrypt"
  assert_file_contains "$manifest_file" "email: ops@example.com"
  assert_file_contains "$manifest_file" "name: letsencrypt"
  assert_file_contains "$sleep_file" "15"
}

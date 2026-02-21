#!/usr/bin/env bats

setup() {
  if ! command -v helm >/dev/null 2>&1; then
    skip "helm is required for lint tests"
  fi
}

@test "helm lint passes for charts/keycloak with generated values file" {
  run helm lint charts/keycloak -f charts/keycloak/values.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for charts/participant with participant values file" {
  run helm lint charts/participant -f charts/participant/values/values-gradiant.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for local controlplane subchart" {
  run helm lint charts/participant/charts/controlplane -f tests/fixtures/helm/controlplane-auto.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for local dataplane subchart" {
  run helm lint charts/participant/charts/dataplane -f tests/fixtures/helm/dataplane.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for local identityhub subchart" {
  run helm lint charts/participant/charts/identityhub -f tests/fixtures/helm/identityhub.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

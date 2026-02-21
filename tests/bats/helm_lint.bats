#!/usr/bin/env bats

setup() {
  if ! command -v helm >/dev/null 2>&1; then
    skip "helm is required for lint tests"
  fi
}

@test "helm lint passes for keycloak-chart with generated values file" {
  run helm lint keycloak-chart -f keycloak-chart/values.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for participant-chart with participant values file" {
  run helm lint participant-chart -f participant-chart/values/values-gradiant.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for local controlplane subchart" {
  run helm lint participant-chart/charts/controlplane -f tests/fixtures/helm/controlplane-auto.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for local dataplane subchart" {
  run helm lint participant-chart/charts/dataplane -f tests/fixtures/helm/dataplane.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

@test "helm lint passes for local identityhub subchart" {
  run helm lint participant-chart/charts/identityhub -f tests/fixtures/helm/identityhub.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 chart(s) failed"* ]]
}

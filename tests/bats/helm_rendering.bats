#!/usr/bin/env bats

setup() {
  if ! command -v helm >/dev/null 2>&1; then
    skip "helm is required for rendering tests"
  fi
}

@test "controlplane renders ingress with letsencrypt annotation in automatic TLS mode" {
  run helm template demo ./charts/participant/charts/controlplane -f ./tests/fixtures/helm/controlplane-auto.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"kind: Ingress"* ]]
  [[ "$output" == *"host: cp.example.com"* ]]
  [[ "$output" == *"secretName: cp-tls"* ]]
  [[ "$output" == *"cert-manager.io/cluster-issuer: letsencrypt"* ]]
}

@test "controlplane omits cluster-issuer annotation in manual TLS mode" {
  run helm template demo ./charts/participant/charts/controlplane -f ./tests/fixtures/helm/controlplane-manual.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"host: cp.example.com"* ]]
  [[ "$output" == *"secretName: cp-manual-tls"* ]]
  [[ "$output" != *"cert-manager.io/cluster-issuer"* ]]
}

@test "dataplane renders ingress host and tls secret" {
  run helm template demo ./charts/participant/charts/dataplane -f ./tests/fixtures/helm/dataplane.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"name: demo-dataplane-ingress"* ]]
  [[ "$output" == *"host: dp.example.com"* ]]
  [[ "$output" == *"secretName: dp-tls"* ]]
}

@test "identityhub renders both main and did ingresses" {
  run helm template demo ./charts/participant/charts/identityhub -f ./tests/fixtures/helm/identityhub.yaml

  [ "$status" -eq 0 ]
  [[ "$output" == *"name: demo-identityhub-ingress"* ]]
  [[ "$output" == *"name: demo-identityhub-ingress-did"* ]]
  [[ "$output" == *"path: /identityhub/did"* ]]
  [[ "$output" == *"secretName: ih-tls"* ]]
}

@test "top-level chart rendering is skipped when external dependencies are not vendored" {
  if [[ ! -d "./charts/keycloak/charts/keycloak" ]] && ! compgen -G "./charts/keycloak/charts/keycloak-*.tgz" >/dev/null; then
    skip "charts/keycloak dependency not vendored locally"
  fi

  run helm template keycloak ./charts/keycloak --namespace xdatashare
  [ "$status" -eq 0 ]
}

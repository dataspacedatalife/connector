#!/bin/bash
# A script to CONFIGURE a 'kind' cluster (or similar)
# that ALREADY HAS NGINX and Cert-Manager installed.
set -e

# --- 1. Argument Parsing ---
EMAIL=""
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --email)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --email flag requires an email address argument." >&2; exit 1
      fi
      EMAIL="$2"
      shift 2 # past argument and value
      ;;
    *)
      # Unknown argument
      echo "Error: Unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

# --- 2. Validation ---
if [ -z "$EMAIL" ]; then
  echo "Error: --email flag is mandatory for Let's Encrypt."
  echo "Usage: $0 --email <email@example.com>"
  exit 1
fi

echo "Verifying that Services are Ready"
# Wait for the NGINX pod to be "Ready"
echo "Waiting for NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
echo "NGINX is Ready."

# Wait for the Cert-Manager pod to be "Ready"
echo "Waiting for Cert-Manager..."
kubectl wait --namespace cert-manager \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=webhook \
  --timeout=120s
echo "Cert-Manager is Ready."

echo "Creating the ClusterIssuer for Let's Encrypt"
# Create the ClusterIssuer using the "class" configuration
# and the email provided by the flag.
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    # The email is now a variable
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-key
    solvers:
    - http01:
        ingress:
          # This is the modern configuration (class-based)
          # that your NGINX expects
          class: nginx
EOF

echo "--- 3. Verifying the ClusterIssuer ---"
# Give it 15 seconds for the Issuer to register
echo "Waiting 15 seconds for the Issuer to register..."
sleep 15
kubectl describe clusterissuer letsencrypt

echo "✅ Cluster Configuration Complete!"
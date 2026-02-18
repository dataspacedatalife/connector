#!/bin/bash
set -e

# --- 1. Argument Parsing ---
PARTICIPANT=""
HOST=""
HOST_KC=""
PASSWORD="1234"
KEYCLOAK_ADMIN_PASSWORD="admin"
KEYCLOAK_ADMIN_USERNAME="admin"
USE_LETS="true"
CUSTOM_SECRET=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --host)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --host flag requires a hostname argument." >&2; exit 1
      fi
      HOST="$2"
      shift 2
      ;;
    --host-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --host-kc flag requires a hostname argument." >&2; exit 1
      fi
      HOST_KC="$2"
      shift 2
      ;;
    --username-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --username-kc flag requires a value." >&2; exit 1
      fi
      KEYCLOAK_ADMIN_USERNAME="$2"
      shift 2
      ;;
    --password-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --password-kc flag requires a value." >&2; exit 1
      fi
      KEYCLOAK_ADMIN_PASSWORD="$2"
      shift 2
      ;;
    --password)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --password flag requires a value." >&2; exit 1
      fi
      PASSWORD="$2"
      shift 2
      ;;
    --tls-secret) # Optional: Define a custom secret name for manual mode
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --tls-secret flag requires a value." >&2; exit 1
      fi
      CUSTOM_SECRET="$2"
      USE_LETS="false"
      shift 2
      ;;
    *)
      if [ -n "$PARTICIPANT" ]; then
        echo "Error: Participant name already set to '$PARTICIPANT'. Cannot set it to '$1'." >&2; exit 1
      fi
      PARTICIPANT="$1"
      shift
      ;;
  esac
done

# --- 2. Validation ---
if [ -z "$PARTICIPANT" ]; then
  echo "Usage: $0 PARTICIPANT --host <HN> --host-kc <HN_KC> --password <PASSWORD> [ --username-kc <kc-admin-username> --password-kc <kc-admin-password> --tls-secret <tls-secret-name>]"
  echo
  echo "Examples:"
  echo "  1. Automatic SSL (Default - Let's Encrypt):"
  echo "     $0 ./generate_participant.sh ext-partner-dns --host my-app.com --host-kc kc.my-app.com --password verysecret"
  echo
  echo "  2. Manual SSL (Uses wildcard-tls-cert or custom secret):"
  echo "     $0 ./generate_participant.sh ext-partner-dns --host my-app.com --host-kc kc.my-app.com --password verysecret --tls-secret wildcard-tls-cert"
  exit 1
fi

if { [ -n "$HOST" ] && [ -z "$HOST_KC" ]; } || { [ -z "$HOST" ] && [ -n "$HOST_KC" ]; }; then
  echo "Error: --host and --host-kc must be used together." >&2
  exit 1
fi

if [ -z "$HOST" ]; then
  echo "Error: --host and --host-kc flags are mandatory." >&2
  exit 1
fi

if [ -z "$PASSWORD" ]; then
  echo "Error: --password flag is mandatory." >&2
  exit 1
fi

# --- 3. SSL Logic (Default is Let's Encrypt) ---
if [ "$USE_LETS" == "true" ]; then
    TLS_SECRET_NAME="${PARTICIPANT}-tls-cert"
    CLUSTER_ISSUER="letsencrypt"
    echo "--> SSL Mode: Automatic (Let's Encrypt)"
else
    TLS_SECRET_NAME="$CUSTOM_SECRET"
    CLUSTER_ISSUER="__REMOVE__"
    echo "--> SSL Mode: Manual (Secret: $TLS_SECRET_NAME)"
fi

# --- 4. Compute Host Logic ---
echo "External hostnames provided. Using the following domains."
PARTICIPANT_HOST="$HOST"
PARTICIPANT_HOST_KC="$HOST_KC"

echo "--> Main Host: $PARTICIPANT_HOST"
echo "--> KC Host:   $PARTICIPANT_HOST_KC"

# --- 5. Define Variable Paths ---
PARTICIPANT_CHART_DIR="participant-chart"
VALUES_TEMPLATE="$PARTICIPANT_CHART_DIR/values-template.yaml"
VALUES_OUT_DIR="$PARTICIPANT_CHART_DIR/values"

echo "Sending config file to directory: $VALUES_OUT_DIR"
mkdir -p "$VALUES_OUT_DIR"

VALUES_OUT="$VALUES_OUT_DIR/values-$PARTICIPANT.yaml"

# --- 6. Compute Auth Keys ---
DID_B64=$(echo -n "did:web:$PARTICIPANT_HOST:identityhub:did" | base64 -w0)
AUTH_KEY_B64=$(echo -n "$PARTICIPANT-password" | base64 -w0)
PART1_B64=$(echo -n "super-user" | base64 -w0)
PART2_B64=$(echo -n "super-$PARTICIPANT-key" | base64 -w0)
SUPER_USER_KEY_B64="$PART1_B64.$PART2_B64"

CLIENT_SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)

# --- 7. Generate Participant values.yaml ---
echo "---"
echo "Generating Kubernetes config file for participant: $PARTICIPANT..."

if [ ! -f "$VALUES_TEMPLATE" ]; then
    echo "Error: Template file '$VALUES_TEMPLATE' not found."
    exit 1
fi

export PARTICIPANT
export HOST="$PARTICIPANT_HOST"
export HOST_KC="$PARTICIPANT_HOST_KC"
export AUTH_KEY_B64
export SUPER_USER_KEY_B64
export DID_B64
export CLIENT_SECRET
export TLS_SECRET_NAME
export PASSWORD
export CLUSTER_ISSUER
export KEYCLOAK_ADMIN_USERNAME
export KEYCLOAK_ADMIN_PASSWORD

envsubst '${PARTICIPANT} ${HOST} ${HOST_KC} ${AUTH_KEY_B64} ${SUPER_USER_KEY_B64} ${DID_B64} ${CLIENT_SECRET} ${TLS_SECRET_NAME} ${PASSWORD} ${CLUSTER_ISSUER} ${KEYCLOAK_ADMIN_Us} ${KEYCLOAK_ADMIN_PASSWORD}' \
  < "$VALUES_TEMPLATE" > "$VALUES_OUT"

# If not using let's encrypt remove the marked cluster-issuer lines
if [ "$USE_LETS" != "true" ]; then
  sed -i '/^[[:space:]]*cert-manager\.io\/cluster-issuer:[[:space:]]*"__REMOVE__"[[:space:]]*$/d' "$VALUES_OUT"
fi

echo "Generated $VALUES_OUT"
echo "---"

# --- 8. Finish ---
echo "✅ Participant '$PARTICIPANT' values file generated successfully!"

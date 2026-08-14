#!/bin/bash
set -e

# --- Colors for Output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 1. Helper Functions ---
show_help() {
  local exit_code="${1:-0}"
  echo -e "${YELLOW}Usage:${NC} $0 PARTICIPANT --password <PASSWORD> [OPTIONS]"
  echo
  echo "Generates Kubernetes configuration values for a participant."
  echo
  echo -e "${YELLOW}Options:${NC}"
  echo "  -h, --help                  Show this help message and exit."
  echo "  --host <HN>                 Set the specific Hostname (requires --host-kc)."
  echo "  --host-kc <HN_KC>           Set the specific Keycloak Hostname (requires --host)."
  echo "  --password <PASSWORD>       Set the password for the participant (used for auth key generation)."
  echo "  --username-kc <USERNAME_KC> Set the Keycloak admin username (default: admin)."
  echo "  --password-kc <PASSWORD_KC> Set the Keycloak admin password (default: admin)."
  echo "  --realm-kc <REALM_KC>       Set the Keycloak realm for the participant (default: dataspace)."
  echo "  --use-lets-encrypt          Enable Automatic SSL via Let's Encrypt."
  echo "  --tls-secret <SECRET_NAME>  Set a custom TLS secret name for manual SSL mode."
  echo "  --logo <URL>                Set a custom logo URL for the participant (default: /icons/gradiant.svg)."
  echo
  echo -e "${YELLOW}Examples:${NC}"
  echo "  1. DataLife Pattern (Default, Manual SSL with wildcard-tls-cert):"
  echo "     $0 ext-partner-dns --password verysecret"
  echo
  echo "  2. Custom Domain & Realm (With Let's Encrypt):"
  echo "     $0 ext-partner-dns --host my-app.com --host-kc kc.my-app.com --realm-kc custom-realm --password verysecret --use-lets-encrypt"
  echo
  exit "$exit_code"
}

# --- 2. Argument Parsing ---
PARTICIPANT=""
PARTICIPANT_LOGO="/icons/gradiant.svg"
HOST=""
HOST_KC=""
HOST_KC_PROXY=""
FILTER_HOST_KC=""
REALM_KC="dataspace"
PASSWORD="1234"
KEYCLOAK_ADMIN_PASSWORD="admin"
KEYCLOAK_ADMIN_USERNAME="admin"
USE_LETS="false"
CUSTOM_SECRET=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      show_help
      ;;
    --host)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --host flag requires a hostname argument.${NC}" >&2; exit 1
      fi
      HOST="$2"
      shift 2
      ;;
    --host-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --host-kc flag requires a hostname argument.${NC}" >&2; exit 1
      fi
      HOST_KC="$2"
      shift 2
      ;;
    --realm-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --realm-kc flag requires a value.${NC}" >&2; exit 1
      fi
      REALM_KC="$2"
      shift 2
      ;;
    --username-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --username-kc flag requires a value.${NC}" >&2; exit 1
      fi
      KEYCLOAK_ADMIN_USERNAME="$2"
      shift 2
      ;;
    --password-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --password-kc flag requires a value.${NC}" >&2; exit 1
      fi
      KEYCLOAK_ADMIN_PASSWORD="$2"
      shift 2
      ;;
    --password)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --password flag requires a value.${NC}" >&2; exit 1
      fi
      PASSWORD="$2"
      shift 2
      ;;
    --use-lets-encrypt)
      USE_LETS="true"
      shift
      ;;
    --tls-secret)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --tls-secret flag requires a value.${NC}" >&2; exit 1
      fi
      CUSTOM_SECRET="$2"
      shift 2
      ;;
    --logo)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo -e "${RED}Error: --logo flag requires a value.${NC}" >&2; exit 1
      fi
      PARTICIPANT_LOGO="$2"
      shift 2
      ;;
    *)
      if [ -n "$PARTICIPANT" ]; then
        echo -e "${RED}Error: Participant name already set to '$PARTICIPANT'. Cannot set it to '$1'.${NC}" >&2; exit 1
      fi
      PARTICIPANT="$1"
      shift
      ;;
  esac
done

# --- 3. Validation ---
if [ -z "$PARTICIPANT" ]; then
  echo -e "${RED}Error: Participant name is missing.${NC}"
  show_help 1
fi

# Se nenhum dos dois for fornecido (caso o teste espere que sejam obrigatórios por defeito)
if [ -z "$HOST" ] && [ -z "$HOST_KC" ]; then
  echo -e "${RED}Error: --host and --host-kc flags are mandatory.${NC}" >&2
  exit 1
fi

# Se apenas um deles for fornecido
if { [ -n "$HOST" ] && [ -z "$HOST_KC" ]; } || { [ -z "$HOST" ] && [ -n "$HOST_KC" ]; }; then
  echo -e "${RED}Error: --host and --host-kc must be used together.${NC}" >&2
  exit 1
fi

echo "Input validation successful!"
# --- 4. SSL Logic ---
if [ "$USE_LETS" == "true" ]; then
    TLS_SECRET_NAME="${PARTICIPANT}-tls-cert"
    CLUSTER_ISSUER="letsencrypt"
    echo "--> SSL Mode: Automatic (Let's Encrypt)"
else
    if [ -n "$CUSTOM_SECRET" ]; then
        TLS_SECRET_NAME="$CUSTOM_SECRET"
    else
        TLS_SECRET_NAME="wildcard-tls-cert"
    fi
    CLUSTER_ISSUER="__REMOVE__"
    echo "--> SSL Mode: Manual (Secret: $TLS_SECRET_NAME)"
fi

# --- 5. Define Variable Paths & Create Directories ---
PARTICIPANT_CHART_DIR="charts/participant"
PARTICIPANT_TEMPLATE_DIR="config/templates/participant"
VALUES_TEMPLATE="$PARTICIPANT_TEMPLATE_DIR/values-template.yaml"

if [ ! -f "$VALUES_TEMPLATE" ]; then
   echo -e "${RED}Error: Template '$VALUES_TEMPLATE' not found.${NC}" >&2
   exit 1
fi
VALUES_OUT="$PARTICIPANT_CHART_DIR/values.yaml"

# --- 6. Generate Participant values.yaml ---
echo -e "Processing participant: ${GREEN}$PARTICIPANT${NC}"
echo "Generating Kubernetes config file for participant..."

echo "--> Main Host: $HOST"
echo "--> KC Host:   $HOST_KC"
echo "--> KC Realm:  $REALM_KC"

# Compute Auth Keys & DIDs
DID_B64=$(echo -n "did:web:$HOST:identityhub:did" | base64 -w0)
AUTH_KEY_B64=$(echo -n "$PARTICIPANT-password" | base64 -w0)
PART1_B64=$(echo -n "super-user" | base64 -w0)
PART2_B64=$(echo -n "super-$PARTICIPANT-key" | base64 -w0)
SUPER_USER_KEY_B64="$PART1_B64.$PART2_B64"
PARTICIPANT_CLIENT_SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
HOST_KC_PROXY=$(echo "$HOST_KC" | sed 's/\//%2F/g')
FILTER_HOST_KC="${HOST_KC%%/*}"

export PARTICIPANT
export PARTICIPANT_LOGO
export HOST
export HOST_KC
export HOST_KC_PROXY
export FILTER_HOST_KC
export REALM_KC
export AUTH_KEY_B64
export SUPER_USER_KEY_B64
export DID_B64
export PARTICIPANT_CLIENT_SECRET
export TLS_SECRET_NAME
export PASSWORD
export CLUSTER_ISSUER
export KEYCLOAK_ADMIN_USERNAME
export KEYCLOAK_ADMIN_PASSWORD

envsubst '${PARTICIPANT} ${PARTICIPANT_LOGO} ${HOST} ${HOST_KC} ${HOST_KC_PROXY} ${FILTER_HOST_KC} ${AUTH_KEY} ${AUTH_KEY_B64} ${DID_B64} ${SUPER_USER_KEY_B64} ${REALM_KC} ${PARTICIPANT_CLIENT_SECRET} ${TLS_SECRET_NAME} ${PASSWORD} ${CLUSTER_ISSUER} ${KEYCLOAK_ADMIN_USERNAME} ${KEYCLOAK_ADMIN_PASSWORD}' \
  < "$VALUES_TEMPLATE" > "$VALUES_OUT"

if [ "$USE_LETS" != "true" ]; then
  sed -i '/^[[:space:]]*cert-manager\.io\/cluster-issuer:[[:space:]]*"__REMOVE__"[[:space:]]*$/d' "$VALUES_OUT"
fi
echo -e "Generated Participant Config File: ${GREEN}$VALUES_OUT${NC}"

echo "---"

# --- 8. Finish ---
echo -e "${GREEN}All tasks finished successfully!${NC}"
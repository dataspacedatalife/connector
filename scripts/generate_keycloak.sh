#!/bin/bash
set -e

# --- Colors for Output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

KEYCLOAK_CHART_DIR="charts/keycloak"
KEYCLOAK_TEMPLATE_DIR="config/templates/keycloak"
TEMPLATE_FILE="$KEYCLOAK_TEMPLATE_DIR/values-template.yaml"
OUTPUT_FILE="$KEYCLOAK_CHART_DIR/values.yaml"
SECRET_TEMPLATE_FILE="$KEYCLOAK_TEMPLATE_DIR/secret-template.yaml"
SECRET_OUTPUT_FILE="$KEYCLOAK_CHART_DIR/templates/secret.yaml"

# --- 1. Helper Functions ---
show_help() {
    local exit_code="${1:-0}"
    echo -e "${YELLOW}Usage:${NC} $0 --host-kc <hostname> [OPTIONS]"
    echo ""
    echo "Generates Kubernetes configuration values for Keycloak."
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  -h, --help                  Show this help message and exit."
    echo "  --host-kc <hostname>        Set the Keycloak Hostname (required)."
    echo "  --user <user>       Set the Keycloak admin user (default: admin)."
    echo "  --password <password>       Set the Keycloak admin password (default: admin)."
    echo "  --password-db <password>    Set the Keycloak database password."
    echo "  --use-lets-encrypt          Enable Automatic SSL via Let's Encrypt."
    echo "  --tls-secret <secret_name>  Set a custom TLS secret name for manual SSL mode."
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  1. Manual SSL (Default, uses wildcard-tls-cert):"
    echo "     $0 --host-kc keycloak.example.com --password MyStrongPassword123"
    echo ""
    echo "  2. Automatic SSL (Let's Encrypt):"
    echo "     $0 --host-kc keycloak.example.com --password MyStrongPassword123 --use-lets-encrypt"
    exit "$exit_code"
}

# --- 2. Initialize variables ---
HOST_KC=""
KC_ADMIN_USER=""
KC_ADMIN_PASSWORD=""
KC_DB_PASSWORD="admin_keycloak"
USE_LETS="false"
CUSTOM_SECRET=""

# --- 3. Parse arguments ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        --host-kc)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --host-kc flag requires a hostname argument.${NC}" >&2; exit 1
            fi
            HOST_KC="$2"
            shift 2
            ;;
        --user)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --user flag requires a value.${NC}" >&2; exit 1
            fi
            KC_ADMIN_USER="$2"
            shift 2
            ;;
        --password)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --password flag requires a value.${NC}" >&2; exit 1
            fi
            KC_ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --password-db)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --password-db flag requires a value.${NC}" >&2; exit 1
            fi
            KC_DB_PASSWORD="$2"
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
        *)
            echo -e "${RED}Error: Unknown parameter $1${NC}" >&2; exit 1
            ;;
    esac
done

# --- 4. Validation ---
if [ -z "$HOST_KC" ]; then
    echo -e "${RED}Error: The argument --host-kc is mandatory.${NC}" >&2
    show_help 1
fi
echo "Keycloak Configuration Generation"

if [ -z "$KC_ADMIN_USER" ]; then
    echo -e "${YELLOW}Warning: The argument --user should be used to set a custom admin username. Using 'admin' by default.${NC}"
    KC_ADMIN_USER="admin"
fi

if [ -z "$KC_ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Warning: The argument --password should be used to set a custom admin password. Using 'admin' by default.${NC}"
    KC_ADMIN_PASSWORD="admin"
fi

# --- 5. SSL Logic ---
if [ "$USE_LETS" == "true" ]; then
    TLS_SECRET_NAME="keycloak-tls-cert"
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

# --- 6. Generate Configuration ---
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: Template file '$TEMPLATE_FILE' not found.${NC}" >&2
    exit 1
fi

export HOST_KC
export TLS_SECRET_NAME
export CLUSTER_ISSUER
export KC_ADMIN_USER

envsubst '${HOST_KC} ${KC_ADMIN_USER} ${TLS_SECRET_NAME} ${CLUSTER_ISSUER}' \
    < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

if [ "$USE_LETS" != "true" ]; then
    sed -i '/^[[:space:]]*cert-manager\.io\/cluster-issuer:[[:space:]]*__REMOVE__[[:space:]]*$/d' "$OUTPUT_FILE"
fi
echo "--> KC Hostname: $HOST_KC"
echo "---"
echo -e "${GREEN}Keycloak Values file '$OUTPUT_FILE' generated.${NC}"

if [ ! -f "$SECRET_TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: Secret template file '$SECRET_TEMPLATE_FILE' not found.${NC}" >&2
    exit 1
fi

export KC_ADMIN_PASSWORD
export KC_DB_PASSWORD

envsubst '${KC_ADMIN_PASSWORD} ${KC_DB_PASSWORD}' \
    < "$SECRET_TEMPLATE_FILE" > "$SECRET_OUTPUT_FILE"

echo -e "${GREEN}Keycloak Secret file '$SECRET_OUTPUT_FILE' generated.${NC}"
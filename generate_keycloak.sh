#!/bin/bash
set -e

KEYCLOAK_CHART_DIR="keycloak-chart"
TEMPLATE_FILE="$KEYCLOAK_CHART_DIR/values-template.yaml"
OUTPUT_FILE="$KEYCLOAK_CHART_DIR/values.yaml"
SECRET_TEMPLATE_FILE="$KEYCLOAK_CHART_DIR/secret-template.yaml"
SECRET_OUTPUT_FILE="$KEYCLOAK_CHART_DIR/templates/secret.yaml"

# Function to display usage instructions
usage() {
    echo "Usage: $0 --host-kc <hostname> --password <kc-admin-password> [--tls-secret <tls-secret-name>]"
    echo ""
    echo "Examples:"
    echo "  1. Automatic SSL (Default - Let's Encrypt):"
    echo "     $0 --host-kc keycloak.example.com --password MyStrongPassword123"
    echo ""
    echo "  2. Manual SSL (Disable Let's Encrypt, use defined secret):"
    echo "     $0 --host-kc keycloak.example.com --password MyStrongPassword123 --tls-secret my-wildcard-cert"
    exit 1
}

# Initialize variables
HOST_KC=""
KC_ADMIN_PASSWORD=""
KC_DB_PASSWORD="admin_keycloak"
USE_LETS="true"
CUSTOM_SECRET=""

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --host-kc)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "Error: --host-kc flag requires a hostname argument." >&2; exit 1
            fi
            HOST_KC="$2"
            shift 2
            ;;
        --password)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "Error: --password flag requires a value." >&2; exit 1
            fi
            KC_ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --password-db)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "Error: --password-db flag requires a value." >&2; exit 1
            fi
            KC_DB_PASSWORD="$2"
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
        *) echo "Error: Unknown parameter $1"; usage ;;
    esac
done

# Validation: Hostname is mandatory
if [ -z "$HOST_KC" ]; then
    echo "Error: The argument --host-kc is mandatory."
    usage
fi

# Validation: Password is mandatory
if [ -z "$KC_ADMIN_PASSWORD" ]; then
    echo "Warning: The argument --password should be used to set a custom admin password. Using 'admin' by default"
    KC_ADMIN_PASSWORD="admin"
fi

# Logic: Determine Issuer and Secret Name
if [ "$USE_LETS" == "true" ]; then
    # CASE A: Let's Encrypt is ENABLED (Default)
    ISSUER_CMD="s|{{CLUSTER_ISSUER}}|letsencrypt|g"

    TLS_SECRET_NAME="keycloak-tls-cert"
    CLUSTER_ISSUER="letsencrypt"

    echo "--> SSL Mode: Automatic (Let's Encrypt)"
else
    # CASE B: Let's Encrypt is DISABLED (Manual Mode)
    ISSUER_CMD="/{{CLUSTER_ISSUER}}/d"

    TLS_SECRET_NAME="$CUSTOM_SECRET"
    CLUSTER_ISSUER="__REMOVE__"

    echo "--> SSL Mode: Manual (Secret: $TLS_SECRET_NAME)"
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found."
    exit 1
fi

export HOST_KC
export TLS_SECRET_NAME
export CLUSTER_ISSUER

envsubst '${HOST_KC} ${TLS_SECRET_NAME} ${CLUSTER_ISSUER}' \
    < "$TEMPLATE_FILE" > "$OUTPUT_FILE"

if [ "$USE_LETS" != "true" ]; then
    sed -i '/^[[:space:]]*cert-manager\.io\/cluster-issuer:[[:space:]]*__REMOVE__[[:space:]]*$/d' "$OUTPUT_FILE"
fi

echo "---"

echo "✅ Success! Values file '$OUTPUT_FILE' generated."

export KC_ADMIN_PASSWORD
envsubst '${KC_ADMIN_PASSWORD}' \
    < "$SECRET_TEMPLATE_FILE" > "$SECRET_OUTPUT_FILE"

echo "✅ Success! Secret file '$SECRET_OUTPUT_FILE' generated."

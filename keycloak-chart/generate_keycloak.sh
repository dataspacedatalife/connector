#!/bin/bash
set -e

TEMPLATE_FILE="values-template.yaml"
OUTPUT_FILE="values.yaml"

# Function to display usage instructions
usage() {
    echo "Usage: $0 --host-kc <hostname> [--manual] [--secret <secret-name>]"
    echo ""
    echo "Examples:"
    echo "  1. Automatic SSL (Default - Let's Encrypt):"
    echo "     $0 --host-kc keycloak.example.com"
    echo ""
    echo "  2. Manual SSL (Disable Let's Encrypt):"
    echo "     $0 --host-kc keycloak.example.com --manual --secret my-wildcard-cert"
    exit 1
}

# Initialize variables
HOST_KC=""
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
        --manual) # Flag to DISABLE Let's Encrypt
            USE_LETS="false"
            shift
            ;;
        --secret) # Optional: Define a custom secret name for manual mode
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "Error: --secret flag requires a value." >&2; exit 1
            fi
            CUSTOM_SECRET="$2"
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

# Logic: Determine Issuer and Secret Name
if [ "$USE_LETS" == "true" ]; then
    # CASE A: Let's Encrypt is ENABLED (Default)
    ISSUER_CMD="s|{{CLUSTER_ISSUER}}|letsencrypt|g"

    TLS_SECRET_NAME="keycloak-tls-cert"

    echo "--> SSL Mode: Automatic (Let's Encrypt)"
else
    # CASE B: Let's Encrypt is DISABLED (Manual Mode)
    ISSUER_CMD="/{{CLUSTER_ISSUER}}/d"

    if [ -z "$CUSTOM_SECRET" ]; then
        TLS_SECRET_NAME="wildcard-tls-cert"
    else
        TLS_SECRET_NAME="$CUSTOM_SECRET"
    fi
    echo "--> SSL Mode: Manual (Secret: $TLS_SECRET_NAME)"
fi

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found."
    exit 1
fi

# Perform replacements using sed
sed -e "s|{{HOST_KC}}|$HOST_KC|g" \
    -e "s|{{TLS_SECRET_NAME}}|$TLS_SECRET_NAME|g" \
    -e "$ISSUER_CMD" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo "---"

echo "✅ Success! Values file '$OUTPUT_FILE' generated."
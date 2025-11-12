#!/bin/bash
set -e

# --- 1. Argument Parsing ---
PARTICIPANT=""
HOST=""
HOST_KC=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --host)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --host flag requires a hostname argument." >&2; exit 1
      fi
      HOST="$2"
      shift 2 # past argument and value
      ;;
    --host-kc)
      if [[ -z "$2" || "$2" == --* ]]; then
        echo "Error: --host-kc flag requires a hostname argument." >&2; exit 1
      fi
      HOST_KC="$2"
      shift 2 # past argument and value
      ;;
    *)
      if [ -n "$PARTICIPANT" ]; then
        echo "Error: Participant name already set to '$PARTICIPANT'. Cannot set it to '$1'." >&2; exit 1
      fi
      PARTICIPANT="$1"
      shift # past argument
      ;;
  esac
done

# --- 2. Validation ---
if [ -z "$PARTICIPANT" ]; then
  echo "Usage: $0 PARTICIPANT --host <HN> --host-kc <HN_KC>"
  echo
  echo "Example:"
  echo "  $0 ext-partner-dns --host my-app.com --host-kc kc.my-app.com"
  exit 1
fi

# Validação: --host e --host-kc devem ser usados em conjunto
if { [ -n "$HOST" ] && [ -z "$HOST_KC" ]; } || { [ -z "$HOST" ] && [ -n "$HOST_KC" ]; }; then
  echo "Error: --host and --host-kc must be used together." >&2
  exit 1
fi

# --- NOVA VALIDAÇÃO ---
# Validação: --host e --host-kc são obrigatórios
if [ -z "$HOST" ]; then
  echo "Error: --host and --host-kc flags are mandatory." >&2
  echo
  echo "Usage: $0 PARTICIPANT --host <HN> --host-kc <HN_KC>"
  echo "Example: $0 $PARTICIPANT --host my-app.com --host-kc kc.my-app.com"
  exit 1
fi

# --- 3. Compute Host Logic ---
# (O 'else' foi removido, pois a validação acima garante que HOST e HOST_KC existem)
echo "External hostnames provided. Using the following domains."
PARTICIPANT_HOST="$HOST"
PARTICIPANT_HOST_KC="$HOST_KC"

echo "Main Host: $PARTICIPANT_HOST"
echo "KC Host:   $PARTICIPANT_HOST_KC"

# --- 4. Define Variable Paths ---
PARTICIPANT_CHART_DIR="participant-chart"
VALUES_TEMPLATE="$PARTICIPANT_CHART_DIR/values-template.yaml"

# Definir o diretório de saída como 'values' (sempre)
VALUES_OUT_DIR="$PARTICIPANT_CHART_DIR/values"
echo "Sending config file to directory: $VALUES_OUT_DIR"

mkdir -p "$VALUES_OUT_DIR"

VALUES_OUT="$VALUES_OUT_DIR/values-$PARTICIPANT.yaml"

# --- 5. Compute Auth Keys ---
DID_B64=$(echo -n "did:web:$PARTICIPANT_HOST:identityhub:did" | base64 -w0)
AUTH_KEY_B64=$(echo -n "$PARTICIPANT-password" | base64 -w0)
PART1_B64=$(echo -n "super-user" | base64 -w0)
PART2_B64=$(echo -n "super-$PARTICIPANT-key" | base64 -w0)
SUPER_USER_KEY_B64="$PART1_B64.$PART2_B64"

# --- 6. Generate Participant values.yaml ---
echo "---"
echo "Generating Kubernetes config file for participant: $PARTICIPANT..."

sed \
  -e "s/{{PARTICIPANT}}/$PARTICIPANT/g" \
  -e "s/{{HOST}}/$PARTICIPANT_HOST/g" \
  -e "s/{{HOST_KC}}/$PARTICIPANT_HOST_KC/g" \
  -e "s/{{AUTH_KEY_B64}}/$AUTH_KEY_B64/g" \
  -e "s/{{SUPER_USER_KEY_B64}}/$SUPER_USER_KEY_B64/g" \
  -e "s/{{DID_B64}}/$DID_B64/g" \
  "$VALUES_TEMPLATE" > "$VALUES_OUT"

echo "Generated $VALUES_OUT"
echo "---"

# --- 7. Finish ---
echo "✅ Participant '$PARTICIPANT' values file generated successfully!"
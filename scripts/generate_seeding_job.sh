#!/bin/bash
set -e

# --- Colors for Output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- 1. Helper Functions ---
show_help() {
  echo -e "${YELLOW}Usage:${NC} $0 --host-kc <hostname> --user <user> --password <password> [OPTIONS]"
  echo
  echo "Generates Kubernetes Job manifests for Keycloak Realm, Client, and Scopes initialization."
  echo
  echo -e "${YELLOW}Options:${NC}"
  echo "  -h, --help                        Show this help message and exit."
  echo "  --host-kc <hostname>              Keycloak Hostname (required)."
  echo "  --user <user>                     Keycloak Admin User (default: admin)."
  echo "  --password <password>             Keycloak Admin Password (default: admin)."
  echo "  --client-admin <client-admin>     Admin Client ID (default: admin-cli)."
  echo "  --realm-admin <realm-admin>       Admin Realm (default: master)."
  echo "  --realm <realm>                   Target Realm name (default: dataspace)."
  echo "  --realm-file <path>               Path to Realm JSON file (default: config/keycloak/realms/realm.json)."
  echo "  --client-file <path>              Path to client JSON file (default: config/keycloak/clients/frontend-client.json)."
  echo "  --scopes-file <path>              Path to scopes JSON file (default: config/keycloak/scopes/groups.json)."
  echo
  echo -e "${YELLOW}Examples:${NC}"
  echo "  1. Standard Generation:"
  echo "     $0 --host-kc kc.example.com --user admin --password MySecretPassword"
  echo
  echo "  2. Custom File Paths & Realm:"
  echo "     $0 --host-kc kc.example.com --user admin --password secret --realm custom-realm-name"
  exit 0
}

# --- 2. Initialize variables ---
KC_URL=""
KC_ADMIN_USER=""
KC_ADMIN_PASSWORD=""
CLIENT_ADMIN="admin-cli"
REALM_ADMIN="master"
TARGET_REALM="dataspace"
CLIENT_FILE="config/keycloak/clients/frontend-client.json"
REALM_FILE="config/keycloak/realms/realm.json"
SCOPES_FILE="config/keycloak/scopes/groups.json"
JOBS_DIRECTORY="config/generated/keycloak/jobs"

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
            KC_URL="$2"
            shift 2
            ;;
        --user)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --user flag requires a username argument.${NC}" >&2; exit 1
            fi
            KC_ADMIN_USER="$2"
            shift 2
            ;;
        --password)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --password flag requires a password argument.${NC}" >&2; exit 1
            fi
            KC_ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --client-admin)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --client-admin flag requires a value.${NC}" >&2; exit 1
            fi
            CLIENT_ADMIN="$2"
            shift 2
            ;;
        --realm-admin)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --realm-admin flag requires a value.${NC}" >&2; exit 1
            fi
            REALM_ADMIN="$2"
            shift 2
            ;;
        --realm)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --realm flag requires a value.${NC}" >&2; exit 1
            fi
            TARGET_REALM="$2"
            shift 2
            ;;
        --realm-file)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --realm-file flag requires a file path argument.${NC}" >&2; exit 1
            fi
            REALM_FILE="$2"
            shift 2
            ;;
        --client-file)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --client-file flag requires a file path argument.${NC}" >&2; exit 1
            fi
            CLIENT_FILE="$2"
            shift 2
            ;;
        --scopes-file)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo -e "${RED}Error: --scopes-file flag requires a file path argument.${NC}" >&2; exit 1
            fi
            SCOPES_FILE="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Unknown parameter $1${NC}" >&2; exit 1
            ;;
    esac
done

# --- 4. Validation ---
if [ -z "$KC_URL" ]; then
    echo -e "${RED}Error: --host-kc is required.${NC}" >&2
    show_help
fi

if [ ! -f "$CLIENT_FILE" ]; then
    echo -e "${RED}Error: Client file '$CLIENT_FILE' not found.${NC}" >&2
    exit 1
fi

if [ ! -f "$REALM_FILE" ]; then
    echo -e "${RED}Error: Realm file '$REALM_FILE' not found.${NC}" >&2
    exit 1
fi

if [ ! -f "$SCOPES_FILE" ]; then
    echo -e "${RED}Error: Scopes file '$SCOPES_FILE' not found.${NC}" >&2
    exit 1
fi

echo "Generating Keycloak Job manifests..."

if [ -z "$KC_ADMIN_USER" ]; then
    echo -e "${YELLOW}Warning: --user not provided. Using 'admin' by default.${NC}"
    KC_ADMIN_USER="admin"
fi

if [ -z "$KC_ADMIN_PASSWORD" ]; then
    echo -e "${YELLOW}Warning: --password not provided. Using 'admin' by default.${NC}"
    KC_ADMIN_PASSWORD="admin"
fi

echo "Configuration:"
echo "--> KC Host:   $KC_URL"
echo "--> Target:    $TARGET_REALM"
echo "--> Realm:     $REALM_FILE"
echo "--> Client:    $CLIENT_FILE"
echo "--> Scopes:    $SCOPES_FILE"

mkdir -p "$JOBS_DIRECTORY"

# --- 5. Generate Jobs ---
# ==============================================================================
# 1. GENERATE CLIENT SEEDING JOB (job-add-default-client.yaml)
# ==============================================================================

CLIENT_JSON_CONTENT=$(sed 's/^/    /' "$CLIENT_FILE")
CLIENT_OUTPUT_FILE="$JOBS_DIRECTORY/job-add-default-client.yaml"

cat <<EOF > "$CLIENT_OUTPUT_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-frontend-client-seeding-config
data:
  KC_ADMIN_USER: "$KC_ADMIN_USER"
  KC_ADMIN_PASSWORD: "$KC_ADMIN_PASSWORD"
  KC_URL: "https://$KC_URL"
  KC_REALM_ADMIN: "$REALM_ADMIN"
  KC_CLIENT_ADMIN: "$CLIENT_ADMIN"
  KC_TARGET_REALM: "$TARGET_REALM"
  frontend-client.json: |
$CLIENT_JSON_CONTENT

---

apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-frontend-client-seeding
spec:
  ttlSecondsAfterFinished: 120
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: seeder-keycloak-client
          image: badouralix/curl-jq:latest
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: keycloak-frontend-client-seeding-config
          command: ["/bin/sh", "-c"]
          args:
            - |
              # ====================================================
              # 1. OBTAIN ADMIN TOKEN
              # ====================================================
              echo "[INFO] Getting Admin Token..."
              TOKEN=\$(curl -s -X POST "\$KC_URL/realms/\$KC_REALM_ADMIN/protocol/openid-connect/token" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=\$KC_ADMIN_USER" \
                -d "password=\$KC_ADMIN_PASSWORD" \
                -d "grant_type=password" \
                -d "client_id=\$KC_CLIENT_ADMIN" | jq -r '.access_token')

              if [ "\$TOKEN" == "null" ] || [ -z "\$TOKEN" ]; then exit 1; fi

              echo "[INFO] Waiting for realm '\$KC_TARGET_REALM' to be created..."
              until curl -s -f -H "Authorization: Bearer \$TOKEN" "\$KC_URL/admin/realms/\$KC_TARGET_REALM" > /dev/null; do sleep 5; done

              # ====================================================
              # 2. PREPARE THE DEFAULT CLIENT
              # ====================================================
              echo "[INFO] Injecting KC_URL (\$KC_URL) into payload..."
              jq --arg url "\$KC_URL/*" '.redirectUris = [\$url]' /payload/frontend-client.json > /tmp/final-payload.json
              echo "[SUCCESS] Payload prepared. Redirect URI set to: \$KC_URL/*"

              # ====================================================
              # 3. CREATE CLIENT
              # ====================================================

              echo "[INFO] Creating Client..."
              HTTP_CODE=\$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "\$KC_URL/admin/realms/\$KC_TARGET_REALM/clients" \
                -H "Authorization: Bearer \$TOKEN" \
                -H "Content-Type: application/json" \
                -d @/tmp/final-payload.json)

              if [ "\$HTTP_CODE" -eq 201 ]; then echo "[SUCCESS] Created successfully."
              elif [ "\$HTTP_CODE" -eq 409 ]; then echo "[WARN] Already exists (409). Skipping."
              else echo "[ERROR] Failed. HTTP Code: \$HTTP_CODE"; exit 1; fi

          volumeMounts:
            - name: payload-volume
              mountPath: /payload
      volumes:
        - name: payload-volume
          configMap:
            name: keycloak-frontend-client-seeding-config
EOF

echo -e "Job manifest generated: ${GREEN}$CLIENT_OUTPUT_FILE${NC}"

# ==============================================================================
# 2. GENERATE REALM IMPORT JOB (job-import-realm.yaml)
# ==============================================================================

REALM_JSON_CONTENT=$(sed 's/^/    /' "$REALM_FILE")
REALM_OUTPUT_FILE="$JOBS_DIRECTORY/job-import-realm.yaml"

cat <<EOF > "$REALM_OUTPUT_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-realm-config
data:
  KC_ADMIN_USER: "$KC_ADMIN_USER"
  KC_ADMIN_PASSWORD: "$KC_ADMIN_PASSWORD"
  KC_URL: "https://$KC_URL"
  KC_REALM_ADMIN: "$REALM_ADMIN"
  KC_CLIENT_ADMIN: "$CLIENT_ADMIN"
  realm.json: |
$REALM_JSON_CONTENT

---

apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-realm-import-api
spec:
  ttlSecondsAfterFinished: 120
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: realm-importer
          image: badouralix/curl-jq:latest
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: keycloak-realm-config
          command: ["/bin/sh", "-c"]
          args:
            - |

              # ====================================================
              # 1. OBTAIN ADMIN TOKEN
              # ====================================================
              echo "[INFO] Getting Admin Token..."
              TOKEN=\$(curl -s -X POST "\$KC_URL/realms/\$KC_REALM_ADMIN/protocol/openid-connect/token" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=\$KC_ADMIN_USER" \
                -d "password=\$KC_ADMIN_PASSWORD" \
                -d "grant_type=password" \
                -d "client_id=\$KC_CLIENT_ADMIN" | jq -r '.access_token')

              if [ "\$TOKEN" == "null" ] || [ -z "\$TOKEN" ]; then
                echo "[ERROR] Error obtaining token. Check credentials."
                exit 1
              fi

              # ====================================================
              # 2. INSERTING DEFAULT REALM
              # ====================================================
              echo "[INFO] Sending Realm to the API..."
              HTTP_CODE=\$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "\$KC_URL/admin/realms" \
                -H "Authorization: Bearer \$TOKEN" \
                -H "Content-Type: application/json" \
                -d @/config/realm.json)

              if [ "\$HTTP_CODE" -eq 201 ]; then echo "[SUCCESS] Realm created successfully!"
              elif [ "\$HTTP_CODE" -eq 409 ]; then echo "[WARN] Realm already exists."
              else echo "[ERROR] Failed. HTTP Code: \$HTTP_CODE"; exit 1; fi

          volumeMounts:
            - name: realm-config-vol
              mountPath: /config
              readOnly: true
      volumes:
        - name: realm-config-vol
          configMap:
            name: keycloak-realm-config
EOF

echo -e "Job manifest generated: ${GREEN}$REALM_OUTPUT_FILE${NC}"

# ==============================================================================
# 3. GENERATE SCOPES SEEDING JOB (job-add-client-scopes.yaml)
# ==============================================================================

SCOPES_JSON_CONTENT=$(sed 's/^/    /' "$SCOPES_FILE")
SCOPES_OUTPUT_FILE="$JOBS_DIRECTORY/job-add-client-scopes.yaml"

cat <<EOF > "$SCOPES_OUTPUT_FILE"
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-client-scopes-config
data:
  KC_ADMIN_USER: "$KC_ADMIN_USER"
  KC_ADMIN_PASSWORD: "$KC_ADMIN_PASSWORD"
  KC_URL: "https://$KC_URL"
  KC_REALM_ADMIN: "$REALM_ADMIN"
  KC_CLIENT_ADMIN: "$CLIENT_ADMIN"
  KC_TARGET_REALM: "$TARGET_REALM"
  client-scopes.json: |
$SCOPES_JSON_CONTENT

---

apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-client-scopes-seeding
spec:
  ttlSecondsAfterFinished: 120
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: seeder-client-scopes
          image: badouralix/curl-jq:latest
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: keycloak-client-scopes-config
          command: ["/bin/sh", "-c"]
          args:
            - |

              # ====================================================
              # 1. OBTAIN ADMIN TOKEN
              # ====================================================
              echo "[INFO] Getting Admin Token..."
              TOKEN=\$(curl -s -X POST "\$KC_URL/realms/\$KC_REALM_ADMIN/protocol/openid-connect/token" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=\$KC_ADMIN_USER" \
                -d "password=\$KC_ADMIN_PASSWORD" \
                -d "grant_type=password" \
                -d "client_id=\$KC_CLIENT_ADMIN" | jq -r '.access_token')

              if [ "\$TOKEN" == "null" ] || [ -z "\$TOKEN" ]; then exit 1; fi

              # ====================================================
              # 2. VERIFYING THE REALM EXISTENCE
              # ====================================================
              echo "[INFO] Waiting for realm '\$KC_TARGET_REALM' to be created..."
              until curl -s -f -H "Authorization: Bearer \$TOKEN" "\$KC_URL/admin/realms/\$KC_TARGET_REALM" > /dev/null; do sleep 5; done


              # ====================================================
              # 3. INSERT CLIENT SCOPES
              # ====================================================
              echo "[INFO] Processing client scopes from payload..."
              jq -c '.[]' /payload/client-scopes.json | while read -r SCOPE_JSON; do
                SCOPE_NAME=\$(echo "\$SCOPE_JSON" | jq -r '.name')
                echo "[INFO] Creating Client Scope: '\$SCOPE_NAME'..."

                HTTP_CODE=\$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "\$KC_URL/admin/realms/\$KC_TARGET_REALM/client-scopes" \
                  -H "Authorization: Bearer \$TOKEN" \
                  -H "Content-Type: application/json" \
                  -d "\$SCOPE_JSON")

                if [ "\$HTTP_CODE" -eq 201 ]; then echo "[SUCCESS] Client Scope created successfully."
                elif [ "\$HTTP_CODE" -eq 409 ]; then echo "[WARN] Client Scope already exists (409). Skipping."
                else echo "[ERROR] Failed. HTTP Code: \$HTTP_CODE"; exit 1; fi

                SCOPE_ID=\$(curl -s -H "Authorization: Bearer \$TOKEN" "\$KC_URL/admin/realms/\$KC_TARGET_REALM/client-scopes" | jq -r --arg name "\$SCOPE_NAME" '.[] | select(.name == \$name) | .id')

                if [ ! -z "\$SCOPE_ID" ] && [ "\$SCOPE_ID" != "null" ]; then
                   echo "[INFO] Assigning '\$SCOPE_NAME' as a Default scope..."
                   curl -s -X PUT "\$KC_URL/admin/realms/\$KC_TARGET_REALM/default-default-client-scopes/\$SCOPE_ID" \
                     -H "Authorization: Bearer \$TOKEN"
                   echo "[SUCCESS] Default Type Assigned to Client Scope."
                fi
              done

          volumeMounts:
            - name: payload-volume
              mountPath: /payload
      volumes:
        - name: payload-volume
          configMap:
            name: keycloak-client-scopes-config
EOF

echo -e "Job manifest generated: ${GREEN}$SCOPES_OUTPUT_FILE${NC}"
echo "---"
echo -e "${GREEN}All tasks finished successfully!${NC}"
#!/bin/bash

# Default values
KC_ADMIN_USER="admin"
KC_ADMIN_PASSWORD="admin"
KC_URL=""
CLIENT_ADMIN="admin-cli"
REALM_ADMIN="master"
CLIENT_FILE="config/keycloak/clients/frontend-client.json"
REALM_FILE="config/keycloak/realms/realm.json"
JOBS_DIRECTORY="config/generated/keycloak/jobs"

# Function to display usage
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --host-kc <host-kc>               Keycloak Hostname (required)"
  echo "  --user <user>                     Keycloak Admin User (default: admin)"
  echo "  --password <password>             Keycloak Admin Password (default: admin)"
  echo "  --client-admin <client-admin>     Admin Client ID (default: admin-cli)"
  echo "  --realm-admin <realm-admin>       Admin Realm (default: master)"
  echo "  --realm-file <path>               Path to Realm JSON file (default: config/keycloak/realms/realm.json)"
  echo "  --client-file <path>              Path to client JSON file (default: config/keycloak/clients/frontend-client.json)"
  echo "  --help                            Show this help message"
  exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --user) KC_ADMIN_USER="$2"; shift ;;
        --password) KC_ADMIN_PASSWORD="$2"; shift ;;
        --host-kc) KC_URL="$2"; shift ;;
        --client-file) CLIENT_FILE="$2"; shift ;; # Renamed from --file for clarity
        --realm-file) REALM_FILE="$2"; shift ;;   # New argument
        --help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate required arguments
if [ -z "$KC_URL" ]; then
    echo "Error: --host-kc is required."
    usage
fi

if [ -z "$KC_ADMIN_USER" ]; then
    echo "Error: --user is required (Keycloak Admin User)."
    usage
fi

if [ -z "$KC_ADMIN_PASSWORD" ]; then
    echo "Error: --password is required (Keycloak Admin Password)."
    usage
fi

# Validate file existence
if [ ! -f "$CLIENT_FILE" ]; then
    echo "Error: File '$CLIENT_FILE' not found."
    exit 1
fi

if [ ! -f "$REALM_FILE" ]; then
    echo "Error: Realm file '$REALM_FILE' not found."
    exit 1
fi

mkdir -p "$JOBS_DIRECTORY"

# ==============================================================================
# 1. GENERATE CLIENT SEEDING JOB (job-add-default-client.yaml)
# ==============================================================================

CLIENT_JSON_CONTENT=$(sed 's/^/    /' "$CLIENT_FILE")
CLIENT_OUTPUT_FILE="$JOBS_DIRECTORY/job-add-default-client.yaml"

# Generate YAML
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
  frontend-client.json: |
$CLIENT_JSON_CONTENT

---

apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-frontend-client-seeding
spec:
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
              # 1. WAIT FOR KEYCLOAK (Wait for Readiness)
              # ====================================================
              echo "Waiting for Keycloak to be ready at \$KC_URL..."
              until curl -s -f "\$KC_URL/health/ready" > /dev/null; do
                echo "Keycloak is unavailable - sleeping"
                sleep 5
              done
              echo "Keycloak is UP!"

              # ====================================================
              # 2. OBTAIN ADMIN TOKEN
              # ====================================================
              echo "Getting Admin Token..."
              TOKEN=\$(curl -s -X POST "\$KC_URL/realms/\$KC_REALM_ADMIN/protocol/openid-connect/token" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=\$KC_ADMIN_USER" \
                -d "password=\$KC_ADMIN_PASSWORD" \
                -d "grant_type=password" \
                -d "client_id=\$KC_CLIENT_ADMIN" | jq -r '.access_token')

              if [ "\$TOKEN" == "null" ] || [ -z "\$TOKEN" ]; then
                echo "Error getting token. Check credentials."
                exit 1
              fi

              # ====================================================
              # 2.5 WAIT FOR REALM IMPORT
              # ====================================================
              echo "Waiting for realm 'dataspace' to be created by the import job..."
              until curl -s -f -H "Authorization: Bearer \$TOKEN" "\$KC_URL/admin/realms/dataspace" > /dev/null; do
                echo "Realm 'dataspace' is not yet available - sleeping 5 seconds..."
                sleep 5
              done
              echo "Realm 'dataspace' is fully imported and ready!"

              # ====================================================
              # 3. PREPARE THE DEFAULT CLIENT
              # ====================================================
              echo "Injecting KC_URL (\$KC_URL) into payload..."
              jq --arg url "\$KC_URL/*" '.redirectUris = [\$url]' /payload/frontend-client.json > /tmp/final-payload.json
              echo "Payload prepared. Redirect URI set to: \$KC_URL/*"

              # ====================================================
              # 4. CREATE CLIENT
              # ====================================================

              # Aux Function to create the client
              create_client() {
                local FILE=\$1
                echo "Creating Client from \$FILE..."
                local HTTP_CODE=\$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "\$KC_URL/admin/realms/dataspace/clients" \
                  -H "Authorization: Bearer \$TOKEN" \
                  -H "Content-Type: application/json" \
                  -d @/tmp/final-payload.json)

                if [ "\$HTTP_CODE" -eq 201 ]; then
                   echo " -> Created successfully."
                elif [ "\$HTTP_CODE" -eq 409 ]; then
                   echo " -> Already exists (409). Skipping."
                else
                   echo " -> Failed. HTTP Code: \$HTTP_CODE"
                   exit 1
                fi
              }

              # Create Frontend Client
              create_client "/tmp/final-payload.json"

          volumeMounts:
            - name: payload-volume
              mountPath: /payload
      volumes:
        - name: payload-volume
          configMap:
            name: keycloak-frontend-client-seeding-config
EOF

echo "Generated: $CLIENT_OUTPUT_FILE"

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
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: realm-importer
          image: alpine:latest
          imagePullPolicy: IfNotPresent
          envFrom:
            - configMapRef:
                name: keycloak-realm-config
          command: ["/bin/sh", "-c"]
          args:
            - |
              # Install dependencies
              apk add --no-cache curl jq sed

              echo "Waiting for Keycloak to be ready at \$KC_URL..."
              until curl -s -f "\$KC_URL/health/ready" > /dev/null; do
                echo "Keycloak is unavailable - waiting..."
                sleep 5
              done

              echo "Getting Admin Token..."
              TOKEN=\$(curl -s -X POST "\$KC_URL/realms/\$KC_REALM_ADMIN/protocol/openid-connect/token" \
                -H "Content-Type: application/x-www-form-urlencoded" \
                -d "username=\$KC_ADMIN_USER" \
                -d "password=\$KC_ADMIN_PASSWORD" \
                -d "grant_type=password" \
                -d "client_id=\$KC_CLIENT_ADMIN" | jq -r '.access_token')

              if [ "\$TOKEN" == "null" ] || [ -z "\$TOKEN" ]; then
                echo "Error obtaining token. Check credentials."
                exit 1
              fi

              echo "Sending Realm to the API..."
              HTTP_CODE=\$(curl -s -o /dev/stderr -w "%{http_code}" -X POST "\$KC_URL/admin/realms" \
                -H "Authorization: Bearer \$TOKEN" \
                -H "Content-Type: application/json" \
                -d @/config/realm.json)

              if [ "\$HTTP_CODE" -eq 201 ]; then
                echo "✅ Realm created successfully!"
              elif [ "\$HTTP_CODE" -eq 409 ]; then
                echo "⚠️ Realm already exists. Nothing done."
              else
                echo "❌ Import failed. HTTP Code: \$HTTP_CODE"
                exit 1
              fi

          volumeMounts:
            - name: realm-config-vol
              mountPath: /config
              readOnly: true
      volumes:
        - name: realm-config-vol
          configMap:
            name: keycloak-realm-config
EOF

echo "Generated: $REALM_OUTPUT_FILE"

# Xdatashare Connector Deployment Guide
This document outlines the two-phase process for adding a new xdatashare connector to an unpopulated Kubernetes cluster (such as kind).This process assumes the cluster is already running NGINX Ingress Controller and Cert-Manager, but has not yet been configured to issue certificates.

## Prerequisites

Before starting, ensure you have the following:
- **A Running Kubernetes Cluster:** A cluster (like kind) with correct port-forwarding for ports 80 and 443.
- **Installed Tooling:** kubectl and helm must be installed and configured to point to the cluster.
- **Installed Cluster Services:**
    - `ingress-nginx` (NGINX Ingress Controller)
    - `cert-manager`
- **Deployment Scripts/Jobs:**
    - `setup-issuer.sh` (This script, for Phase 1)
    - `generate_participant.sh` (This script, for Phase 2)
    - `generate_keycloak.sh` (This script, for Phase 2 if deploying Keycloak)
    - `job-import-realm.yaml` (Keycloak realm import job, for client's keycloak)
- **Helm Chart:** 
    - The `keycloak-chart` directory.
    - The `participant-chart` directory.
- **Public DNS:** You must have public DNS "A" records pointing to the hostnames (e.g., `conector-xdatashare.gradiant.org`, `conector-xdatashare-kc.gradiant.org`) to the cluster's public IP address.

## Phase 1: Cluster-Level Setup (One-Time Only)

This phase configures `cert-manager` to communicate with `Let's Encrypt`, enabling automatic SSL certificate generation for the entire cluster. **This only needs to be run once per new cluster**.

**Note:** Skip this phase if you intend to use manual TLS secrets (e.g., wildcard certificates) or if your cluster already has a configured ClusterIssuer.
### 1. Run the Setup Issuer Script (Optional)

This script verifies that NGINX and `cert-manager` are ready, then creates the global `ClusterIssuer`. You must provide a valid email address for `Let's Encrypt` registration.
```bash
  # Make the script executable
  chmod +x setup-cert-issuer.sh

  # Run the script, passing in the registration email
  ./setup-cert-issuer.sh --email email@example.com
```

### 2. Verify the ClusterIssuer

After the script finishes, you can manually verify that the `ClusterIssuer` is Ready.
```bash
  kubectl describe clusterissuer letsencrypt-prod
```

Look for the following in the status: section at the end of the output:

```txt
  Status:
    Conditions:
    ...
    Reason:            ACMEAccountRegistered
    Status:            True
    Type:              Ready
```

If `Status` is `True`, the cluster is now ready to automatically issue certificates for any participant.

## Phase 2: Deploying a New Participant

### 1. Keycloak (Optional) 

Deploying `keycloak-chart` is an optional step. This chart deploys a Keycloak image (based on Bitnami) that eliminates the need to integrate a subchart within the participant. In this way, Keycloak is established as a standalone, centralized element, designed to serve all participants deployed in the customer's environment. In any case, the implementation includes the necessary configuration (a Realm and a default Client) so that the participant's portal can communicate correctly.


#### 1.1. Seeding Jobs

To do these step of configuring the keycloak, two configuration jobs are used:

- **Realm import job (job-import-realm.json):** Imports a preconfigured realm with the client scopes necessary for the user's initial login verifications. 
- **Client registration job (job-add-default-client.json):** Registers a new client in this realm that will serve as the default client for the participant interface. 

To automatically generate both of the previously mentioned jobs (the realm import and the frontend client registration), we use the generate_seeding_job.sh script.

The following image illustrates how to grant execution permissions to the script and provides an example of how to run it by specifying the Keycloak host and the administrator password:

```bash
  # Make the script executable
  chmod +x generate_seeding_job.sh

  # Usage:
  # ./generate_seeding_job.sh --host-kc <KEYCLOAK_HOSTNAME> --user <KEYCLOAK_ADMIN_USER> --pass <KEYCLOAK_ADMIN_PASSWORD>

  # Example:
  ./generate_seeding_job.sh --host-kc conector-xdatashare-kc.gradiant.org --pass admin

```

The `generate_seeding_job.sh` script automates the creation of the Kubernetes jobs responsible for initializing the Keycloak environment (realm import and frontend client registration).

This script is configured by passing command-line arguments.

**Required Parameters:**
- --host-kc <host-kc>: The hostname or URL where Keycloak is deployed (e.g., conector-xdatashare-kc.gradiant.org).
- --pass <password>: The Keycloak administrator password.

**Optional Parameters (with default values):**
- --user <user>: The Keycloak administrator username. (Default: admin).
- --realm-file <path>: Path to the JSON file containing the realm configuration to be imported. (Default: keycloak/realms/realm.json).
- --client-file <path>: Path to the JSON file containing the client configuration to be registered. (Default: keycloak/clients/frontend-client.json).
- --client-admin <client-admin>: The admin client ID used for the connection. (Default: admin-cli).
- --realm-admin <realm-admin>: The administration realm name. (Default: master).
- --help: Displays the help and usage message.

The `generate_seeding_job.sh` script relies on two pre-configured JSON files by default to construct the Kubernetes job manifests. These files contain the actual payloads that will be applied to Keycloak:
- **Realm File (keycloak/realms/realm.json):** This file contains the complete definition of the target realm (e.g., the "dataspace" realm). It includes the necessary client scopes and settings required for the initial user login verification. It is used as the blueprint to build the job responsible for importing the realm.
- **Frontend Client File (keycloak/clients/frontend-client.json):** This file defines the default OIDC client (typically named `edc-frontend`), which is strictly required to secure and enable the authentication flow for the participant portal. It is used to construct the job responsible for registering this client within the previously imported realm.

**Note:** If the operator wishes to use custom configurations, they can replace these files or point to a different path using the `--realm-file` and `--client-file` flags explained above.

#### 1.2. Generate Keycloak Configuration

Use the `generate_keycloak.sh` script to create a customized values.yaml for the Keycloak chart. This step is only necessary if you plan to deploy the Keycloak chart as part of your participant deployment. If you are using an external Keycloak, you can skip this step and manually configure your Keycloak instance.

```bash
  # Make the script executable
  chmod +x generate_keycloak.sh

  # Usage:
  # ./generate_keycloak.sh <PARTICIPANT_NAME> --host-kc <KEYCLOAK_HOSTNAME> --manual --secret <TLS_SECRET_NAME>

  # Example:
  ./generate_keycloak.sh gradiant --host-kc conector-xdatashare-kc.gradiant.org

```

This command will create a new file: `keycloak-chart/values.yaml`, which contains the necessary configuration for deploying the Keycloak chart with the specified hostname.
The generation script supports several flags:
- `--host-kc <KEYCLOAK_HOSTNAME>`: This is the hostname that will be used for the Keycloak deployment. It should match the DNS record you have set up for Keycloak (e.g., `conector-xdatashare-kc.gradiant.org`).
- `--manual`: If you want to deploy the external Keycloak without the connection to the lets encrypt, you can use this flag to generate a `values.yaml` without the TLS configuration. This is useful if you want to manage the TLS certificates for Keycloak separately (e.g., using wildcard certificates or another certificate management solution).
- `--secret <TLS_SECRET_NAME>`: If you have an existing TLS secret for Keycloak, you can use this flag to specify the name of that secret. The generated `values.yaml` will then reference this secret instead of creating a new one. If this name is not passed the script will assume the default secret name `keycloak-tls-cert` for the Keycloak deployment. This is useful if you have already set up TLS for Keycloak and want to reuse that configuration without modification.

**Creating a Manual TLS Secret**
If you are not using Let's Encrypt (Phase 1) and do not have an existing TLS secret configured, you must create one manually before deploying the chart. This secret stores your certificate chain and private key in a format the Ingress controller can consume.
You will need your certificate file (e.g., tls.crt) and your private key file (e.g., tls.key)

**Create the secret**
Run the following command in the namespace where you intend to deploy Keycloak:
```bash
kubectl create secret tls <TLS_SECRET_NAME> \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n <KEYCLOAK_NAMESPACE>
```
**Warning:** The Secret must be created in the same namespace as the Keycloak deployment for the Ingress controller to successfully terminate the SSL connection.

**Verify the secret**
```bash
kubectl get secret keycloak-tls-cert -n xdatashare -o yaml
```

#### 1.2. Deploy Keycloak Chart

If the participant does not have an existing IAM solution, deploy the `keycloak-chart`. This chart acts as a complementary service, removing the need for a Keycloak subchart inside the participant deployment. It is now deployed as a centralized, standalone service.

```bash
# Install the standalone Keycloak chart
helm install keycloak ./keycloak-chart \
  --namespace xdatashare
```

### 2. Participant
#### 2.1. Generate Participant Configuration

Use the generate_participant.sh script. This creates a customized values.yaml that points to either the Keycloak deployed in the previous step or an external one.
```bash
  # Make the script executable
  chmod +x generate_participant.sh

  # Usage:
  # ./generate_participant.sh <PARTICIPANT_NAME> --host <MAIN_HOSTNAME> --host-kc <KEYCLOAK_HOSTNAME>

  # Example:
  ./generate_participant.sh gradiant \
  --host conector-xdatashare.gradiant.org \
  --host-kc conector-xdatashare-kc.gradiant.org
```
This command will create a new file: participant-chart/values/values-gradiant.yaml.
The script supports the following arguments to customize the deployment:
  - `<PARTICIPANT_NAME>`: (Required) The name of the participant (e.g., gradiant). This is used to prefix resources and name the output file.
  - `--host <MAIN_HOSTNAME>`: The primary domain for the participant (e.g., conector-xdatashare.gradiant.org). This covers the Portal and EDC endpoints.
  - `--host-kc <KEYCLOAK_HOSTNAME>`: The domain where the Keycloak service is reachable.
  - `--manual`: Disables automatic Let's Encrypt (cert-manager) annotations for the participant's Ingress resources.
  - `--secret <TLS_SECRET_NAME>`: Specifies an existing TLS secret for the participant's domains. 
    - If `--manual` is used without this flag, the script defaults to a secret named participant-tls-cert.


#### 2.2. Deploy Participant Chart

The participant-chart no longer contains an internal Keycloak subchart by default. It is now "IAM-agnostic," allowing the participant to opt for our chart-deployed Keycloak or their own.

**Note:** We recommend deploying the participant into a namespace.

```bash
  # Example for a participant named "gradiant" in namespace "xdatashare"
  # 1. Create the namespace (if it doesn't exist)
  kubectl create namespace xdatashare

  # 2. Install the Helm chart
  helm install gradiant ./participant-chart \
  -f ./participant-chart/values/values-gradiant.yaml \
  -n xdatashare
```   

### 3. Verify the Deployment

After running helm install, cert-manager will automatically begin obtaining the SSL certificates.
This may take 1-2 minutes.You can monitor the status of the certificates:# Watch the certificates in the participant's namespace
```bash
  kubectl get certificate -n xdatashare -w
```    

Wait for the `READY` column to switch from `False` to `True`.
```txt
   NAME                    READY   SECRET                  AGE
   gradiant-keycloak-tls   True    gradiant-keycloak-tls   1m
   gradiant-main-tls       True    gradiant-main-tls       1m
```

Once `READY` is `True`, the participant is fully deployed, secured with HTTPS, and accessible at the domain (e.g., `https://conector-xdatashare.gradiant.org`).

#### Veryfing Did Document Creation (Optional)
To confirm that the participant's Decentralized Identifier (DID) document has been successfully created and registered in the Identity Hub, we can query the Identity Hub's DID endpoint.

```bash
curl -s -X GET "https://conector-xdatashare.gradiant.org/identityhub/did"| jq
```


#### Verifying Credential Issuance (Optional)

After deployment, the `job-request-credentials.yaml` job (described below) automatically requests a Verifiable Credential from the central **dataspace-issuer**.

To confirm that the credential was successfully issued, we can query the connector's identity endpoint. We will need the **superuser API key** (often stored in the issuer's configuration).

```bash
# Set the environment variables for the ISSUER
export API_KEY="<issuer-api-key>"

# Query the issuer's /credentials endpoint
curl -s -X GET "https://conector-xdatashare.gradiant.org/identityhub/identity/api/identity/v1alpha/credentials" \
-H "X-Api-Key: $API_KEY" | jq
```

### 4. Component Architecture

**Keycloak Chart Components:**

The Keycloak Chart is a complementary chart that provides an externalized IAM service. It decouples identity management from the participant logic, allowing participants to choose between this managed deployment or a pre-existing enterprise Keycloak.

**Initial Seeding Jobs for the Keycloak Chart**


When the keycloak-chart is deployed, by default, a Post-Install/Post-Upgrade Hook runs to bootstrap the environment. This ensures that the IAM layer is immediately compatible with the Participant's security requirements.

The seeding job performs the Frontend Client Creation step: It automatically creates a client within the target realm using a predefined JSON payload (frontend-client.json).
  - Purpose: This client is used after the authentication step the participant node to give us access to the web portal. 
  - Naming Convention: By default, this client is identified as edc-frontend.

**Note:** If you choose to use an external Keycloak not managed by this chart, you must manually create this default client, in order to allow the correct redirect from the oauth2-proxy to the participant-portal.


**Participant Chart Components (Subcharts):**

The participant node is composed of several key services deployed as subcharts:
- **EDC Components:**
    - **controlplane:** Deploys the EDC Controlplane. This is the "brain" of the participant, responsible for managing the data catalog, handling contract negotiations, and enforcing data usage policies.
    - **dataplane:** Deploys the EDC Dataplane. This component is responsible for the actual, secure transfer of data between participants once a contract agreement has been successfully negotiated by the controlplane.
    - **identityhub:** Deploys the Identity Hub service. This is a critical component for managing the participant's Decentralized Identity (DID) and for storing and using Verifiable Credentials.
- **Supporting Infrastructure:**
    - **postgres:** Deploys a PostgreSQL database instance for persisting the participant's data.
    - **vault:** Deploys a HashiCorp Vault instance for managing sensitive information and secrets.
- **Participant Interface:**
    - **participant-portal:** Installs the participant web portal. This is the primary graphical user interface (GUI) where users can manage the data catalog, view policies, initiate contract negotiations, and monitor the status of data transfers.
    - **oauth2-proxy:** It acts as a security sidecar for the Participant Portal. It intercepts all incoming requests to the portal and validates the user's session against an OpenID Connect (OIDC) provider (like the Keycloak).

**Initial Seeding Jobs for the Participant Chart**

To streamline the setup process, the chart includes several one-time jobs that run after installation:

- Create Default Policies (`job-seed-policies.yaml`):
    - Purpose: Establishes the foundational data access and usage policies for the participant.
    - Functionality: Create the default set of data acess and usage policies, defining the rules under which participant will access the data.
- Create Participant DID (`job-seed-identityhub.yaml`):
    - Purpose: Establishes the participant's identity within the dataspace by creating and registering its Decentralized Identifier (DID).
    - Functionality: This job generates and registers the participant's Decentralized Identifier (DID) in the Identity Hub. The DID is essential for establishing the participant's identity within the dataspace.
- Request Credential (`job-request-credentials.yaml`):
    - Purpose: Initiates the process for the participant to obtain its Verifiable Credential from the dataspace-issuer.
    - Functionality: This job automates a crucial onboarding step by making the participant proactively request its required Verifiable Credential from the dataspace-issuer. This allows the participant to become a trusted and verifiable member of the dataspace shortly after deployment.
- Create Keycloak User (`job-add-proxy-client.yaml`):
    - Purpose: Ensures that the necessary Keycloak users and clients are created if the participant is using the chart-deployed Keycloak.
    - Functionality: This job interacts with the Keycloak Admin API to create the required client for securing the participant portal and to set up an initial user with appropriate permissions. This step is essential for enabling access to the participant portal immediately after deployment.


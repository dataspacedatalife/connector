# Xdatashare Connector Deployment Guide
This document outlines the two-phase process for adding a new xdatashare connector to an unpopulated Kubernetes cluster (such as kind).This process assumes the cluster is already running NGINX Ingress Controller and Cert-Manager, but has not yet been configured to issue certificates.

## Prerequisites

Before starting, ensure you have the following:
- **A Running Kubernetes Cluster:** A cluster (like kind) with correct port-forwarding for ports 80 and 443.
- **Installed Tooling:** kubectl and helm must be installed and configured to point to the cluster.
- **Installed Cluster Services:**
    - `ingress-nginx` (NGINX Ingress Controller)
    - `cert-manager`
- **Deployment Scripts:**
    - `setup-issuer.sh` (This script, for Phase 1)
    - `generate_participant.sh` (This script, for Phase 2)
- **Helm Chart:** 
    - The `keycloak-chart` directory.
    - The `participant-chart` directory.
- **Public DNS:** You must have public DNS "A" records pointing to the hostnames (e.g., `conector-xdatashare.gradiant.org`, `conector-xdatashare-kc.gradiant.org`) to the cluster's public IP address.

## Phase 1: Cluster-Level Setup (One-Time Only)

This phase configures `cert-manager` to communicate with `Let's Encrypt`, enabling automatic SSL certificate generation for the entire cluster. **This only needs to be run once per new cluster**.

### 1. Run the Setup Issuer Script

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

### 1. (Optional) Deploy Keycloak

If the participant does not have an existing IAM solution, deploy the keycloak-chart. This chart acts as a complementary service, removing the need for a Keycloak subchart inside the participant deployment.

```bash
# Install the standalone Keycloak chart
helm install keycloak-service ./keycloak-chart \
  --namespace xdatashare \
  --set hostname=conector-xdatashare-kc.gradiant.org
```

### 2. Generate Participant Configuration

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

### 3. Deploy Participant Chart

The participant-chart no longer contains an internal Keycloak subchart by default. It is now "IAM-agnostic," allowing the participant to opt for our chart-deployed Keycloak or their own.

**Note:** We recommend deploying the participant into a namespace.

```bash
  # Example for a participant named "gradiant" in namespace "dataspacexdatashare"
  # 1. Create the namespace (if it doesn't exist)
  kubectl create namespace dataspacexdatashare

  # 2. Install the Helm chart
  helm install gradiant ./participant-chart \
  -f ./participant-chart/values/values-gradiant.yaml \
  -n dataspacexdatashare
```   

### 3. Verify the Deployment

After running helm install, cert-manager will automatically begin obtaining the SSL certificates.
This may take 1-2 minutes.You can monitor the status of the certificates:# Watch the certificates in the participant's namespace
```bash
  kubectl get certificate -n dataspacexdatashare -w
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
- Create Keycloak User (`job-kc-client.yaml`):
    - Purpose: Ensures that the necessary Keycloak users and clients are created if the participant is using the chart-deployed Keycloak.
    - Functionality: This job interacts with the Keycloak Admin API to create the required client for securing the participant portal and to set up an initial user with appropriate permissions. This step is essential for enabling access to the participant portal immediately after deployment.
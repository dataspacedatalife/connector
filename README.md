# External Participant Deployment Guide
This document outlines the two-phase process for adding a new external participant to an unpopulated Kubernetes cluster (such as kind).This process assumes the cluster is already running NGINX Ingress Controller and Cert-Manager, but has not yet been configured to issue certificates.

## Prerequisites

Before starting, ensure you have the following:
- **A Running Kubernetes Cluster:** A cluster (like kind) with correct port-forwarding for ports 80 and 443.
- **Installed Tooling:** kubectl and helm must be installed and configured to point to your cluster.
- **Installed Cluster Services:**
  - `ingress-nginx` (NGINX Ingress Controller)
  - `cert-manager`
- **Deployment Scripts:**
  - `setup-issuer.sh` (This script, for Phase 1)
  - `generate_participant.sh` (This script, for Phase 2)
- **Helm Chart:** The `participant-chart` directory.
- **Public DNS:** You must have public DNS "A" records pointing your hostnames (e.g., `conector-xdatashare.gradiant.org`) to your cluster's public IP address.
## Phase 1: Cluster-Level Setup (One-Time Only)

This phase configures `cert-manager` to communicate with Let's Encrypt, enabling automatic SSL certificate generation for the entire cluster.This only needs to be run once per new cluster.
 
### 1. Run the Setup Issuer Script

This script verifies that NGINX and `cert-manager` are ready, then creates the global `ClusterIssuer`. You must provide a valid email address for Let's Encrypt registration.
```bash
  # Make the script executable
  chmod +x setup-issuer.sh

  # Run the script, passing in your registration email
  ./setup-issuer.sh --email your-email@example.com
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

If `Status` is `True`, your cluster is now ready to automatically issue certificates for any participant.

## Phase 2: Deploying a New ParticipantRun these steps every time you need to add a new participant to the cluster.
### 1.Generate Participant Configuration

First, use the `generate_participant.sh` script to create the customized `values.yaml` file for your new participant. This script requires the participant's "main" hostname and its "Keycloak" hostname.

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

### 2. Deploy with Helm

Finally, use Helm to install the participant-chart, referencing the new values file you just created.

**Note:** We recommend deploying each participant into its own namespace.

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

Once `READY` is `True`, your participant is fully deployed, secured with HTTPS, and accessible at your domain (e.g., `https://conector-xdatashare.gradiant.org`).
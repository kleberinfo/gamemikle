# GameMiKle: Terraform + GitHub Actions + Azure

This setup provisions **Azure Static Web Apps** with Terraform and publishes the existing HTML game automatically from the `main` branch. The game continues to use the current Supabase backend; this change only addresses web hosting and deployment.

## What is automated

- Changes under `infra/terraform/` run Terraform formatting and validation. On pushes to `main`, the workflow plans and applies infrastructure changes.
- Changes to `index.html` (or future `assets/` or `public/` files) trigger the website deployment workflow.
- Terraform authenticates to Azure using GitHub OIDC / workload identity federation, so no Azure client secret is stored in the repository.
- Terraform state lives in a private Azure Blob container named `tfstate`.

The first-time Azure bootstrap is intentionally manual. It creates the identity and remote state store that Terraform itself depends on.

## Prerequisites

- An Azure subscription with permission to create resources and role assignments.
- Azure CLI and Terraform installed locally for the one-time bootstrap.
- Admin access to `kleberinfo/gamemikle`.
- The GitHub repository's default branch is `main`.

## 1. Create the bootstrap resources

Sign in and select the correct subscription:

```bash
az login
az account set --subscription "<AZURE_SUBSCRIPTION_ID>"
```

Choose a **globally unique, lowercase** storage account name for the Terraform state (3-24 letters or digits), then create the state resource group, state account, and container. Replace `<TFSTATE_STORAGE_ACCOUNT>` with your chosen name.

```bash
az group create --name rg-gamemikle-tfstate --location westeurope
az group create --name rg-gamemikle-prod --location westeurope

az storage account create \
  --name <TFSTATE_STORAGE_ACCOUNT> \
  --resource-group rg-gamemikle-tfstate \
  --location westeurope \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

az storage container create \
  --name tfstate \
  --account-name <TFSTATE_STORAGE_ACCOUNT> \
  --auth-mode key
```

Keep the state account private. The website deployment token and other sensitive values can be present in Terraform state, so do not publish the state file or store it in Git.

## 2. Create the GitHub OIDC identity

Create a user-assigned managed identity and a federated credential that trusts only the `main` branch of this repository:

```bash
az identity create \
  --name id-gamemikle-github-actions \
  --resource-group rg-gamemikle-tfstate

CLIENT_ID=$(az identity show \
  --name id-gamemikle-github-actions \
  --resource-group rg-gamemikle-tfstate \
  --query clientId -o tsv)

PRINCIPAL_ID=$(az identity show \
  --name id-gamemikle-github-actions \
  --resource-group rg-gamemikle-tfstate \
  --query principalId -o tsv)

az identity federated-credential create \
  --name github-main \
  --identity-name id-gamemikle-github-actions \
  --resource-group rg-gamemikle-tfstate \
  --issuer https://token.actions.githubusercontent.com \
  --subject repo:kleberinfo/gamemikle:ref:refs/heads/main \
  --audiences api://AzureADTokenExchange
```

Grant this identity access only to the required scopes. The commands below require an administrator who can assign Azure roles:

```bash
STATE_ACCOUNT_ID=$(az storage account show \
  --name <TFSTATE_STORAGE_ACCOUNT> \
  --resource-group rg-gamemikle-tfstate \
  --query id -o tsv)

APP_RG_ID=$(az group show \
  --name rg-gamemikle-prod \
  --query id -o tsv)

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STATE_ACCOUNT_ID"

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "$APP_RG_ID"
```

Role assignments may take a few minutes to propagate.

## 3. Add GitHub repository variables

Open **Settings → Secrets and variables → Actions → Variables** in the repository and create:

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | The `CLIENT_ID` from step 2 |
| `AZURE_TENANT_ID` | The Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | The subscription ID selected with Azure CLI |
| `AZURE_RESOURCE_GROUP` | `rg-gamemikle-prod` |
| `AZURE_LOCATION` | `westeurope` (optional; this is the default) |
| `TFSTATE_RESOURCE_GROUP` | `rg-gamemikle-tfstate` |
| `TFSTATE_STORAGE_ACCOUNT` | The unique state storage account name |

These are identifiers, not passwords or client secrets. Do not create an Azure client secret for this pipeline.

## 4. Run Terraform

Once the variables, OIDC identity, permissions, and state container are ready:

1. Open **Actions → Terraform - Azure infrastructure**.
2. Select **Run workflow** on `main`.
3. Wait for validation, plan, and apply.
4. Open the workflow log and note the resulting Static Web Apps URL from the Terraform outputs.

The Terraform resource is configured for the **Free** Azure Static Web Apps SKU and prevents accidental deletion via Terraform. Review infrastructure plans before applying future changes.

## 5. Configure automatic website deployment

Terraform state stores the Static Web Apps deployment token as a sensitive output. Retrieve it locally; do not paste it into source code or a public issue.

From a local clone, first authenticate with Azure CLI:

```bash
az login
az account set --subscription "<AZURE_SUBSCRIPTION_ID>"
cd infra/terraform
```

Initialize the backend using Azure CLI authentication for this local session. Replace the state account value:

```bash
terraform init -reconfigure \
  -backend-config="resource_group_name=rg-gamemikle-tfstate" \
  -backend-config="storage_account_name=<TFSTATE_STORAGE_ACCOUNT>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=gamemikle.tfstate" \
  -backend-config="use_cli=true" \
  -backend-config="use_azuread_auth=true"

terraform output -raw deployment_token
```

Copy that output directly into **Settings → Secrets and variables → Actions → Secrets** as:

`AZURE_STATIC_WEB_APPS_API_TOKEN`

Then add the repository variable `AZURE_DEPLOY_ENABLED` with value `true`. A push to `main` that changes `index.html` will now publish the game automatically. You can also start **Deploy GameMiKle to Azure Static Web Apps** manually from the Actions page.

## Safety notes

- Never commit `.tfstate`, plan files, deployment tokens, passwords, or client secrets.
- The GitHub OIDC identity is trusted only for the repository's `main` branch in this starter configuration. If you add workflows that run Terraform from other refs or environments, add narrowly scoped federated credentials intentionally.
- The Free SKU is a starting point, not a guarantee that all future traffic or features will fit within free quotas.
- This does not migrate Supabase. User accounts, saves, rankings, trades, and real-time features remain on Supabase until a separate backend migration is designed and tested.
- GitHub Actions deployment of the website is separate from packaging the game for Google Play or the Apple App Store.

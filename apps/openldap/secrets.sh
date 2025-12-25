#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="openldap"
SECRET_NAME="openldap-secrets"
DEPLOYMENT_FILE="$(dirname "$0")/deployment.yaml"

echo -e "${GREEN}=== OpenLDAP Sealed Secrets Generator ===${NC}"
echo ""

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo -e "${RED}Error: kubeseal is not installed${NC}"
    echo "Please install kubeseal: https://github.com/bitnami-labs/sealed-secrets"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Prompt for passwords
echo -e "${YELLOW}Please enter the LDAP passwords:${NC}"
echo ""

read -sp "LDAP Admin Password: " LDAP_ADMIN_PASSWORD
echo ""
echo ""
echo ""
echo ""

# Validate passwords are not empty
if [[ -z "$LDAP_ADMIN_PASSWORD" ]]; then
    echo -e "${RED}Error: LDAP Admin password must be provided${NC}"
    exit 1
fi

echo -e "${GREEN}Generating sealed secrets...${NC}"

# Create temporary secret manifest
TMP_SECRET=$(mktemp)
cat > "$TMP_SECRET" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
type: Opaque
stringData:
  LDAP_ADMIN_PASSWORD: "$LDAP_ADMIN_PASSWORD"
EOF

# Generate sealed secret
TMP_SEALED=$(mktemp)
if ! kubeseal --format=yaml < "$TMP_SECRET" > "$TMP_SEALED" 2>/dev/null; then
    echo -e "${RED}Error: Failed to generate sealed secret${NC}"
    echo "Make sure you have access to your Kubernetes cluster and sealed-secrets controller is running"
    rm -f "$TMP_SECRET" "$TMP_SEALED"
    exit 1
fi

# Extract encrypted values using yq or python
if command -v yq &> /dev/null; then
    ENCRYPTED_ADMIN=$(yq eval '.spec.encryptedData.LDAP_ADMIN_PASSWORD' "$TMP_SEALED")
elif command -v python3 &> /dev/null; then
    ENCRYPTED_ADMIN=$(python3 -c "import yaml; print(yaml.safe_load(open('$TMP_SEALED'))['spec']['encryptedData']['LDAP_ADMIN_PASSWORD'])")
else
    echo -e "${YELLOW}Warning: Neither yq nor python3 found. Using grep/awk fallback${NC}"
    ENCRYPTED_ADMIN=$(grep "LDAP_ADMIN_PASSWORD:" "$TMP_SEALED" | awk '{print $2}')
fi

# Cleanup temp files
rm -f "$TMP_SECRET" "$TMP_SEALED"

# Validate encrypted values
if [[ -z "$ENCRYPTED_ADMIN" ]]; then
    echo -e "${RED}Error: Failed to extract encrypted value${NC}"
    exit 1
fi

echo -e "${GREEN}Updating deployment.yaml with new sealed secrets...${NC}"

# Create a temporary file with the updated content
TMP_DEPLOYMENT=$(mktemp)

# Use sed to replace the encrypted values (handles multi-line values)
sed -e "/LDAP_ADMIN_PASSWORD:/,/LDAP_CONFIG_PASSWORD:/ {
    s|LDAP_ADMIN_PASSWORD:.*|LDAP_ADMIN_PASSWORD: $ENCRYPTED_ADMIN|
}" "$DEPLOYMENT_FILE" > "$TMP_DEPLOYMENT"

# Replace the original file
mv "$TMP_DEPLOYMENT" "$DEPLOYMENT_FILE"

echo ""
echo -e "${GREEN}✓ Successfully updated sealed secrets in deployment.yaml${NC}"
echo ""
echo -e "You can now apply the updated deployment:"
echo -e "  ${GREEN}kubectl apply -f $DEPLOYMENT_FILE${NC}"

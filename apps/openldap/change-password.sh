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
POD_NAME="openldap-0"

echo -e "${GREEN}=== OpenLDAP Password Change Tool ===${NC}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if pod is running
if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: Pod $POD_NAME not found in namespace $NAMESPACE${NC}"
    exit 1
fi

POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo -e "${RED}Error: Pod $POD_NAME is not running (status: $POD_STATUS)${NC}"
    exit 1
fi

# Get current base DN from configmap
BASE_DN=$(kubectl get configmap openldap-env -n "$NAMESPACE" -o jsonpath='{.data.LDAP_BASE_DN}')
if [ -z "$BASE_DN" ]; then
    echo -e "${RED}Error: Could not retrieve LDAP_BASE_DN from configmap${NC}"
    exit 1
fi

echo -e "${YELLOW}Current LDAP Base DN: $BASE_DN${NC}"
echo ""

# Prompt for current admin password
read -sp "Enter current LDAP Admin Password: " CURRENT_ADMIN_PASSWORD
echo ""
# Prompt for new admin password
read -sp "Enter new LDAP Admin Password: " NEW_ADMIN_PASSWORD
echo ""
read -sp "Confirm new LDAP Admin Password: " NEW_ADMIN_PASSWORD_CONFIRM
echo ""
echo ""

# Validate passwords
if [ -z "$CURRENT_ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: Current admin password cannot be empty${NC}"
    exit 1
fi

if [ -z "$NEW_ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: New admin password cannot be empty${NC}"
    exit 1
fi

if [ "$NEW_ADMIN_PASSWORD" != "$NEW_ADMIN_PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Error: Admin passwords do not match${NC}"
    exit 1
fi

echo -e "${GREEN}Changing LDAP admin (rootpw) password in OpenLDAP config...${NC}"

# Generate password hash inside the pod
HASH=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- slappasswd -s "$NEW_ADMIN_PASSWORD")
if [ -z "$HASH" ]; then
    echo -e "${RED}Error: Failed to generate password hash.${NC}"
    exit 1
fi

# Create LDIF file
LDIF_FILE="/tmp/change-rootpw.ldif"
cat <<EOF > "$LDIF_FILE"
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcRootPW
olcRootPW: $HASH
EOF

# Copy LDIF to pod
kubectl cp "$LDIF_FILE" "$NAMESPACE/$POD_NAME:/tmp/change-rootpw.ldif"

# Apply LDIF inside the pod
if kubectl exec -n "$NAMESPACE" "$POD_NAME" -- ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/change-rootpw.ldif; then
    echo -e "${GREEN}✓ Admin (rootpw) password changed successfully in OpenLDAP config${NC}"
else
    echo -e "${RED}Error: Failed to change admin (rootpw) password in OpenLDAP config.${NC}"
    exit 1
fi

# Clean up
rm -f "$LDIF_FILE"


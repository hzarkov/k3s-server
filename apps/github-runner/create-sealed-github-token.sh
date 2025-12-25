#!/bin/bash
# Usage: ./create-sealed-github-token.sh
# Prompts for GitHub token, seals it, and updates deployment.yaml in-place.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENT_FILE="$SCRIPT_DIR/deployment.yaml"
SECRET_NAME=github-runner-token
NAMESPACE=github-runner

read -rsp "Enter your GitHub registration token: " GITHUB_TOKEN
echo

# Create a Kubernetes Secret manifest in a temp file
TMP_SECRET=$(mktemp)
cat <<EOF > "$TMP_SECRET"
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $NAMESPACE
stringData:
  GITHUB_TOKEN: "$GITHUB_TOKEN"
EOF

# Seal the secret (requires kubeseal and access to the SealedSecrets controller)
echo "Sealing the secret..."
SEALED_SECRET=$(kubeseal --format yaml < "$TMP_SECRET")
rm "$TMP_SECRET"

# Extract the sealed value for GITHUB_TOKEN
SEALED_VALUE=$(echo "$SEALED_SECRET" | awk '/GITHUB_TOKEN:/ {print $2}')

# Update deployment.yaml in-place
echo "Updating deployment.yaml with new sealed token..."
sed -i "/GITHUB_TOKEN:/c\    GITHUB_TOKEN: \"$SEALED_VALUE\"" "$DEPLOYMENT_FILE"

echo "deployment.yaml updated with new sealed GitHub token."

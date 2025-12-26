#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <pub-cert.pem>"
  exit 1
fi

CERT_FILE="$1"
VALUES_FILE="values.yaml"
NAMESPACE="ldap"

# List of secrets to prompt for and their YAML paths
# Format: [yaml_path]=k8s_secret_name
# yaml_path should match the key in values.yaml (dot notation)
declare -A SECRETS=(
  ["openldap.sealedSecrets.adminPassword"]="openldap-admin-password"
  ["authentik.sealedSecrets.secretKey"]="authentik-secret-key"
  ["authentik.sealedSecrets.postgresqlPassword"]="authentik-postgresql-password"
)

for key in "${!SECRETS[@]}"; do
  secret_name="${SECRETS[$key]}"
  leaf_key="${key##*.}"
  echo -n "Enter value for $key: "
  read -s secret_value
  echo

  # Create a temporary secret manifest
  tmpfile=$(mktemp)
  cat > "$tmpfile" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $secret_name
  namespace: $NAMESPACE
type: Opaque
data:
  value: $(echo -n "$secret_value" | base64)
EOF

  # Seal the secret and extract the encrypted value using the provided cert
  sealed_value=$(kubeseal --cert "$CERT_FILE" --format yaml < "$tmpfile" | awk '/value:/{print $2; exit}')

  # Replace the value in values.yaml by matching only the leaf key (e.g., adminPassword: "...")
  sed -i "s|^\([[:space:]]*$leaf_key: \)\".*\"|\1\"$sealed_value\"|" "$VALUES_FILE"

  rm "$tmpfile"
done

echo "Sealed secrets updated in $VALUES_FILE"

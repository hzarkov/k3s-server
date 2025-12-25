#!/bin/bash
# Script to automate Authentik initial configuration via API
# Requirements: jq, curl
# Usage: ./configure-authentik.sh <admin_email> <admin_password> <ldap_host> <ldap_bind_dn> <ldap_bind_pw> <ldap_base_dn>

set -e

if [ $# -ne 6 ]; then
  echo "Usage: $0 <admin_email> <admin_password> <ldap_host> <ldap_bind_dn> <ldap_bind_pw> <ldap_base_dn>"
  exit 1
fi

ADMIN_EMAIL="$1"
ADMIN_PASSWORD="$2"
LDAP_HOST="$3"
LDAP_BIND_DN="$4"
LDAP_BIND_PW="$5"
LDAP_BASE_DN="$6"

# Wait for Authentik to be ready
until curl -s http://localhost:9000/api/v3/core/version/ > /dev/null; do
  echo "Waiting for Authentik API..."
  sleep 5
done

# Get admin token
TOKEN=$(curl -s -X POST http://localhost:9000/api/v3/auth/token/ -d "username=admin&password=$ADMIN_PASSWORD" | jq -r .access_token)

# Create LDAP provider
curl -s -X POST http://localhost:9000/api/v3/providers/ldap/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ldap-provider",
    "server_uri": "ldap://'$LDAP_HOST'",
    "bind_dn": "'$LDAP_BIND_DN'",
    "bind_password": "'$LDAP_BIND_PW'",
    "base_dn": "'$LDAP_BASE_DN'",
    "property_mappings": [],
    "start_tls": false
  }'

echo "LDAP provider created."
# Add more API calls here to automate further setup (sync, applications, policies, etc.)

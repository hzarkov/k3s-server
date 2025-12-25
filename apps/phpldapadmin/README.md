# phpLDAPadmin

This directory contains the Kubernetes manifests for deploying phpLDAPadmin, a web-based LDAP administration interface.

## Overview

phpLDAPadmin provides a user-friendly web interface for managing your OpenLDAP server. It's deployed as a separate application but connects to the OpenLDAP service in the same namespace.

## Architecture

- **Deployment**: Single replica running osixia/phpldapadmin:0.9.0
- **LoadBalancer Service**: Exposes HTTP (80) and HTTPS (443) ports externally
- **ConfigMap**: Configuration for LDAP server connection
- **Namespace**: Deployed in the `openldap` namespace

## Configuration

### Environment Variables (ConfigMap: phpldapadmin-env)

- `PHPLDAPADMIN_LDAP_HOSTS`: LDAP server address (default: "openldap.openldap.svc.cluster.local")
- `PHPLDAPADMIN_HTTPS`: Enable HTTPS (default: "false")
- `PHPLDAPADMIN_TRUST_PROXY_SSL`: Trust proxy SSL (default: "true")

## Accessing phpLDAPadmin

### Get the External IP:
```bash
kubectl get svc phpldapadmin -n openldap
```

### Access in Browser:
```
http://<EXTERNAL-IP>
```

### Login Credentials:
- **Login DN**: `cn=admin,dc=hzarkov,dc=space`
- **Password**: The admin password from the OpenLDAP SealedSecret (currently: "changeme_admin_password")

## Usage

Once logged in, you can:
- Browse the LDAP directory tree
- Create organizational units (OUs)
- Add, edit, and delete users
- Manage groups
- Modify LDAP attributes
- Import/export LDIF files

## Common Tasks

### Create Organizational Unit:
1. Click on "dc=hzarkov,dc=space" in the tree
2. Click "Create a child entry"
3. Select "Generic: Organisational Unit"
4. Enter the OU name (e.g., "users", "groups")
5. Click "Create Object"

### Add a User:
1. Navigate to the desired OU (e.g., "ou=users")
2. Click "Create a child entry"
3. Select "Generic: User Account"
4. Fill in the required fields (cn, sn, uid, password)
5. Click "Create Object"

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n openldap -l app=phpldapadmin

# View logs
kubectl logs -n openldap -l app=phpldapadmin

# Describe pod for events
kubectl describe pod -n openldap -l app=phpldapadmin

# Check service
kubectl get svc phpldapadmin -n openldap
```

### Common Issues:

**Cannot connect to LDAP server:**
- Ensure OpenLDAP pods are running: `kubectl get pods -n openldap -l app=openldap`
- Check service connectivity: `kubectl get svc openldap -n openldap`

**Login failed:**
- Verify the admin password in the OpenLDAP SealedSecret
- Check LDAP logs: `kubectl logs openldap-0 -n openldap`

## Security Recommendations

1. **Use strong passwords**: Update the OpenLDAP admin password via SealedSecret
2. **Enable HTTPS**: Set `PHPLDAPADMIN_HTTPS: "true"` and provide TLS certificates
3. **Restrict access**: Use NetworkPolicies or Ingress with authentication
4. **Regular updates**: Keep the phpLDAPadmin image updated for security patches
5. **Audit logs**: Monitor phpLDAPadmin access logs regularly

## Dependencies

- **OpenLDAP**: phpLDAPadmin requires the OpenLDAP service to be running
- Service connection: `openldap.openldap.svc.cluster.local:389`

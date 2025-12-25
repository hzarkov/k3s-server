# OpenLDAP Deployment

This directory contains the Kubernetes manifests for deploying OpenLDAP using the `osixia/openldap` Docker image.

## Architecture

- **StatefulSet**: Ensures stable network identity and persistent storage for each pod
- **Headless Service (openldap)**: Enables direct pod-to-pod communication and DNS resolution (internal only)
- **SealedSecret**: Encrypted secrets stored safely in Git (decrypted by the controller at runtime)
- **PersistentVolumeClaims**: 
  - `/var/lib/ldap` - LDAP database files (1GB)
  - `/etc/ldap/slapd.d` - LDAP configuration files (256MB)
- **Domain**: hzarkov.bg (dc=hzarkov,dc=space)

**Note**: The LDAP server is only accessible within the k3s cluster for security. External access can be added later if needed.

## Related Applications

- **phpLDAPadmin**: Web-based LDAP management interface (see [apps/phpldapadmin](../phpldapadmin/README.md))
  - Deployed as a separate application
  - Automatically configured to connect to this OpenLDAP server

## Configuration

### Sealed Secrets (Encrypted Secrets in Git)


This deployment uses **Sealed Secrets** to securely store the initial admin password in Git. Only the admin password is required and managed.

**Password management workflow:**

1. Run `secrets.sh` to generate and seal the initial admin password. This updates the SealedSecret in `deployment.yaml`.
2. Deploy or redeploy OpenLDAP. The admin password from the sealed secret is used only for initial setup or if the persistent data is wiped.
3. To change the admin password after deployment, use `change-password.sh`. This updates the password directly in the running LDAP server.
4. The password set with `change-password.sh` will persist as long as the LDAP data volume is not deleted, regardless of the value in `deployment.yaml`.
5. If you redeploy and wipe the LDAP data, the password from the sealed secret will be used again.

### Environment Variables (ConfigMap: openldap-env)

**Core Settings:**
- `LDAP_ORGANISATION`: Organization name (default: "HZarkov Space")
- `LDAP_DOMAIN`: LDAP domain (default: "hzarkov.bg")
- `LDAP_BASE_DN`: Base DN (default: "dc=hzarkov,dc=space")

**Security (stored in SealedSecret):**
- `LDAP_ADMIN_PASSWORD`: Admin password (encrypted in Git)

**TLS Settings:**
- `LDAP_TLS`: Enable TLS (default: "true")
- `LDAP_TLS_ENFORCE`: Enforce TLS connections (default: "false")
- `LDAP_TLS_VERIFY_CLIENT`: Client certificate verification (default: "demand")

**Advanced:**
- `LDAP_READONLY_USER`: Create a read-only user (default: "false")
- `LDAP_BACKEND`: Database backend (default: "mdb")
- `LDAP_REPLICATION`: Enable replication for multi-master setup

### Accessing Persistent Volumes

The persistent volumes are mounted on the k3s node(s) where the pods are scheduled. To access them:

1. Find the pod and node:
   ```bash
   kubectl get pods -n openldap -o wide
   ```

2. Find the PVC and PV:
   ```bash
   kubectl get pvc -n openldap
   kubectl get pv
   ```

3. The volumes are stored in `/var/lib/rancher/k3s/storage/` on the node by default (k3s local-path provisioner)

4. To edit files, you can:
   - SSH into the node and navigate to the volume path
   - Use `kubectl exec` to access the pod:
     ```bash
     kubectl exec -it openldap-0 -n openldap -- /bin/bash
     ```

## Scaling

To scale the LDAP deployment:

```bash
kubectl scale statefulset openldap -n openldap --replicas=3
```

**Important Notes for Scaling:**
- Each replica gets its own persistent storage
- For true multi-master replication, you need to:
  1. Set `LDAP_REPLICATION: "true"` in the ConfigMap
  2. Configure replication settings (see osixia/openldap documentation)
  3. Ensure network connectivity between pods
- Without replication configured, each instance will have its own independent data

## Accessing LDAP

### Web Interface (phpLDAPadmin):
For a user-friendly web interface to manage your LDAP server, see the [phpLDAPadmin app](../phpldapadmin/README.md).

### From within the cluster:
```bash
# Using the headless service (connects to a specific pod)
ldap://openldap-0.openldap.svc.cluster.local:389

# Using the service (round-robin to any pod)
ldap://openldap.openldap.svc.cluster.local:389
```

### From your local machine (via port-forward):
```bash
# Forward LDAP port to localhost
kubectl port-forward -n openldap svc/openldap 389:389

# Then connect to localhost
ldap://localhost:389
```

**Note**: The LDAP server is not exposed externally. Use port-forward or connect from applications running within the cluster.

## Testing the Deployment

### Using phpLDAPadmin (Web Interface):
See the [phpLDAPadmin documentation](../phpldapadmin/README.md) for web-based management.

### Using Command Line:
```bash
# Check if LDAP is responding
kubectl exec -it openldap-0 -n openldap -- ldapsearch -x -H ldap://localhost -b dc=hzarkov,dc=space -D "cn=admin,dc=hzarkov,dc=space" -w changeme_admin_password

# Add a test organizational unit
kubectl exec -it openldap-0 -n openldap -- bash -c 'ldapadd -x -D "cn=admin,dc=hzarkov,dc=space" -w changeme_admin_password << EOF
dn: ou=users,dc=hzarkov,dc=space
objectClass: organizationalUnit
ou: users
EOF'
```

## Security Recommendations

1. **Update Sealed Secrets with Strong Passwords**: Follow the instructions in the "Sealed Secrets" section above to update passwords
2. **Enable TLS enforcement**: Set `LDAP_TLS_ENFORCE: "true"` in the ConfigMap and provide proper certificates
3. **Network Policies**: Restrict access to LDAP ports using NetworkPolicies
4. **RBAC**: Configure proper role-based access control in Kubernetes
5. **Backup the Sealed Secrets Private Key**: The controller's private key is stored in the cluster and should be backed up:
   ```bash
   sudo kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
   ```
   Store this backup securely - it's needed to decrypt your secrets if you rebuild the cluster.

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n openldap

# View logs
kubectl logs openldap-0 -n openldap

# Describe pod for events
kubectl describe pod openldap-0 -n openldap

# Check PVC status
kubectl get pvc -n openldap

# Access pod shell
kubectl exec -it openldap-0 -n openldap -- /bin/bash
```

## Backup and Restore

### Backup:
```bash
kubectl exec openldap-0 -n openldap -- slapcat -n 0 > config-backup.ldif
kubectl exec openldap-0 -n openldap -- slapcat -n 1 > data-backup.ldif
```

### Restore:
```bash
cat config-backup.ldif | kubectl exec -i openldap-0 -n openldap -- slapadd -n 0 -l /dev/stdin
cat data-backup.ldif | kubectl exec -i openldap-0 -n openldap -- slapadd -n 1 -l /dev/stdin
```

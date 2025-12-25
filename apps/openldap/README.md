# OpenLDAP Deployment

This directory contains the Kubernetes manifests for deploying OpenLDAP using the `osixia/openldap` Docker image.

## Architecture

- **StatefulSet**: Ensures stable network identity and persistent storage for each pod
- **Headless Service (openldap)**: Enables direct pod-to-pod communication and DNS resolution
- **LoadBalancer Service (openldap-lb)**: Exposes LDAP ports 389 and 636 externally
- **SealedSecret**: Encrypted secrets stored safely in Git (decrypted by the controller at runtime)
- **PersistentVolumeClaims**: 
  - `/var/lib/ldap` - LDAP database files
  - `/etc/ldap/slapd.d` - LDAP configuration files

## Configuration

### Sealed Secrets (Encrypted Secrets in Git)

This deployment uses **Sealed Secrets** to securely store sensitive data in Git. The SealedSecret is encrypted and can only be decrypted by the Sealed Secrets controller running in your cluster.

**Current encrypted secrets:**
- `LDAP_ADMIN_PASSWORD` - Admin password (currently: "changeme_admin_password")
- `LDAP_CONFIG_PASSWORD` - Config password (currently: "changeme_config_password")
- `LDAP_READONLY_USER_PASSWORD` - Read-only user password

**To update passwords:**

1. Create a new secret file with your desired passwords:
```bash
cat > /tmp/openldap-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: openldap-secrets
  namespace: openldap
type: Opaque
stringData:
  LDAP_ADMIN_PASSWORD: "your-secure-admin-password"
  LDAP_CONFIG_PASSWORD: "your-secure-config-password"
  LDAP_READONLY_USER_PASSWORD: "your-secure-readonly-password"
EOF
```

2. Encrypt it using kubeseal:
```bash
sudo kubeseal --kubeconfig=/etc/rancher/k3s/k3s.yaml --format=yaml \
  < /tmp/openldap-secret.yaml > /tmp/sealed-secret.yaml
```

3. Replace the SealedSecret section in `deployment.yaml` with the new encrypted content

4. Commit and push to Git

### Environment Variables (ConfigMap: openldap-env)

**Core Settings:**
- `LDAP_ORGANISATION`: Organization name (default: "Example Organization")
- `LDAP_DOMAIN`: LDAP domain (default: "example.com")
- `LDAP_BASE_DN`: Base DN (default: "dc=example,dc=com")

**Security (stored in SealedSecret):**
- `LDAP_ADMIN_PASSWORD`: Admin password (encrypted in Git)
- `LDAP_CONFIG_PASSWORD`: Config password (encrypted in Git)
- `LDAP_READONLY_USER_PASSWORD`: Read-only user password (encrypted in Git)

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

### From within the cluster:
```bash
# Using the headless service (connects to a specific pod)
ldap://openldap-0.openldap.openldap.svc.cluster.local:389

# Using the load balancer service (round-robin)
ldap://openldap-lb.openldap.svc.cluster.local:389
```

### From outside the cluster:
```bash
# Get the external IP of the LoadBalancer
kubectl get svc openldap-lb -n openldap

# Connect using the external IP
ldap://<EXTERNAL-IP>:389
ldaps://<EXTERNAL-IP>:636
```

## Testing the Deployment

```bash
# Check if LDAP is responding
kubectl exec -it openldap-0 -n openldap -- ldapsearch -x -H ldap://localhost -b dc=example,dc=com -D "cn=admin,dc=example,dc=com" -w admin

# Add a test user
kubectl exec -it openldap-0 -n openldap -- bash
ldapadd -x -D "cn=admin,dc=example,dc=com" -w admin << EOF
dn: ou=users,dc=example,dc=com
objectClass: organizationalUnit
ou: users
EOF
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

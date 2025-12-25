# Fleet Setup Guide for k3s

## Step 1: Install Fleet in your k3s cluster

```bash
# Install Fleet
kubectl apply -f https://github.com/rancher/fleet/releases/latest/download/fleet.yaml

# Wait for Fleet to be ready
kubectl -n cattle-fleet-system rollout status deploy/fleet-controller
```

## Step 2: Generate SSH Key for Fleet

```bash
# Generate a dedicated SSH key for Fleet (no passphrase)
ssh-keygen -t ed25519 -f ~/.ssh/fleet-k3s-server -C "fleet-k3s-server" -N ""

# Display the public key
cat ~/.ssh/fleet-k3s-server.pub
```

## Step 3: Add Deploy Key to GitHub

1. Copy the public key output from the previous step
2. Go to https://github.com/hzarkov/k3s-server/settings/keys
3. Click "Add deploy key"
4. Title: `fleet-k3s-server`
5. Paste the public key
6. **DO NOT** check "Allow write access" (read-only is safer)
7. Click "Add key"

## Step 4: Create Kubernetes Secret with SSH Key

```bash
# Create namespace for Fleet local cluster
kubectl create namespace fleet-local

# Create secret with the private SSH key
kubectl create secret generic fleet-git-ssh \
  --from-file=ssh-privatekey=/home/master-server/.ssh/fleet-k3s-server \
  --from-literal=known_hosts="$(ssh-keyscan github.com 2>/dev/null)" \
  -n fleet-local

# Label the secret for Fleet
kubectl label secret fleet-git-ssh \
  -n fleet-local \
  fleet.cattle.io/managed=true
```

## Step 5: Register the GitRepository with Fleet

Create a GitRepo resource to tell Fleet to monitor your repository:

```bash
kubectl apply -f - <<EOF
apiVersion: fleet.cattle.io/v1alpha1
kind: GitRepo
metadata:
  name: k3s-server
  namespace: fleet-local
spec:
  repo: git@github.com:hzarkov/k3s-server.git
  branch: main
  paths:
  - apps
  clientSecretName: fleet-git-ssh
  pollingInterval: 1m
EOF
```

## Step 6: Verify Fleet is Working

```bash
# Check GitRepo status
kubectl get gitrepo -n fleet-local

# Check bundles (Fleet's deployment units)
kubectl get bundles -n fleet-local

# Check Fleet logs if there are issues
kubectl logs -n cattle-fleet-system -l app=fleet-controller --tail=100
```

## Step 7: Push Initial Configuration to GitHub

```bash
# From your k3s-server directory
cd /home/master-server/k3s-server

# Initialize git repository
git init
git add .
git commit -m "Initial Fleet GitOps setup"

# Add remote and push
git remote add origin git@github.com:hzarkov/k3s-server.git
git branch -M main
git push -u origin main
```

## Troubleshooting

### Check GitRepo Status
```bash
kubectl describe gitrepo k3s-server -n fleet-local
```

### Common Issues

1. **SSH Key Issues**: Verify the secret contains the correct key
   ```bash
   kubectl get secret fleet-git-ssh -n fleet-local -o yaml
   ```

2. **Permission Denied**: Ensure the deploy key is added to GitHub

3. **Bundle Not Created**: Check Fleet controller logs
   ```bash
   kubectl logs -n cattle-fleet-system -l app=fleet-controller
   ```

## Next Steps

- Add your applications to the `apps/` directory
- Commit and push changes
- Fleet will automatically deploy them to your cluster

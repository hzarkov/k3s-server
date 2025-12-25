# Docker Registry for k3s

This directory contains Kubernetes manifests to deploy a private Docker registry inside your k3s cluster.

## Deployment Steps

1. Apply the namespace:
   kubectl apply -f namespace.yaml

2. Deploy the registry:
   kubectl apply -f deployment.yaml

3. (Optional) Expose the registry outside the cluster by editing the Service to type: NodePort or LoadBalancer.

4. (Recommended) For persistent storage, replace `emptyDir` in deployment.yaml with a PersistentVolumeClaim.

## Usage
- Push images: `docker push <node-ip>:5000/myimage:tag`
- Pull images: `docker pull <node-ip>:5000/myimage:tag`

## Security
- This example is for internal/test use. For production, add authentication and TLS.

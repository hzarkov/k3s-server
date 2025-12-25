# GitHub Actions Self-Hosted Runner on k3s

This manifest deploys a self-hosted GitHub Actions runner as a Kubernetes Deployment in the `github-runner` namespace.

## Setup Steps

1. Replace `REPLACE_WITH_YOUR_TOKEN` in the Secret with your GitHub registration token (from your repo or org settings).
2. Replace `OWNER/REPO` in the `REPO_URL` env var with your GitHub repository (or org) path.
3. Apply the manifest:
   kubectl apply -f deployment.yaml

## Notes
- The runner will register with your GitHub repo and pick up jobs assigned to self-hosted runners.
- For multiple runners, increase `replicas`.
- For organization-wide runners, adjust the `REPO_URL` accordingly.
- For security, use a PersistentVolume for the workdir if needed.
- See: https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners

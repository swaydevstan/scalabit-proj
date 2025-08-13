#!/bin/bash
set -e

apt-get update
apt-get install -y curl wget

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

gcloud auth configure-docker ${region}-docker.pkg.dev --quiet

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -

while ! kubectl get nodes; do
  echo "Waiting for k3s to be ready..."
  sleep 10
done

kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

sleep 30

echo "K3s and Gatekeeper setup completed successfully."
#!/bin/bash
set -e
IMAGE_TAG="$1"
sed -i "s|IMAGE_PLACEHOLDER|${IMAGE_TAG}|g" manifests/deployment.yaml
export KUBECONFIG=/etc/k3s/deployer-kube/config
kubectl apply -f policy/
sleep 10
kubectl apply -f manifests/namespace.yaml
sleep 10
kubectl apply -f manifests/
kubectl rollout status deployment/scalabit-api -n scalabit --timeout=60s
# Project Overview

This repository provides a  solution for deploying and managing a NodeJs API in a protected Virtual Machine on Google Cloud running K3s. It includes application code, infrastructure as code (Terraform), Kubernetes manifests, policy definitions, and CI/CD automation with GitHub Actions.

## Folder Structure

- **infra/**: Infrastructure as Code using Terraform.
	- `main.tf`: Main Terraform configuration for provisioning cloud resources (e.g., compute, networking, storage).
	- `variables.tf`: Input variables to parameterize the infrastructure.
	- `outputs.tf`: Output values from the Terraform deployment (e.g., IP addresses, resource IDs).
	- `setupscript.sh`: Helper script for installing K3s and provisioning some Kubernetes CRDs

- **manifests/**: Kubernetes manifest files for deploying the application.
	- `namespace.yaml`: Defines a dedicated Kubernetes namespace for resource isolation.
	- `deployment.yaml`: Describes the deployment of application pods.
	- `service.yaml`: Exposes the application within the cluster or to external clients.
	- `ingress.yaml`: Configures ingress rules for external HTTP/HTTPS access to the app.

- **policy/**: Policy as Code for governance and compliance.
	- `constraints.yml`: Defines policy for preventing deployment of containers if image is not from a specific google artifact registry
	- `constraintstemplate.yml`: Template for creating reusable policy constraints.

- **.github/workflows/**: GitHub Actions workflows for CI/CD automation.
    - `terraform-deploy.yaml`: Workflow to deploy terraform infrastructure to Google Cloud. Authentication to google cloud done via [Workload Identity Federation](https://github.com/google-github-actions/auth?tab=readme-ov-file#preferred-direct-workload-identity-federation)
	- `app-deploy.yaml`: Workflow to build the docker image as well as deploy the app to K3s

- **deployscript.sh**: Script to automate deployment steps, for deploying the app in the K3s cluster
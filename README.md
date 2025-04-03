# Azure Red Hat OpenShift (ARO) Deployment

![Red Hat OpenShift Logo](https://microsoft.github.io/aroworkshop/img/redhat-openshift.png)

## Overview

Azure Red Hat OpenShift (ARO) provides highly available, fully managed OpenShift clusters on demand, monitored and operated jointly by Microsoft and Red Hat. Kubernetes is at the core of Red Hat OpenShift. The service-level agreement (SLA) guarantees 99.95% availability.

This repository contains Ansible automation to simplify the deployment of an Azure Red Hat OpenShift cluster. The playbook automates the process described in the [official Microsoft documentation](https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster).

## Features

- **Fully automated deployment** - Deploy a production-ready ARO cluster with a single command
- **Best practices included** - Networking, security, and scaling considerations built-in
- **Idempotent execution** - Run the playbook multiple times safely
- **Comprehensive output** - Detailed cluster information saved for easy access

## Prerequisites

Before running the playbook, ensure you have:

- **Azure CLI** - [Installation instructions](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Azure subscription** with sufficient quota (40-50 vCPUs in target region)
- **Ansible** (v2.9+) with the `azure.azcollection` collection installed
  ```bash
  ansible-galaxy collection install azure.azcollection
  pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt
  ```
- **OpenShift CLI tools** - [Latest `oc` & `kubectl` binaries](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/)
- **Red Hat Pull Secret** (strongly recommended) - [Available from cloud.redhat.com](https://cloud.redhat.com)

## Quota Requirements

Ensure you have sufficient quota in your target Azure region:

```bash
# Check total vCPU quota
az vm list-usage --location "Central US" --output table | grep "Total Regional vCPUs"

# Check DSv3 family quota (for worker nodes)
az vm list-usage --location "Central US" --output table | grep "Standard DSv3 Family vCPUs"
```

## Getting Started

1. Clone this repository
   ```bash
   git clone https://github.com/your-username/aro-deployment.git
   cd aro-deployment
   ```

2. Download your Red Hat pull secret and save it as `pull-secret.txt` in the repository directory

3. Review and modify the `aro_vars.yml` file to customize your deployment

4. Authenticate to Azure
   ```bash
   az login
   ```

5. Run the playbook
   ```bash
   ansible-playbook aro_deployment.yml
   ```

6. Access your cluster using the information in the generated `aro-cluster-info-*.txt` file

## Configuration Options

The deployment can be customized through the `aro_vars.yml` file:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `location` | Azure region for deployment | centralus |
| `resource_group` | Resource group name | aro |
| `vnet_name` | Virtual network name | aro-vnet |
| `cluster_name` | ARO cluster name | aro-cluster |
| `domain` | Custom domain (optional) | openshifthelp.com |
| `master_vm_size` | VM size for master nodes | Standard_D8s_v3 |
| `worker_vm_size` | VM size for worker nodes | Standard_D4s_v3 |
| `worker_count` | Number of worker nodes | 3 |

## Post-Deployment Steps

After deployment completes:

1. Access the OpenShift console URL provided in the output
2. Log in with the kubeadmin credentials
3. Configure OAuth or other authentication methods
4. Install the OpenShift GitOps Operator for CI/CD capabilities
5. Deploy your applications

## Troubleshooting

Common issues and their solutions:

- **Quota exceeded**: Request additional quota through the Azure portal
- **Network connectivity issues**: Verify your firewall settings
- **Authentication failures**: Ensure your Azure credentials are valid

For more help, see the [ARO troubleshooting guide](https://docs.microsoft.com/en-us/azure/openshift/troubleshoot)

## Documentation and Resources

- [Official ARO Documentation](https://docs.microsoft.com/en-us/azure/openshift/)
- [OpenShift 4 Documentation](https://docs.openshift.com/container-platform/4.10/welcome/index.html)
- [Red Hat ARO Product Page](https://www.redhat.com/en/technologies/cloud-computing/openshift/azure)

## Video Tutorial

A step-by-step video tutorial is available here:
[![ARO Deployment Tutorial](https://img.youtube.com/vi/d701iQ2v2J0/0.jpg)](https://youtu.be/d701iQ2v2J0)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

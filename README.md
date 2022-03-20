# Azure Red Hat OpenShift deployment

Azure Red Hat OpenShift (ARO) provides highly available, fully managed OpenShift clusters on demand, monitored and operated jointly by Microsoft and Red Hat. Kubernetes is at the core of Red Hat OpenShift. The service-level agreement (SLA) is 99.95 percent availability.

This playbook simplifies the deployment of an Azure Red Hat OpenShift cluster using an Ansible playbook. The playbook automates the tutorial found here: https://docs.microsoft.com/en-us/azure/openshift/tutorial-create-cluster

# Prerequesties for running this playbook:

Azure CLI tool - https://docs.microsoft.com/en-us/cli/azure/
oc / kubectl binaries - https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/

# Recommendations:
An OpenShift Pull Secret - https://cloud.redhat.com
While not required to deploy ARO, an image pull secret provides authentication for the cluster to access services and registries which serve the container images for OpenShift components.

# Written [Instructions][1]

[1]: https://github.com/ryannix123/aro_ansible/blob/main/Instructions.md

# [YouTube Tutorial] [2]

[2] https://youtu.be/d701iQ2v2J0






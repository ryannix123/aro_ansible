## Instructions for deploying Azure Red Hat OpenShift (ARO) using an Ansible Playbook. It’s a good idea to fork this repository so you can make your own changes.

**Log into Azure using the az command line tool**

`az login`

**Ensure you have enough computing resources to deploy ARO to your Azure account in your target region. You’ll need at least 36 vCPUS. You can adjust the quota limits [using these instructions][1].

` az vm list-usage --location "Central US" --output table | grep "Total Regional vCPUs" `

**Clone either this repo to your local desktop or fork it to your Github repo then clone that version locally.**

e.g.,` git clone `[https://github.com/ryannix123/aro\_ansible.git][2]

**Download your OpenShift pull-secret from [console.redhat.com][3]. You can find the pull-secret in OpenShift/Downloads.** **Move the pull-secret to your locally cloned aro git repo.**

**Customize the Ansible playbook variables to your liking. e.g., change the region, the name of the resource group, etc. You may comment out the domain portion if you wish to simply use the default domain that Azure assigns to the ARO cluster.**

	  vars:
	    LOCATION: centralus
	    RESOURCEGROUP: aro
	    CLUSTER: aro-cluster
	    DOMAIN: openshifthelp.com
	    MASTER_SIZE : Standard_D8s_v3
	    WORKER_SIZE : Standard_D4s_v3
	    WORKER_COUNT: 3
	    DISK_SIZE: 128

Run the playbook!
`ansible-playbook aro_deployment.yaml`

**The deployment should take 20-35 minutes. When it’s finished you will see the IP addresses, the cluster’s API and console URL as well as the kubeadmin password.**

** To delete the cluster and remove other resources: **
`az group delete --name aro && az group delete --name NetworkWatcherRG && az group delete --name NetworkWatcher_centralus`

[1]:	https://docs.microsoft.com/en-us/azure/azure-portal/supportability/regional-quota-requests#:~:text=Increase%20a%20regional%20vCPU%20quota,-To%20request%20a&text=In%20the%20Azure%20portal%2C%20search,view%20your%20quota%20by%20usage.
[2]:	https://github.com/ryannix123/aro_ansible.git
[3]:	console.redhat.com
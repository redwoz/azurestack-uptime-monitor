# Disconnected version of the Azure Stack uptime monitor 

The procedure is only intended for disconnected environments that do not have any outbound connectivity for workloads running on Azure Stack. Depending on the download bandwidth, this procedure will take ~1 hour.

## Prerequisites
The disconnected version has the following prerequisites.

- Azure Subscription to create the source VHD.
- The linux vm extension v2.0 needs to be available in the Azure Stack enviroment. It can either be downloaded from the Azure marketplace feed in Azure Stack marketplace management or imported with the [Offline Marketplace Syndication](https://github.com/Azure/AzureStack-Tools/tree/master/Syndication) for disconnected environments.
- A tenant user in the same tenant as the SPN account that has at least **contributor** permissions to a resource group that the solution will be deployed to.
- An SPN created in the Identity Provider ([AAD](https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-create-service-principals#create-service-principal-for-azure-ad) or [ADFS](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-create-service-principals#create-a-service-principal-using-a-client-secret)). The authentication method for the SPN account must be with a key (certificate based authentication is not supported). The SPN must have **reader** permissions on the Azure Stack default provider subscription and **contributor** permissions on an Azure Stack tenant subscription.
- An SSH key pair for authenticating to the source VHD and the solution VM. [Guide for creating and using the ssh key pair](/docs/SSH.md).

## Deploy

- Create source VHD on Azure
- Download the VHD from Azure
- Upload the VHD to Azure Stack
- Deploy the solution referencing the VHD

### Create source VHD on Azure

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazurestack-uptime-monitor%2Fmaster%2Fdeploy%2Finitialize%2FmainTemplate.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

You can either click the "deploy to Azure button" or sign in to the Azure Portal, select to create a new resource and search for **template deployment** in the marketplace. In the template deployment marketplace item, select to **build your own template** in the editor and copy the [initialize - deployment template](https://raw.githubusercontent.com/Azure/azurestack-uptime-monitor/master/deploy/initialize/mainTemplate.json) to template editor and hit save.

Use the same username and SSH public that you will use for the deployment of the solution on Azure Stack. If you need to use a different SSH public key, than ensure you change the username to a different value. This will prevent any conflict during the deployment on Azure Stack.

The deployment template will create an Ubuntu VM, installs packages, downloads the required Docker images (influxdb, grafana and azure-cli) and downloads the solution scripts.

### Download the VHD from Azure
Once the deployment is completed, shut down the VM, [download the VHD from Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/download-vhd) from a local machine with internet connectivity.

### Upload the VHD to Azure Stack
A VHD that is not generalized is also known as a specialized VHD. Connect with PowerShell to the Azure Stack tenant subscription you want to deploy the solution, [upload the specialized VHD and convert it to a managed disk](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/create-vm-specialized#option-2-upload-a-specialized-vhd)

### Deploy the solution referencing the VHD
Login to the Azure Stack tenant portal with a user that has access contributor access on the subscription that contains the newly created managed disk. Select to create a new resource and search for **template deployment** in the marketplace. Select **edit template** and copy the [disconnected - deployment template](https://raw.githubusercontent.com/Azure/azurestack-uptime-monitor/master/deploy/disconnected/mainTemplate.json) to template editor and hit save.

The deployment template requires the following inputs:

- managedDiskUri: Specify the url for the managed disk created from the source VHD.
- adminUsername: Use the same username used to create the source VHD.
- sshPublicKey: Use the same SSH public key used to create the source VHD.
- appId: this is the application Id of the SPN created in the identity store.
- appKey: this is the key (password) for the SPN created in the identity store.
- grafanaPassword: this password is used to authenticate to the Grafana portal, once the deployment is completed.
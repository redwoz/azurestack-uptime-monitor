## Deployment for disconnected environment

The procedure is only intended for disconnected environments that do not have any outbound connectivity for workloads running on Azure Stack. This procedure will take ~1 hour.

- Ubuntu image (18.04-LTS or 16.04-LTS). You can use the images available in the Azure marketplace feed in Azure Stack marketplace management, or if you have a disconnected environment, you can use the [Offline Marketplace Syndication](https://github.com/Azure/AzureStack-Tools/tree/master/Syndication) to donwload the image or you can provision an Ubuntu image yourself [Add Linux images to Azure Stack](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-linux)
- An SPN created in the Identity Provider ([AAD](https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-create-service-principals#create-service-principal-for-azure-ad) or [ADFS](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-create-service-principals#create-a-service-principal-using-a-client-secret)). The authentication method for the SPN account must be with a key (certificate based authentication is not supported). The SPN must have **reader** permissions on the default provider subscription and **contributor** permissions on a tenant subscription.
- The linux vm extension v2.0 needs to be available in the Azure Stack enviroment. It can be either installed through Marketplace Management or imported with the [Offline Marketplace Syndication](https://github.com/Azure/AzureStack-Tools/tree/master/Syndication) for disconnected environments.
- A tenant user in the same tenant as the SPN account that has at least **contributor** permissions to a resource group that the solution will be deployed to.
- An SSH key pair for authenticating to the solution VM. [Guide for creating and using the ssh key pair](/docs/SSH.md).

- Download Ubuntu image to connected workstation 
- Install Azure VM Agent [link to steps]
- Install prerequisistes (repos, docker, pull images)
- Import the VHD to a storage account is the tenant subscript
- Deploy ARM template with using custom VHD as input for managed disk
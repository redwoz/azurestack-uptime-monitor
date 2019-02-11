## Deployment for disconnected environment

The procedure is only intended for disconnected environments that do not have any outbound connectivity for workloads running on Azure Stack. This procedure will take ~1 hour.

- Azure Subscription to create base image.
- An SPN created in the Identity Provider ([AAD](https://docs.microsoft.com/en-us/azure/azure-stack/user/azure-stack-create-service-principals#create-service-principal-for-azure-ad) or [ADFS](https://docs.microsoft.com/en-us/azure/azure-stack/azure-stack-create-service-principals#create-a-service-principal-using-a-client-secret)). The authentication method for the SPN account must be with a key (certificate based authentication is not supported). The SPN must have **reader** permissions on the Azure Stack default provider subscription and **contributor** permissions on an Azure Stack tenant subscription.
- The linux vm extension v2.0 needs to be available in the Azure Stack enviroment. It can be either installed through Marketplace Management or imported with the [Offline Marketplace Syndication](https://github.com/Azure/AzureStack-Tools/tree/master/Syndication) for disconnected environments.
- A tenant user in the same tenant as the SPN account that has at least **contributor** permissions to a resource group that the solution will be deployed to.
- An SSH key pair for authenticating to the solution VM. [Guide for creating and using the ssh key pair](/docs/SSH.md).

- Create Ubuntu image on Azure
- Install prerequisistes (repos, docker, pull images)
- Download the VHD
- Import the VHD to a storage account is the tenant subscript
- Create managed disk from VHD blob
- Deploy ARM template with using custom VHD as input for managed disk

## Create Ubuntu image on Azure
Sign in to the Azure Portal adn deploy the sourceTemplate.json 



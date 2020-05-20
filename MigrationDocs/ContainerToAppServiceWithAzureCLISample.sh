# This script contains sample commands for creating resources for an Azure App Service web site using Azure CLI - it is meant to be used as an example of az commands
# Prior to running this script you should install Azure CLI, login to Azure, and select the subscription you want to use
# Installing Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest):
#     curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# Logging in: 
#     az login
# Selecting a subscription (https://docs.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli?view=azure-cli-latest):
#     az account set --subscription "<SUBSCRIPTION NAME>"

myResourceGroupName="MyNewRG"
# myAzureRegion value options can be found using: https://docs.microsoft.com/en-us/cli/azure/appservice?view=azure-cli-latest#az-appservice-list-locations) 
myAzureRegion="Central US"
myASPName="MyNewASP"
mySiteName="MyNewUniqueSiteName"
myACRName="MyNewUniqueACRName"
imageAndTag="imagename:latest"
myLocalContainerId="96302002acff"

echo "Creating resource group $myResourceGroupName"
az group create --name $myResourceGroupName --location "$myAzureRegion"

echo ''
echo "Creating an Azure Container Registry ($myACRName) and saving the registry password for later step"
az acr create --name $myACRName --resource-group $myResourceGroupName --sku Basic --admin-enabled true -l "$myAzureRegion"
acrpwd=$(az acr credential show --name $myACRName | grep  '"value"' -m 1 | cut -d '"' -f 4)

echo ''
echo "Creating a single web worker App Service Plan"
az appservice plan create -n $myASPName -g $myResourceGroupName --is-linux -l "$myAzureRegion" --sku P1v2 --number-of-workers 1

echo "Create image from specified container, login to ACR, and push image to the new Azure Container Registry"
sudo docker commit $myLocalContainerId ${myACRName}.azurecr.io/$imageAndTag
sudo docker login ${myACRName}.azurecr.io --username $myACRName -p $acrpwd
sudo docker push ${myACRName}.azurecr.io/$imageAndTag

echo "Creating site using image in Azure Container Registry"
az webapp create --resource-group $myResourceGroupName --plan $myASPName --name $mySiteName --deployment-container-image-name ${myACRName}.azurecr.io/$imageAndTag --docker-registry-server-user $myACRName --docker-registry-server-password $acrpwd

echo ''
echo "Created site ${mySiteName}.azurewebsites.net"
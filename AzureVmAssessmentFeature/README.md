# Summary
The goal of this feature is to enable Azure App Service migration assessment at scale for applications running on Azure Windows Virtual Machines. These scripts are a wrapper for the existing [Azure App Service Migration Readiness Assessment](https://github.com/Azure/App-Service-Migration-Assistant/wiki/PowerShell-Scripts) and execute the scripts remotely using parallel processing. Note this is for assessments only and the migration of applications is not currently supported. 

# Components
There are two core components, below:
1. Console Script - [Assessment.ps1](/scripts/Assessment.ps1). The script would typically be run by by a user interactively in a script host environment (Azure cloud shell, Powershell desktop, etc).  The script takes a list of Azure Virtual Machiness, performs some pre-flight checks, and then stages and configures the virtual machine script below to run remotely on each virtual machine. It will create a log file locally that details which virtual machines failed the pre-flight checks and why. 
2. VM Scripts - [Assessment.ps1](/scripts/internal/Assessment.ps1) and [Prerequisites.ps1](/scripts/internal/Prerequisites.ps1). This script runs "headless" on each virtual machine.  It executes the App Service Migration Assessment, and uploads the results to blob storage. 

# Requirements
-   The Console Script will support PowerShell core in order to run using Cloud Shell (linux container), and will require both internet access and access to a blob storage container that the virtual machines can also access.
-   Execution requires a pre-created blob container, and the list of virtual machines to assess (with the exception of having the option to run on all virtual machines within a resource group). Virtual machine discovery is beyond scope.  Some examples for how to query ARM and produce a list of target virtual machines will be provided as an example rather than a feature.
-   The initial release will target Azure Virtual Machines only.  Virtual Machine Scale Sets and Cloud Server Web Roles may work as well, but will not be tested, and are currently unsupported targets.
-   Target virtual machines must be running a Windows Server OS 2008R2 or later, have a minimum of PowerShell 4.0, have the Azure Virtual Machine host agent provisioned, and have network access to the user-specified blob storage container.
-   The minimum TLS version of your Azure VM and your storage account must match. Our scripts do not check for this dependency. 
-   Once the virtual machine script is running, there is currently no way to stop it from executing.  The host agent will abort it after 90 minutes if it does not finish sooner.

# Executing the assessment scripts

## Production
This section covers running the assessment scripts on a pre-existing set of Azure Virtual Machines either provided as a list or via a resource group name. 

### Querying ARM for list of virtual machines
See [Microsoft PowerShell documentation](https://learn.microsoft.com/en-us/powershell/module/az.compute/get-azvm?view=azps-9.2.0#example-3-get-properties-for-all-virtual-machines-in-a-resource-group) for example of getting a list of all virtual machines in a resource group. 

### Steps
1. Clone this repo.  The easiest option is to open [Cloudshell](https://shell.azure.com), making sure the to select PowerShell as your shell, and then run:
```
git clone https://github.com/AppServiceMigrations/BulkAppMigration.git
```
2. Check to make sure you are connected the right subscription.  Run [Get-AzContext](https://learn.microsoft.com/en-us/powershell/module/az.accounts/get-azcontext) to verify.  If you need to change to a different subscription, you can list available by calling [Get-AzSubscription](https://learn.microsoft.com/en-us/powershell/module/az.accounts/get-azsubscription), and then run [Set-AzContext -Subscription "xxxx-xxxx-xxxx-xxxx"](Set-AzContext -Subscription "xxxx-xxxx-xxxx-xxxx") with the correct Id.

3.  Switch to the folder of the Github repo you cloned.  Assuming you accepted the default folder, this would be `cd /clouddrive/App-Service-Migration-Assistant/AzureVmAssessmentFeature`.  Note that case-sensitivity matters.

4. Navigate to the [Application Migration Scripts page](https://azure.microsoft.com/en-us/products/app-service/migration-tools/), click _Download Now_ under _App Service migration assistant for PowerShell scripts (preview)_, accept the EULA and you will see a zip file of the scripts downloaded. Upload this zip file to the blob storage accessible by your virtual machines. Do not change the name of the file and put it in the root of the container. The script will expect the scripts in the zip file as is when it downloads.
5. 
6. Run the [Assessment.ps1](/scripts/Assessment.ps1) script to run pre-flight checks and perform the application assessment on each of your virtual machines. 
 
    You will need the following parameters to run this script successfully:
    ```
    SubscriptionId: If you want to use your current context, the script does not require this. 

    ResourceGroupName: Resource group where your virtual machines live

    VirtualMachineNames: Comma separated array of virtual machine names. Not mandatory if you want to query all virtual machines in a resource group.

    AccountName: Storage account name for your blob storage 

    AccountKey: Account key for your storage account

    ContainerName: Name of blob container that contains the zip file of the [Application Migration Scripts](https://github.com/Azure/App-Service-Migration-Assistant/wiki/PowerShell-Scripts) and where your migration results will be uploaded
    ```
    ### Example

    Calling the script without providing a list of virtual machines
    ``` 
    .\Assessment.ps1 -ResourceGroupName "example" -AccountName "exampleSA" -AccountKey "examplekey" -ContainerName "blobname"
    ``` 

    Calling the script providing a list of virtual machines
    ``` 
    .\Assessment.ps1 -ResourceGroupName "example" -AccountName "exampleSA" -AccountKey "examplekey" -ContainerName "blobname" -VirtualMachineNames {"virtualmachine1","virtualmachine2"}
    ``` 
7. Check the logfile in your CloudShell or on your desktop labelled "assessment_XXXX.log" to see if any of your virtual machines didn't meet the pre-flight specifications.
8. Check your blob container where you will find a folder with the same name as your resource group. Inside that folder, you will find a separate output file for each of your virtual machines. 
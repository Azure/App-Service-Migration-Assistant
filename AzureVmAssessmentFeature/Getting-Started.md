# Summary
The goal of this feature is to enable Azure App Service migration assessment at scale for applications running on Azure Windows Virtual Machines. These scripts are a wrapper for the existing [Azure App Service Migration Readiness Assessment](https://github.com/Azure/App-Service-Migration-Assistant/wiki/PowerShell-Scripts) and execute the scripts remotely using parallel processing. Note this is for assessments only and the migration of applications is not currently supported. 

# Components
There are two core components, below:
1. Console Script - [Invoke-Assessment.ps1](/scripts/Invoke-Assessment.ps1). The script would typically be run by by a user interactively in a script host environment (Azure cloud shell, Powershell desktop, etc).  The script takes a list of Azure Virtual Machiness, performs some pre-flight checks, and then stages and configures the virtual machine script below to run remotely on each virtual machine. It will create a log file locally that details which virtual machines failed the pre-flight checks and why. 
2. VM Script - [Assessment.ps1](/scripts/Assessment.ps1). This script runs "headless" on each virtual machine.  It executes the App Service Migration Assessment, and uploads the results to blob storage. 

# Requirements
-   The Console Script will support PowerShell core in order to run using Cloud Shell (linux container), and will require both internet access and access to a blob storage container that the virtual machines can also access.
-   Execution requires a pre-created blob container, and the list of virtual machines to assess (with the exception of having the option to run on all virtual machines within a resource group). Virtual machine discovery is beyond scope.  Some examples for how to query ARM and produce a list of target virtual machines will be provided as an example rather than a feature.
-   The initial release will target Azure Virtual Machines only.  Virtual Machine Scale Sets and Cloud Server Web Roles may work as well, but will not be tested, and are currently unsupported targets.
-   Target virtual machines must be running a Windows OS, 2008R2 or later, have a minimum of PowerShell 4.0, have the Azure Virtual Machine host agent provisioned, and have network access to the user-specified blob storage container.
-   The blob storage requires TLS 1.2 to be enabled on the virtual machine. Our scripts do not check for this dependency. 
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

3.  Switch to the folder of the Github repo you cloned.  Assuming you accepted the default folder, this would be `cd /clouddrive/BulkAppMigration/tests`.  Note that case-sensitivity matters.

4. Run the [Set-Dependencies.ps1](/scripts/Set-Dependencies.ps1) script to upload the [Application Migrations Scripts](https://github.com/Azure/App-Service-Migration-Assistant/wiki/PowerShell-Scripts) to the blob storage accessible by your virtual machines. The script will expect the scripts in the zip file as is when it downloads. Please ensure you accept the EULA when downloading the scripts. 
5. Run the [Invoke-Assessment.ps1](/scripts/Invoke-Assessment.ps1) script to run pre-flight checks and perform the application assessment on each of your virtual machines. 
 
    You will need the following parameters to run this script successfully:
    ```
    SubscriptionId: If you want to use your current context, the script does not require this. 

    ResourceGroupName: Resource group where your virtual machines live

    VMList: Comma separated array of virtual machine names. Not mandatory if you want to query all virtual machines in a resource group.

    AccountName: Storage account name for your blob storage 

    AccountKey: Account key for your storage account

    ContainerName: Name of blob container that contains the zip file of the [Application Migration Scripts](https://github.com/Azure/App-Service-Migration-Assistant/wiki/PowerShell-Scripts) and where your migration results will be uploaded
    ```
    ### Example

    Calling the script without providing a list of virtual machines
    ``` 
    .\Invoke-Assessment -ResourceGroupName "example" -AccountName "exampleSA" -AccountKey "examplekey" -ContainerName "blobname"
    ``` 

    Calling the script providing a list of virtual machines
    ``` 
    .\Invoke-Assessment -ResourceGroupName "example" -AccountName "exampleSA" -AccountKey "examplekey" -ContainerName "blobname" -VMList {"virtualmachine1","virtualmachine2"}
    ``` 
6. Check the logfile in your CloudShell or on your desktop labelled "AppAssessmentErrorLog_XXXX.log" to see if any of your virtual machines didn't meet the pre-flight specifications.
7. Check your blob container where you will find a folder with the same name as your resource group. Inside that folder, you will find a separate output file for each of your virtual machines. 

## Testing [WIP]

You will need an Azure subscription with contributor access, in order to provision some testing infrastructure, and ultimately for running the assessment.  This project includes scripts for setting up some virtual machines to test against, as well has the required storage, and some wrapper functions to parameterize and execute the core scripts.

There are three helper scripts in the `tests` folder: <!-- TODO: expand with parameters and options -->
- `Deploy-Infra.ps1` - Creates some virtual machines and a storage account in your subscription. Returns a list of virtual machines and a blob container, which you can use in the next script.
- `Run-Test.ps1` - Executes the migration assessment, and validates that the expected results were produced.  Expected results will probably need to be provided as some kind of parameter.  Should probably return some basic diagnostic data (execution time, etc)
- `Destroy-Infra.ps1` - Removes all resources created by the first script.  Needs to ensure it doesn't remove resources that were not created.  We might need to limit resources groups in the first script to newly-created only, so we don't destroy a resource group that already existed with other resources.  Or if there is a way to otherwise limit how the resources are identified to be removed.  

### Steps
1. Clone this repo.  The easiest option is to open [Cloudshell](https://shell.azure.com), making sure the to select PowerShell as your shell, and then run:
```
git clone https://github.com/AppServiceMigrations/BulkAppMigration.git
```
2. Check to make sure you are connected the right subscription.  Run [Get-AzContext](https://learn.microsoft.com/en-us/powershell/module/az.accounts/get-azcontext) to verify.  If you need to change to a different subscription, you can list available by calling [Get-AzSubscription](https://learn.microsoft.com/en-us/powershell/module/az.accounts/get-azsubscription), and then run [Set-AzContext -Subscription "xxxx-xxxx-xxxx-xxxx"](Set-AzContext -Subscription "xxxx-xxxx-xxxx-xxxx") with the correct Id.

3.  Switch to the folder of the Github repo you cloned.  Assuming you accepted the default folder, this would be `cd /clouddrive/BulkAppMigration/tests`.  Note that case-sensitivity matters.

4.  Run the Deploy script.
```
$deployedInfra = ./Deploy-Infra.ps1 -<params to be updated>
```
5.  Run the Test script.
```
./Run-Test.ps1 -<params to be updated> -Virtual Machines $deployedIfra.Virtual Machines -storageContainer $deployedIfra.storageContainer -ExpectedResults './foo.json'
```
6. and so on...
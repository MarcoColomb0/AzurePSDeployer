<#
.INFO
    Script Name: AzurePSDeployer.ps1
    Description: Automatic Azure infrastructure deployer
    
.NOTES
    File Name      : AzurePSDeployer.ps1
    Author         : MarcoColomb0
    Repository     : https://github.com/MarcoColomb0/AzurePSDeployer
    Prerequisite   : PowerShell, Az module, and an Azure subscription :)
    Description    : A script that functions as a "launcher" for the deployments stored in the GitHub repository at /deployments 
#>

# Display available services and prompt for user input
Write-Host "You are currently able to deploy these services"
Write-Host "1. Windows 11 Client 23H2"
Write-Host "2. Windows Server 2022"

$DeploymentPrompt = Read-Host "Enter the number corresponding to the service you want to deploy"

# Process user input and deploy the selected service
switch ($DeploymentPrompt) {
    "1" {
        $DeploymentType = "w11-23h2"
    }
    "2" {
        $DeploymentType = "ws-2022"
    }
    default {
        Write-Host "Invalid selection. Exiting script."
        exit
    }
}

# Build the script URL and deploy the selected service
$ScriptURL = "https://github.com/MarcoColomb0/AzurePSDeployer/raw/main/deployments/$DeploymentType.ps1"
Invoke-WebRequest -Uri $ScriptURL | Invoke-Expression
